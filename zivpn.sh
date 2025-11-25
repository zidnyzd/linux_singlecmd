#!/bin/bash
# zivpn-udp-user - manage UDP users for zivpn (interactive menu + CLI + Telegram backup/restore)
USERS_FILE="/etc/zivpn/users.json"
CONFIG_FILE="/etc/zivpn/config.json"
BACKUP_DIR="/etc/zivpn/backups"
TELEGRAM_CONF="/etc/zivpn/telegram.conf"  # or use env ZIVPN_TG_TOKEN / ZIVPN_TG_CHATID

# colors
c_reset=$(tput sgr0 2>/dev/null || echo "")
c_bold=$(tput bold 2>/dev/null || echo "")
c_red=$(tput setaf 1 2>/dev/null || echo "")
c_green=$(tput setaf 2 2>/dev/null || echo "")
c_yellow=$(tput setaf 3 2>/dev/null || echo "")
c_cyan=$(tput setaf 6 2>/dev/null || echo "")

ensure_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo -e "${c_yellow}jq tidak ditemukan. Menginstall jq...${c_reset}"
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -qq && apt-get install -y jq >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
      yum install -y jq >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y jq >/dev/null 2>&1
    else
      echo -e "${c_red}Error: jq tidak terinstall dan tidak dapat menginstall otomatis. Silakan install jq manual.${c_reset}"
      exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
      echo -e "${c_red}Error: Gagal menginstall jq. Silakan install manual.${c_reset}"
      exit 1
    fi
    echo -e "${c_green}jq berhasil diinstall.${c_reset}"
  fi
}

now() { date -u +"%Y-%m-%d"; }
now_ts() { date -u +"%Y%m%d_%H%M%S"; }

load_telegram_conf() {
  # precedence: env vars > telegram.conf
  if [ -n "${ZIVPN_TG_TOKEN:-}" ] && [ -n "${ZIVPN_TG_CHATID:-}" ]; then
    TG_TOKEN="${ZIVPN_TG_TOKEN}"
    TG_CHATID="${ZIVPN_TG_CHATID}"
    return
  fi
  if [ -f "$TELEGRAM_CONF" ]; then
    # simple KEY=VALUE lines
    source "$TELEGRAM_CONF"
    TG_TOKEN="${ZIVPN_TG_TOKEN:-$TG_TOKEN}"
    TG_CHATID="${ZIVPN_TG_CHATID:-$TG_CHATID}"
  fi
}

