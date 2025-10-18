#!/bin/bash

echo "[🚀] Memulai setup Fail2Ban (backend systemd/journald) dengan pemblokiran total dan notifikasi Telegram opsional..."

# ========== HARD RESET FAIL2BAN ==========
echo "[⚠️] Melakukan hard reset Fail2Ban..."
sudo systemctl stop fail2ban 2>/dev/null
sudo apt purge --remove -y fail2ban
sudo rm -rf /etc/fail2ban
sudo rm -rf /var/lib/fail2ban
sudo rm -rf /var/run/fail2ban
sudo rm -f /var/log/fail2ban.log

# Bersihkan rule iptables lama (hati-hati: ini flush semua chain filter)
sudo iptables -D INPUT -j f2b-sshd 2>/dev/null
sudo iptables -F f2b-sshd 2>/dev/null
sudo iptables -X f2b-sshd 2>/dev/null
sudo iptables -F || true
sudo iptables -X || true

# ========== CEK /root/.vars ==========
TELEGRAM_ENABLED=true
if [ -f /root/.vars ]; then
    echo "[ℹ️] /root/.vars ditemukan. Lewati input token Telegram."
else
    echo "[❓] Aktifkan notifikasi Telegram saat IP diblokir? (y/n)"
    read -r enable_telegram
    if [[ "$enable_telegram" =~ ^[Yy]$ ]]; then
        echo -n "[🔐] Masukkan Bot Token: "
        read -r bot_token
        echo -n "[👤] Masukkan Telegram Chat ID: "
        read -r telegram_id
        echo -n "[🧵] Masukkan Telegram Thread ID (opsional, tekan Enter jika tidak ada): "
        read -r telegram_thread_id

        echo "[💾] Menyimpan kredensial ke /root/.vars..."
        cat <<EOF > /root/.vars
bot_token="$bot_token"
telegram_id="$telegram_id"
telegram_thread_id="${telegram_thread_id}"
EOF
        chmod 600 /root/.vars
    else
        TELEGRAM_ENABLED=false
        echo "[⏩] Melewati notifikasi Telegram."
    fi
fi

# ========== INSTALL FAIL2BAN (dan curl untuk Telegram) ==========
echo "[📦] Menginstal Fail2Ban..."
sudo apt update && sudo apt install -y fail2ban curl jq
# ========== PASANG HELPER TELEGRAM (tg_notify) ==========
if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "[🧰] Menginstal helper Telegram: /usr/local/bin/tg_notify"
    sudo tee /usr/local/bin/tg_notify >/dev/null <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

# tg_notify <mode> <message> [key]
#   mode: send|append
#   message: text to send/append
#   key: logical group key for batching (default: default)

# Load credentials
if [ -f /root/.vars ]; then
    # shellcheck disable=SC1091
    . /root/.vars
else
    echo "[tg_notify] /root/.vars tidak ditemukan" >&2
    exit 1
fi

BOT_TOKEN=${bot_token:-}
CHAT_ID=${telegram_id:-}
THREAD_ID=${telegram_thread_id:-}

if [ -z "${BOT_TOKEN}" ] || [ -z "${CHAT_ID}" ]; then
    echo "[tg_notify] BOT_TOKEN atau CHAT_ID kosong" >&2
    exit 1
fi

MODE=${1:-send}
TEXT=${2:-}
KEY=${3:-default}

if [ -z "${TEXT}" ]; then
    echo "[tg_notify] TEXT kosong" >&2
    exit 1
fi

STATE_DIR=/var/tmp
MSG_FILE="${STATE_DIR}/tg_notify_${KEY}.txt"
ID_FILE="${STATE_DIR}/tg_notify_${KEY}.msgid"
TS_FILE="${STATE_DIR}/tg_notify_${KEY}.ts"
LOCK_FILE="${STATE_DIR}/tg_notify_${KEY}.lock"
COUNT_FILE="${STATE_DIR}/tg_notify_${KEY}.count"

