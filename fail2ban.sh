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

        echo "[💾] Menyimpan kredensial ke /root/.vars..."
        cat <<EOF > /root/.vars
bot_token="$bot_token"
telegram_id="$telegram_id"
EOF
        chmod 600 /root/.vars
    else
        TELEGRAM_ENABLED=false
        echo "[⏩] Melewati notifikasi Telegram."
    fi
fi

# ========== INSTALL FAIL2BAN (dan curl untuk Telegram) ==========
echo "[📦] Menginstal Fail2Ban..."
sudo apt update && sudo apt install -y fail2ban curl

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
actionban   = . /root/.vars && curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" -d chat_id="${telegram_id}" -d text="🚫 IP <ip> telah diblokir oleh Fail2Ban (jail: <name>)."
actionunban = . /root/.vars && curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" -d chat_id="${telegram_id}" -d text="✅ IP <ip> telah di-unban oleh Fail2Ban (jail: <name>)."
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