# --- Initial Setup Function ---
initial_setup() {
  echo ""
  echo -e "${c_cyan}${c_bold}========================================${c_reset}"
  echo -e "${c_cyan}${c_bold}   ZIVPN SETUP AWAL - ONE TIME INSTALL  ${c_reset}"
  echo -e "${c_cyan}${c_bold}========================================${c_reset}"
  echo ""
  
  # Check if already setup
  if [ -f "$USERS_FILE" ] && [ -f "$CONFIG_FILE" ] && [ -f "$TELEGRAM_CONF" ]; then
    echo -e "${c_green}Setup sudah dilakukan sebelumnya.${c_reset}"
    echo -e "${c_yellow}Jika ingin setup ulang, hapus file berikut:${c_reset}"
    echo -e "  - $USERS_FILE"
    echo -e "  - $CONFIG_FILE"
    echo -e "  - $TELEGRAM_CONF"
    echo ""
    read -p "Lanjutkan ke menu? (Y/n): " cont
    if [[ "$cont" =~ ^[Nn]$ ]]; then
      exit 0
    fi
    return 0
  fi
  
  # Ensure jq is installed
  ensure_jq
  
  # Create /etc/zivpn directory
  echo -e "${c_cyan}[1/5] Membuat direktori /etc/zivpn...${c_reset}"
  mkdir -p /etc/zivpn
  mkdir -p "$BACKUP_DIR"
  chown root:root /etc/zivpn "$BACKUP_DIR"
  chmod 700 /etc/zivpn "$BACKUP_DIR"
  echo -e "${c_green}Direktori dibuat.${c_reset}"
  
  # Initialize users.json if not exists
  echo -e "${c_cyan}[2/5] Menginisialisasi users.json...${c_reset}"
  if [ ! -f "$USERS_FILE" ]; then
    echo "[]" > "$USERS_FILE"
    chmod 600 "$USERS_FILE"
    chown root:root "$USERS_FILE"
    echo -e "${c_green}users.json dibuat.${c_reset}"
  else
    echo -e "${c_yellow}users.json sudah ada, dilewati.${c_reset}"
  fi
  
  # Initialize config.json if not exists
  echo -e "${c_cyan}[3/5] Menginisialisasi config.json...${c_reset}"
  if [ ! -f "$CONFIG_FILE" ]; then
    echo '{"config":["zi"]}' > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    chown root:root "$CONFIG_FILE"
    echo -e "${c_green}config.json dibuat.${c_reset}"
  else
    echo -e "${c_yellow}config.json sudah ada, dilewati.${c_reset}"
  fi
  
  # Setup Telegram Bot
  echo -e "${c_cyan}[4/5] Setup Telegram Bot...${c_reset}"
  if [ -f "$TELEGRAM_CONF" ]; then
    echo -e "${c_yellow}Telegram config sudah ada.${c_reset}"
    read -p "Setup ulang Telegram? (y/N): " redo_tg
    if [[ ! "$redo_tg" =~ ^[Yy]$ ]]; then
      echo -e "${c_yellow}Telegram setup dilewati.${c_reset}"
      return 0
    fi
  fi
  
  echo ""
  echo -e "${c_cyan}Untuk mendapatkan Bot Token:${c_reset}"
  echo -e "  1. Buka Telegram, cari @BotFather"
  echo -e "  2. Kirim perintah /newbot"
  echo -e "  3. Ikuti instruksi untuk membuat bot baru"
  echo -e "  4. Salin token yang diberikan BotFather"
  echo ""
  read -p "Masukkan Bot Token: " tg_token
  
  if [ -z "$tg_token" ]; then
    echo -e "${c_yellow}Token kosong, Telegram setup dilewati.${c_reset}"
    return 0
  fi
  
  echo ""
  echo -e "${c_cyan}Untuk mendapatkan Chat ID:${c_reset}"
  echo -e "  1. Kirim pesan ke bot yang baru dibuat"
  echo -e "  2. Buka browser: https://api.telegram.org/bot${tg_token}/getUpdates"
  echo -e "  3. Cari \"chat\":{\"id\":123456789 di hasil JSON"
  echo -e "  4. Salin angka ID tersebut"
  echo ""
  read -p "Masukkan Chat ID: " tg_chatid
  
  if [ -z "$tg_chatid" ]; then
    echo -e "${c_yellow}Chat ID kosong, Telegram setup dilewati.${c_reset}"
    return 0
  fi
  
  # Test Telegram connection
  echo -e "${c_cyan}Menguji koneksi Telegram...${c_reset}"
  ensure_jq
  test_resp=$(curl -s "https://api.telegram.org/bot${tg_token}/getMe")
  test_ok=$(echo "$test_resp" | jq -r '.ok' 2>/dev/null)
  
  if [ "$test_ok" = "true" ]; then
    bot_name=$(echo "$test_resp" | jq -r '.result.username' 2>/dev/null)
    echo -e "${c_green}Koneksi berhasil! Bot: @${bot_name}${c_reset}"
  else
    echo -e "${c_red}Gagal menguji koneksi. Token mungkin salah.${c_reset}"
    read -p "Tetap simpan konfigurasi? (y/N): " save_anyway
    if [[ ! "$save_anyway" =~ ^[Yy]$ ]]; then
      echo -e "${c_yellow}Konfigurasi Telegram dibatalkan.${c_reset}"
      return 0
    fi
  fi
  
  # Save Telegram config
  echo -e "${c_cyan}[5/5] Menyimpan konfigurasi Telegram...${c_reset}"
  cat > "$TELEGRAM_CONF" <<EOF
ZIVPN_TG_TOKEN=${tg_token}
ZIVPN_TG_CHATID=${tg_chatid}
EOF
  chmod 600 "$TELEGRAM_CONF"
  chown root:root "$TELEGRAM_CONF"
  echo -e "${c_green}Konfigurasi Telegram disimpan di $TELEGRAM_CONF${c_reset}"
  
  echo ""
  echo -e "${c_green}${c_bold}Setup selesai!${c_reset}"
  echo ""
  read -p "Tekan enter untuk melanjutkan ke menu..."
}

