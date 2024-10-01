#!/bin/bash

# Memastikan script dijalankan dengan hak akses root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Update dan install fail2ban
echo "Updating package lists and installing fail2ban..."
apt update && apt upgrade -y
apt install fail2ban -y

# Backup konfigurasi default fail2ban
echo "Backing up default fail2ban configuration..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak

# Membuat file jail.local untuk konfigurasi kustom fail2ban
echo "Creating jail.local for custom configuration..."
cat <<EOL > /etc/fail2ban/jail.local
[DEFAULT]
bantime = -1      # Ban selamanya
findtime = 10m    # Cari kesalahan login dalam 10 menit
maxretry = 1      # Ban setelah 1 kali percobaan gagal
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
EOL

# Restart dan aktifkan fail2ban
echo "Restarting fail2ban service..."
systemctl restart fail2ban
systemctl enable fail2ban

# Periksa status fail2ban
echo "Fail2ban has been installed and configured for permanent ban."
fail2ban-client status sshd