mkdir -p "${STATE_DIR}"

# Serialize concurrent invocations for the same KEY to avoid duplicate send
exec {LOCK_FD}>"${LOCK_FILE}"
flock -w 10 "${LOCK_FD}" || {
  echo "[tg_notify] tidak bisa mendapatkan lock untuk ${KEY}" >&2
  exit 1
}

api_url() {
  echo "https://api.telegram.org/bot${BOT_TOKEN}/$1"
}

send_message() {
  if [ -n "${THREAD_ID}" ]; then
    curl -sS -X POST "$(api_url sendMessage)" \
      -d chat_id="${CHAT_ID}" \
      -d message_thread_id="${THREAD_ID}" \
      -d disable_web_page_preview=true \
      --data-urlencode "text=$1"
  else
    curl -sS -X POST "$(api_url sendMessage)" \
      -d chat_id="${CHAT_ID}" \
      -d disable_web_page_preview=true \
      --data-urlencode "text=$1"
  fi
}

edit_message() {
  local message_id="$1"; shift
  if [ -n "${THREAD_ID}" ]; then
    curl -sS -X POST "$(api_url editMessageText)" \
      -d chat_id="${CHAT_ID}" \
      -d message_id="${message_id}" \
      -d disable_web_page_preview=true \
      --data-urlencode "text=$1"
  else
    curl -sS -X POST "$(api_url editMessageText)" \
      -d chat_id="${CHAT_ID}" \
      -d message_id="${message_id}" \
      -d disable_web_page_preview=true \
      --data-urlencode "text=$1"
  fi
}

extract_message_id() {
  # Prefer jq for robust parsing
  if command -v jq >/dev/null 2>&1; then
    jq -r '.result.message_id // empty' 2>/dev/null | head -n1
  else
    # Fallback to sed if jq missing
    sed -n 's/.*"message_id"[[:space:]]*:[[:space:]]*\([0-9]\+\).*/\1/p' | head -n1
  fi
}

now_ts() { date +%s; }

readable_now() { date '+%Y-%m-%d %H:%M:%S %Z'; }

ban_count_from_file() {
  # Read persistent total ban count
  if [ -s "${COUNT_FILE}" ]; then
    cat "${COUNT_FILE}"
  else
    echo 0
  fi
}

strip_footer() {
  # Remove footer lines if exist
  sed -e '/^Terakhir diperbarui:/d' -e '/^Total IP diblokir:/d'
}

rotate_if_needed() {
  local text_len
  text_len=$(wc -c <"${MSG_FILE}" 2>/dev/null || echo 0)
  # Telegram limit ~4096 chars; rotate if > 3900 to be safe
  if [ "${text_len}" -gt 3900 ]; then
    # Preserve persistent counters; only reset message state
    rm -f "${ID_FILE}" "${TS_FILE}" "${MSG_FILE}"
  fi
}