# --- Backup / restore functions ---
ensure_backup_dir() {
  mkdir -p "$BACKUP_DIR"
  chown root:root "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR"
}

create_backup() {
  ensure_backup_dir
  ts=$(now_ts)
  outfile="${BACKUP_DIR}/zivpn-backup-${ts}.tar.gz"
  # include users.json, config.json, certs if exist
  tar -czf "$outfile" -C /etc zivpn || ( echo "${c_red}Backup failed${c_reset}" && return 1 )
  echo "$outfile"
}

send_file_to_telegram() {
  local file="$1"
  load_telegram_conf
  ensure_jq
  if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ]; then
    echo -e "${c_red}Telegram token/chat id belum diset. Jalankan setup awal atau buat file $TELEGRAM_CONF dengan ZIVPN_TG_TOKEN=... dan ZIVPN_TG_CHATID=...${c_reset}"
    return 1
  fi
  if [ ! -f "$file" ]; then
    echo -e "${c_red}File $file tidak ditemukan${c_reset}"
    return 1
  fi
  # sendDocument
  resp=$(curl -s -F chat_id="$TG_CHATID" -F document=@"$file" "https://api.telegram.org/bot${TG_TOKEN}/sendDocument")
  ok=$(echo "$resp" | jq -r '.ok')
  if [ "$ok" = "true" ]; then
    echo -e "${c_green}Backup dikirim ke Telegram.${c_reset}"
    return 0
  else
    echo -e "${c_red}Gagal mengirim ke Telegram: $(echo "$resp" | jq -r '.description // "unknown")'${c_reset}"
    return 1
  fi
}

backup_command() {
  file=$(create_backup) || return 1
  echo -e "${c_green}Backup dibuat: $file${c_reset}"
}

backup_send_telegram_cmd() {
  file=$(create_backup) || return 1
  send_file_to_telegram "$file"
}

