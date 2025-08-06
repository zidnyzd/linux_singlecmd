#!/bin/bash

echo "[🚀] Memulai setup Fail2Ban dengan pemblokiran total dan notifikasi Telegram opsional..."

# ===== CEK /root/.vars =====
TELEGRAM_ENABLED=true
if [ -f /root/.vars ]; then
    echo "[ℹ️] File /root/.vars sudah ada. Lewati input token Telegram."
else
    echo -n "[❓] Aktifkan notifikasi Telegram saat IP diblokir? (y/n): "
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

# ===== INSTALL FAIL2BAN =====
echo "[📦] Menginstal Fail2Ban..."
apt update -y && apt install fail2ban -y

# ===== ACTION iptables-ban =====
echo "[🛡️] Membuat action iptables-ban.conf..."
cat <<'EOF' > /etc/fail2ban/action.d/iptables-ban.conf
[Definition]
actionban = /sbin/iptables -I INPUT -s <ip> -j DROP
actionunban = /sbin/iptables -D INPUT -s <ip> -j DROP
EOF

# ===== ACTION telegram-ban (jika diaktifkan) =====
if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "[📨] Membuat action telegram-ban.conf..."
    cat <<'EOF' > /etc/fail2ban/action.d/telegram-ban.conf
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = . /root/.vars && curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" -d chat_id="${telegram_id}" -d text="🚫 IP <ip> telah diblokir oleh Fail2Ban karena login SSH gagal."
actionunban = . /root/.vars && curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" -d chat_id="${telegram_id}" -d text="✅ IP <ip> telah dibuka dari blokir Fail2Ban."
[Init]
EOF
fi

# ===== BUAT jail.local =====
echo "[📄] Menyiapkan /etc/fail2ban/jail.local..."
if [ "$TELEGRAM_ENABLED" = true ]; then
    cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 1
findtime = 60
bantime = 86400
action = iptables-ban
         telegram-ban
EOF
else
    cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 1
findtime = 60
bantime = 86400
action = iptables-ban
EOF
fi

# ===== RESTART FAIL2BAN =====
echo "[🔁] Me-restart Fail2Ban..."
systemctl restart fail2ban
sleep 3

if systemctl is-active --quiet fail2ban; then
    echo "[✅] Fail2Ban berhasil dijalankan!"
    fail2ban-client reload
else
    echo "[❌] Gagal menjalankan Fail2Ban. Silakan cek dengan:"
    echo "     sudo journalctl -xeu fail2ban"
    exit 1
fi

# ===== DONE =====
echo ""
echo "[✅] Setup selesai!"
echo "• IP yang mencoba login gagal akan diblokir total (semua koneksi)."
if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "• Notifikasi akan dikirim ke Telegram."
else
    echo "• Notifikasi Telegram tidak diaktifkan."
fi
echo ""
echo "[🧪] Contoh test:"
echo "    sudo fail2ban-client set sshd banip 1.2.3.4"
echo "    sudo iptables -L -n | grep 1.2.3.4"