case "${MODE}" in
  send)
    RESP=$(send_message "${TEXT}") || true
    echo -n "${RESP}" | extract_message_id >"${ID_FILE}" || true
    ;;
  append)
    # Initialize or rotate
    rotate_if_needed

    # Check if we have existing message to append to
    message_id=""
    if [ -s "${ID_FILE}" ]; then
      message_id=$(cat "${ID_FILE}" 2>/dev/null || true)
    fi

    if [ -z "${message_id}" ]; then
      # No existing message, create new one
      echo "[tg_notify] Membuat pesan baru untuk key: ${KEY}" >&2
      echo "${TEXT}" >"${MSG_FILE}"
      RESP=$(send_message "${TEXT}") || true
      extracted_id=$(echo -n "${RESP}" | extract_message_id || true)
      if [ -n "${extracted_id}" ]; then
        echo "${extracted_id}" >"${ID_FILE}"
        echo "[tg_notify] Message ID tersimpan: ${extracted_id}" >&2
      else
        echo "[tg_notify] Gagal extract message_id dari response: ${RESP}" >&2
      fi
      date +%s >"${TS_FILE}"
      exit 0
    fi

    # Append to existing message and edit with footer (last updated + total bans)
    echo "[tg_notify] Mengedit pesan ID: ${message_id} untuk key: ${KEY}" >&2
    { echo "${TEXT}"; echo; } >>"${MSG_FILE}"
    # Build body without old footer
    BODY=$(strip_footer <"${MSG_FILE}")
    # Persistent total bans
    if [ ! -s "${COUNT_FILE}" ]; then echo 0 >"${COUNT_FILE}"; fi
    if grep -q '^🚫' <<<"${TEXT}"; then
      CUR=$(cat "${COUNT_FILE}" 2>/dev/null || echo 0)
      echo $((CUR+1)) >"${COUNT_FILE}"
    fi
    TOTAL=$(ban_count_from_file)
    FOOTER=$'Terakhir diperbarui: '"$(readable_now)"$'\nTotal IP diblokir: '"${TOTAL}"
    RESP=$(edit_message "${message_id}" "${BODY}

${FOOTER}") || true

    # Check if edit was successful
    if grep -q '"ok"[[:space:]]*:[[:space:]]*true' <<<"${RESP}"; then
      echo "[tg_notify] Berhasil edit pesan" >&2
      date +%s >"${TS_FILE}"
    else
      echo "[tg_notify] Edit gagal, membuat pesan baru: ${RESP}" >&2
      # Edit failed, fallback to new message
      echo "${TEXT}" >"${MSG_FILE}"
      RESP=$(send_message "${TEXT}") || true
      extracted_id=$(echo -n "${RESP}" | extract_message_id || true)
      if [ -n "${extracted_id}" ]; then
        echo "${extracted_id}" >"${ID_FILE}"
        echo "[tg_notify] Fallback: Message ID tersimpan: ${extracted_id}" >&2
      fi
      date +%s >"${TS_FILE}"
    fi
    ;;
  *)
    echo "[tg_notify] MODE tidak dikenali: ${MODE}" >&2
    exit 1
    ;;
esac
EOF
    sudo chmod +x /usr/local/bin/tg_notify
    echo "[🧰] Menginstal helper info IP: /usr/local/bin/f2b_build_message"
    sudo tee /usr/local/bin/f2b_build_message >/dev/null <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

# f2b_build_message <ban|unban> <ip> <jail-name>

EVENT=${1:-}
IP=${2:-}
JAIL=${3:-}

if [ -z "${EVENT}" ] || [ -z "${IP}" ] || [ -z "${JAIL}" ]; then
  echo "Invalid arguments" >&2
  exit 1
fi

ICON="🚫"; ACTION="diblokir"
if [ "${EVENT}" = "unban" ]; then
  ICON="✅"; ACTION="di-unban"
fi

ASN_CODE="-"
ISP_NAME="-"

# Try ip-api.com (fast, no key)
JSON=$(curl -sS --max-time 5 "http://ip-api.com/json/${IP}?fields=status,as,isp" || true)
if command -v jq >/dev/null 2>&1 && echo "${JSON}" | jq -e '.status=="success"' >/dev/null 2>&1; then
  AS_FIELD=$(echo "${JSON}" | jq -r '.as // empty')
  ISP_NAME=$(echo "${JSON}" | jq -r '.isp // empty')
  if [ -n "${AS_FIELD}" ]; then
    ASN_CODE=$(awk '{print $1}' <<<"${AS_FIELD}")
  fi
fi

# Fallback to ipinfo if missing
if [ "${ASN_CODE}" = "-" ] || [ -z "${ASN_CODE}" ]; then
  JSON2=$(curl -sS --max-time 5 "https://ipinfo.io/${IP}/json" || true)
  if command -v jq >/dev/null 2>&1 && [ -n "${JSON2}" ]; then
    ORG=$(echo "${JSON2}" | jq -r '.org // empty')
    if [ -n "${ORG}" ]; then
      ASN_CODE=$(awk '{print $1}' <<<"${ORG}")
      ISP_NAME=$(echo "${ORG}" | sed 's/^[^ ]\+ //')
    fi
  fi