# --- restore: download latest document sent to bot ---
# flow:
# 1) getUpdates -> find latest message with document
# 2) getFile -> file_path
# 3) download file and extract safely (backup current first)
restore_from_telegram() {
  load_telegram_conf
  ensure_jq
  if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHATID" ]; then
    echo -e "${c_red}Telegram token/chat id belum diset. Jalankan setup awal atau buat file $TELEGRAM_CONF dengan ZIVPN_TG_TOKEN=... dan ZIVPN_TG_CHATID=...${c_reset}"
    return 1
  fi

  # fetch updates (only last 100 to be safe)
  updates=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getUpdates?limit=100")
  ok=$(echo "$updates" | jq -r '.ok')
  if [ "$ok" != "true" ]; then
    echo -e "${c_red}getUpdates failed: $(echo "$updates" | jq -r '.description // "unknown")'${c_reset}"
    return 1
  fi

  # find last document from the configured chat_id
  local jq_file_filter="[ .result[] | select(.message!=null) | .message | select(.chat.id|tostring==\$cid) | select(.document!=null) | {date:.date, file_id:.document.file_id} ] | sort_by(.date) | last | .file_id"
  file_id=$(echo "$updates" | jq -r --arg cid "$TG_CHATID" "$jq_file_filter")
  if [ -z "$file_id" ] || [ "$file_id" = "null" ]; then
    echo -e "${c_yellow}Tidak ada file document terbaru di bot untuk chat_id $TG_CHATID.${c_reset}"
    return 1
  fi
  # get file path
  getfile=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getFile?file_id=${file_id}")
  okf=$(echo "$getfile" | jq -r '.ok')
  if [ "$okf" != "true" ]; then
    echo -e "${c_red}getFile failed: $(echo "$getfile" | jq -r '.description // "unknown")'${c_reset}"
    return 1
  fi
  file_path=$(echo "$getfile" | jq -r '.result.file_path')
  if [ -z "$file_path" ] || [ "$file_path" = "null" ]; then
    echo -e "${c_red}Tidak dapat menemukan file_path${c_reset}"
    return 1
  fi

  # download file
  ensure_backup_dir
  out_local="${BACKUP_DIR}/zivpn-restore-$(now_ts).tar.gz"
  url="https://api.telegram.org/file/bot${TG_TOKEN}/${file_path}"
  echo -e "${c_cyan}Mengunduh file dari Telegram...${c_reset}"
  curl -s -o "$out_local" "$url"
  if [ ! -s "$out_local" ]; then
    echo -e "${c_red}Download gagal${c_reset}"
    return 1
  fi
  echo -e "${c_green}File diunduh: $out_local${c_reset}"

  # backup current before overwrite
  safe_backup="${BACKUP_DIR}/pre-restore-$(now_ts).tar.gz"
  tar -czf "$safe_backup" -C /etc zivpn || echo "Pre-restore backup failed - continuing"

  # extract (overwrite) but be careful: extract to temp first, validate then move
  tmpdir=$(mktemp -d)
  tar -xzf "$out_local" -C "$tmpdir"
  # expect tmpdir/etc/zivpn/...
  if [ -d "$tmpdir/etc/zivpn" ]; then
    echo -e "${c_cyan}Memindahkan file dari backup ke /etc/zivpn - overwrite${c_reset}"
    cp -a "$tmpdir/etc/zivpn/." /etc/zivpn/
    chown root:root /etc/zivpn/users.json /etc/zivpn/config.json 2>/dev/null || true
    chmod 600 /etc/zivpn/users.json 2>/dev/null || true
    echo -e "${c_green}Restore selesai. Membuat regen config dan restart service...${c_reset}"
    regen_config >/dev/null 2>&1 || true
    systemctl restart zivpn.service || true
    rm -rf "$tmpdir"
    return 0
  else
    echo -e "${c_red}File backup tidak berformat yang diharapkan - tidak ditemukan etc/zivpn. Restore dibatalkan.${c_reset}"
    rm -rf "$tmpdir"
    return 1
  fi
}

# --- existing user management functions (add/del/list/info/expire/regen) ---
add_user_cli() {
  local user="$1"; local days="$2"
  if [ -z "$user" ] || [ -z "$days" ]; then
    echo -e "${c_red}add requires username and days${c_reset}"; exit 1
  fi
  local created=$(date -u +"%Y-%m-%d")
  local expires=$(date -u -d "$created +$days days" +"%Y-%m-%d")
  if jq -e --arg u "$user" '.[] | select(.username==$u)' "$USERS_FILE" >/dev/null 2>&1; then
    echo -e "${c_yellow}User $user already exists${c_reset}"; exit 1
  fi
  local password="$user"   # password == username
  jq --arg username "$user" --arg password "$password" --arg created "$created" --arg expires "$expires" \
     '. + [ {username:$username, password:$password, created:$created, expires:$expires} ]' \
     "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
  echo -e "${c_green}Added user: $user - expires: $expires | password = username${c_reset}"
  regen_config >/dev/null 2>&1 || true
  systemctl restart zivpn.service || true
}

del_user_cli() {
  local user="$1"
  if [ -z "$user" ]; then echo "usage: del username"; exit 1; fi
  if ! jq -e --arg u "$user" '.[] | select(.username==$u)' "$USERS_FILE" >/dev/null 2>&1; then
    echo -e "${c_yellow}User $user not found${c_reset}"; exit 1
  fi
  jq --arg u "$user" 'del(.[] | select(.username==$u))' "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
  echo -e "${c_green}Deleted user $user${c_reset}"
  regen_config >/dev/null 2>&1 || true
  systemctl restart zivpn.service || true
}

