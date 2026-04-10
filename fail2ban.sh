#!/bin/bash

# Pastikan script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Tolong jalankan script ini sebagai root (gunakan sudo)."
  exit 1
fi

echo "=========================================================="
echo "🛡️ Memulai Instalasi Fail2ban Agresif (1x Gagal = Ban IP) 🛡️"
echo "=========================================================="

# 1. Update dan install paket
echo "⏳ [1/4] Update sistem dan menginstal Fail2ban & Rsyslog..."
apt-get update -y
apt-get install fail2ban rsyslog python3-systemd iptables -y

# 2. Konfigurasi Log (Rsyslog)
echo "⏳ [2/4] Mengatur sistem log agar Fail2ban tidak crash..."
systemctl enable rsyslog
systemctl start rsyslog
touch /var/log/auth.log # Membuat file log pancingan

# 3. Membuat konfigurasi jail.local
echo "⏳ [3/4] Menyuntikkan aturan agresif ke jail.local..."
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
# ⚠️ PENTING: Jika Anda punya IP Statis, tambahkan di sebelah ::1 (pisahkan dengan spasi)
ignoreip = 127.0.0.1/8 ::1
bantime  = 86400
findtime = 600
maxretry = 1
banaction = iptables-allports
protocol = all

[sshd]
enabled = true
port    = ssh
logpath = /var/log/auth.log
backend = polling
EOF

# 4. Restart layanan
echo "⏳ [4/4] Menerapkan konfigurasi dan menyalakan Fail2ban..."
systemctl enable fail2ban
systemctl restart fail2ban

echo "=========================================================="
echo "✅ Instalasi Selesai! Server Anda sekarang dikunci ketat."
echo "=========================================================="
echo "📊 Status Fail2ban (Jail SSHD):"
sleep 2
fail2ban-client status sshd