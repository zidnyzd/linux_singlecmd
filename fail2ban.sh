#!/bin/bash

echo "[🚀] Memulai setup Fail2Ban dengan pemblokiran total dan notifikasi Telegram opsional..."

# ========== HARD RESET FAIL2BAN ==========
echo "[⚠️] Melakukan hard reset Fail2Ban..."
sudo systemctl stop fail2ban
sudo apt purge --remove fail2ban -y
sudo rm -rf /etc/fail2ban
sudo rm -rf /var/lib/fail2ban
sudo rm -rf /var/run/fail2ban
sudo rm -rf /var/log/fail2ban.log
sudo iptables -D INPUT -j f2b-sshd 2>/dev/null
sudo iptables -F f2b-sshd 2>/dev/null
sudo iptables -X f2b-sshd 2>/dev/null
sudo iptables -L -n --line-numbers
sudo iptables -F
sudo iptables -X

# ========== CEK /root/.vars ==========
TELEGRAM_ENABLED=true
if [ -f /root/.vars ]; then
    echo "[ℹ️] File /root/.vars sudah ada. Lewati input token Telegram."
else
    echo "[❓] Apakah ingin mengaktifkan notifikasi Telegram saat IP diblokir? (y/n)"
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

# ========== INSTALL FAIL2BAN ==========
echo "[📦] Menginstal Fail2Ban..."
apt update && apt install fail2ban -y

# ========== ACTION UNTUK BLOK TOTAL ==========
echo "[🛡️] Membuat action iptables-ban.conf untuk blokir semua trafik..."
cat <<'EOF' > /etc/fail2ban/action.d/iptables-ban.conf
[Definition]
actionban = /sbin/iptables -I INPUT -s <ip> -j DROP
actionunban = /sbin/iptables -D INPUT -s <ip> -j DROP
EOF

# ========== (OPSIONAL) ACTION UNTUK TELEGRAM ==========
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

# ========== BUAT JAIL.LOCAL ==========
echo "[📄] Menyiapkan konfigurasi jail.local..."
rm -f /etc/fail2ban/jail.local

cat <<EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 1
findtime = 60
bantime = 86400
action =
    iptables-ban
EOF

if [ "$TELEGRAM_ENABLED" = true ]; then
    echo "    telegram-ban" >> /etc/fail2ban/jail.local
fi

# ========== RESTART FAIL2BAN ==========
echo "[🔁] Me-restart Fail2Ban..."
systemctl restart fail2ban
fail2ban-client reload

# ========== SELESAI ==========
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