list_users_cli() {
  echo -e "${c_bold}Users - username | expiresUTC:${c_reset}"
  if [ "$(jq length "$USERS_FILE")" -eq 0 ]; then
    echo "no users"; return
  fi
  jq -r '.[] | "\(.username) | \(.expires)"' "$USERS_FILE" | nl -ba
}

info_user_cli() {
  local user="$1"
  if [ -z "$user" ]; then echo "usage: info username"; exit 1; fi
  if ! jq -e --arg u "$user" '.[] | select(.username==$u)' "$USERS_FILE" >/dev/null 2>&1; then
    echo -e "${c_yellow}User not found${c_reset}"; exit 1
  fi
  jq -r --arg u "$user" '.[] | select(.username==$u) | "username: \(.username)\npassword: \(.password)\ncreated: \(.created)\nexpires: \(.expires)"' "$USERS_FILE"
}

expire_user_cli() {
  local user="$1"
  if [ -z "$user" ]; then echo "usage: expire username"; exit 1; fi
  local jq_check=".[] | select(.username==\$u)"
  local jq_result
  jq_result=$(jq -e --arg u "$user" "$jq_check" "$USERS_FILE" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$jq_result" ]; then
    echo -e "${c_yellow}User $user not found${c_reset}"; exit 1
  fi
  local today=$(date -u +"%Y-%m-%d")
  local jq_filter="map(if .username == \$u then .expires = \$ex else . end)"
  jq --arg u "$user" --arg ex "$today" "$jq_filter" "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
  echo -e "${c_green}User $user marked expired - $today${c_reset}"
  regen_config >/dev/null 2>&1 || true
  systemctl restart zivpn.service || true
}

regen_config() {
  ensure_jq
  local today=$(date -u +"%Y-%m-%d")
  local jq_filter="[ .[] | select(.expires >= \$today) | .username ]"
  arr=$(jq -c --arg today "$today" "$jq_filter" "$USERS_FILE")
  if [ -z "$arr" ] || [ "$arr" = "[]" ]; then arr='["zi"]'; fi
  jq --argjson arr "$arr" '.config = $arr' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  local cnt=$(echo "$arr" | jq 'length')
  echo -e "${c_cyan}Regenerated $CONFIG_FILE with $cnt active passwords${c_reset}"
}

# --- Interactive menu (extended with backup/restore) ---
interactive_menu() {
  while true; do
    clear
    echo ""
    echo -e "${c_cyan}${c_bold}========================================${c_reset}"
    echo -e "${c_cyan}${c_bold}     ZIVPN UDP ACCOUNT MANAGER v1      ${c_reset}"
    echo -e "${c_cyan}${c_bold}========================================${c_reset}"
    echo ""
    echo -e "  ${c_green}1)${c_reset} Tambah user - password = username"
    echo -e "  ${c_green}2)${c_reset} Hapus user"
    echo -e "  ${c_green}3)${c_reset} Daftar user"
    echo -e "  ${c_green}4)${c_reset} Info user"
    echo -e "  ${c_green}5)${c_reset} Tandai expired sekarang"
    echo -e "  ${c_green}6)${c_reset} Regenerate config - aktifkan/deaktifkan berdasarkan expiry"
    echo -e "  ${c_green}7)${c_reset} Backup -> buat file di server"
    echo -e "  ${c_green}8)${c_reset} Backup -> kirim ke Telegram"
    echo -e "  ${c_green}9)${c_reset} Restore <- ambil backup terbaru dari Telegram"
    echo -e "  ${c_green}10)${c_reset} Setup ulang - Telegram config"
    echo -e "  ${c_green}11)${c_reset} Exit"
    echo ""
    read -p $'\e[36mPilih nomor> \e[0m' choice
    case "$choice" in
      1)
        read -p "Username (alphanumeric): " u
        if [[ ! $u =~ ^[A-Za-z0-9._-]{1,32}$ ]]; then
          echo -e "${c_red}Invalid username. Only A-Z, a-z, 0-9, . _ - allowed.${c_reset}"
          read -p "Tekan enter untuk kembali..."
          continue
        fi
        read -p "Masa aktif (hari): " days
        if ! [[ $days =~ ^[0-9]+$ ]]; then
          echo -e "${c_red}Invalid days. Masukkan angka.${c_reset}"
          read -p "Tekan enter untuk kembali..."
          continue
        fi
        add_user_cli "$u" "$days"
        read -p "Tekan enter untuk lanjut..."
        ;;
      2)
        read -p "Username yang akan dihapus: " u
        read -p "Yakin hapus $u? (y/N): " conf
        if [[ "$conf" =~ ^[Yy]$ ]]; then del_user_cli "$u"; else echo "Batal."; fi
        read -p "Tekan enter untuk lanjut..."
        ;;
      3)
        list_users_cli; echo ""; read -p "Tekan enter untuk lanjut..."
        ;;
      4)
        read -p "Username: " u; info_user_cli "$u"; echo ""; read -p "Tekan enter untuk lanjut..."
        ;;
      5)
        read -p "Username: " u
        read -p "Yakin tandai expired $u sekarang? (y/N): " conf
        if [[ "$conf" =~ ^[Yy]$ ]]; then expire_user_cli "$u"; else echo "Batal."; fi
        read -p "Tekan enter untuk lanjut..."
        ;;
      6)
        regen_config; read -p "Tekan enter untuk lanjut..."
        ;;
      7)
        f=$(create_backup) && echo -e "${c_green}Backup dibuat: $f${c_reset}"; read -p "Tekan enter untuk lanjut..."
        ;;
      8)
        backup_send_telegram_cmd; read -p "Tekan enter untuk lanjut..."
        ;;
      9)
        echo -e "${c_yellow}Restore akan mengambil file document terbaru yang dikirim ke bot untuk chat_id yang di-set.${c_reset}"
        read -p "Lanjut restore? (y/N): " conf
        if [[ "$conf" =~ ^[Yy]$ ]]; then restore_from_telegram; else echo "Batal."; fi
        read -p "Tekan enter untuk lanjut..."
        ;;
      10)
        initial_setup
        ;;
      11) echo "Bye."; exit 0 ;;
      *) echo -e "${c_yellow}Pilihan tidak valid.${c_reset}"; read -p "Tekan enter..." ;;
    esac
  done
}