fi

ASN_CODE=${ASN_CODE:--}
ISP_NAME=${ISP_NAME:--}

printf "%s IP %s (jail: %s).\nIP: %s\nASN: %s\nISP: %s" "${ICON}" "${ACTION}" "${JAIL}" "${IP}" "${ASN_CODE}" "${ISP_NAME}"
EOF
    sudo chmod +x /usr/local/bin/f2b_build_message
fi

# Pastikan direktori ada
sudo mkdir -p /etc/fail2ban/action.d
sudo mkdir -p /etc/fail2ban/jail.d

# ========== ACTION UNTUK BLOK TOTAL (iptables) ==========
echo "[🛡️] Membuat action iptables-ban.conf untuk blokir semua trafik..."
IPT=$(command -v iptables || echo /sbin/iptables)
sudo tee /etc/fail2ban/action.d/iptables-ban.conf >/dev/null <<EOF
[Definition]
actionban = $IPT -I INPUT -s <ip> -j DROP
actionunban = $IPT -D INPUT -s <ip> -j DROP
EOF

# ========== (OPSIONAL) ACTION UNTUK TELEGRAM ==========
if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "[📨] Membuat action telegram-ban.conf..."
    sudo tee /etc/fail2ban/action.d/telegram-ban.conf >/dev/null <<'EOF'
[Definition]
actionstart =
actionstop  =
actioncheck =
actionban   = /usr/local/bin/tg_notify append "$(/usr/local/bin/f2b_build_message ban <ip> <name>)" fail2ban-sshd-v2
actionunban = /usr/local/bin/tg_notify append "$(/usr/local/bin/f2b_build_message unban <ip> <name>)" fail2ban-sshd-v2
[Init]
EOF
fi

# ========== KONFIGURASI JAIL (backend systemd + aggressive mode) ==========
echo "[📄] Menyiapkan konfigurasi /etc/fail2ban/jail.d/sshd.local (systemd backend)..."
sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<EOF
[sshd]
enabled   = true
backend   = systemd
# Tambahan untuk memastikan hanya log dari service SSH:
journalmatch = _SYSTEMD_UNIT=ssh.service + _COMM=sshd

port      = ssh
# Dengan backend=systemd, logpath tidak diperlukan/diabaikan.
# logpath  = %(sshd_log)s

# Lebih tegas menangkap pola seperti "Invalid user ... [preauth]"
mode      = aggressive

# Kebijakan ban (silakan sesuaikan):
maxretry  = 1
findtime  = 60
bantime   = 86400

# Aksi: blok total via iptables + (opsional) Telegram
action    = iptables-ban
EOF

if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "             telegram-ban" | sudo tee -a /etc/fail2ban/jail.d/sshd.local >/dev/null
fi

# ========== RESTART FAIL2BAN ==========
echo "[🔁] Me-restart Fail2Ban..."
sudo systemctl enable --now fail2ban
sudo fail2ban-client reload || sudo systemctl restart fail2ban

# ========== STATUS ==========
echo ""
echo "[✅] Setup selesai!"
echo "• Backend: systemd (journald) dengan mode=aggressive."
echo "• IP yang gagal login SSH akan diblokir total (DROP di INPUT)."
if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "• Notifikasi Telegram diaktifkan."
else
    echo "• Notifikasi Telegram tidak diaktifkan."
fi

echo ""
echo "[🧪] Uji cepat:"
echo "  - Tampilkan log SSH dari journald: journalctl -u ssh --since \"-10m\" | tail -n 30"
echo "  - Tes ban manual: sudo fail2ban-client set sshd banip 1.2.3.4"
echo "  - Cek status jail: fail2ban-client status sshd"
