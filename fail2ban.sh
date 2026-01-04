#!/bin/bash

echo "[🚀] Memulai setup Fail2Ban (backend systemd/journald) dengan pemblokiran total..."

# ========== HARD RESET FAIL2BAN ==========
echo "[⚠️] Melakukan hard reset Fail2Ban..."
sudo systemctl stop fail2ban 2>/dev/null
sudo apt purge --remove -y fail2ban
sudo rm -rf /etc/fail2ban
sudo rm -rf /var/lib/fail2ban
sudo rm -rf /var/run/fail2ban
sudo rm -f /var/log/fail2ban.log

# Bersihkan rule fail2ban lama saja (tanpa flush semua iptables)
if sudo iptables -S INPUT 2>/dev/null | grep -q "\-j f2b-sshd"; then
  sudo iptables -D INPUT -j f2b-sshd 2>/dev/null
fi
if sudo iptables -nL f2b-sshd >/dev/null 2>&1; then
  sudo iptables -F f2b-sshd 2>/dev/null
  sudo iptables -X f2b-sshd 2>/dev/null
fi

# ========== TELEGRAM DISABLED ==========
TELEGRAM_ENABLED=false

# ========== INSTALL FAIL2BAN ==========
echo "[📦] Menginstal Fail2Ban..."
sudo apt update && sudo apt install -y fail2ban
# ========== TELEGRAM HELPER REMOVED ==========
# Telegram notification functionality has been removed

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

# ========== TELEGRAM ACTION REMOVED ==========
# Telegram action configuration has been removed

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

# Aksi: blok total via iptables
action    = iptables-ban
EOF

# ========== RESTART FAIL2BAN ==========
echo "[🔁] Me-restart Fail2Ban..."
sudo systemctl enable --now fail2ban
sudo fail2ban-client reload || sudo systemctl restart fail2ban

# ========== STATUS ==========
echo ""
echo "[✅] Setup selesai!"
echo "• Backend: systemd (journald) dengan mode=aggressive."
echo "• IP yang gagal login SSH akan diblokir total (DROP di INPUT)."
echo "• Notifikasi Telegram telah dihapus."

echo ""
echo "[🧪] Uji cepat:"
echo "  - Tampilkan log SSH dari journald: journalctl -u ssh --since \"-10m\" | tail -n 30"
echo "  - Tes ban manual: sudo fail2ban-client set sshd banip 1.2.3.4"
echo "  - Cek status jail: fail2ban-client status sshd"