# --- Entry point: CLI or interactive ---
# Run initial setup if needed (only for interactive mode)
if [ "$#" -eq 0 ]; then
  # Check if initial setup needed
  if [ ! -f "$USERS_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    initial_setup
  fi
  interactive_menu
  exit 0
fi

# For CLI commands, ensure files exist
if [ ! -f "$USERS_FILE" ]; then
  mkdir -p /etc/zivpn
  echo "[]" > "$USERS_FILE"
  chmod 600 "$USERS_FILE"
  chown root:root "$USERS_FILE"
fi
if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p /etc/zivpn
  echo '{"config":["zi"]}' > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  chown root:root "$CONFIG_FILE"
fi

case "$1" in
  setup) initial_setup ;;
  add) shift; add_user_cli "$1" "$2" ;;
  del) shift; del_user_cli "$1" ;;
  list) list_users_cli ;;
  info) shift; info_user_cli "$1" ;;
  expire) shift; expire_user_cli "$1" ;;
  regen) regen_config ;;
  backup) # backup [tg]
    if [ "$2" = "tg" ] || [ "$2" = "telegram" ]; then backup_send_telegram_cmd; else backup_command; fi
    ;;
  restore)
    if [ "$2" = "tg" ] || [ "$2" = "telegram" ]; then restore_from_telegram; else echo "restore requires 'tg' or 'telegram' as source"; fi
    ;;
  *) echo "Unknown command"; exit 1 ;;
esac
