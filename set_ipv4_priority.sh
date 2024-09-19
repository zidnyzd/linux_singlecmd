#!/bin/bash

# Memastikan script dijalankan dengan hak akses root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

echo "Configuring sysctl to ensure IPv6 is enabled but not prioritized..."

# Membuat file konfigurasi sysctl untuk memastikan IPv6 tetap aktif
cat <<EOL > /etc/sysctl.d/99-ipv4-priority.conf
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
EOL

# Menerapkan konfigurasi sysctl
sysctl -p /etc/sysctl.d/99-ipv4-priority.conf

echo "Updating /etc/gai.conf to prioritize IPv4 over IPv6..."

# Backup file gai.conf jika belum ada backup
if [ ! -f /etc/gai.conf.bak ]; then
  cp /etc/gai.conf /etc/gai.conf.bak
fi

# Mengedit /etc/gai.conf untuk memprioritaskan IPv4
grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf

echo "Restarting networking service to apply changes..."

# Restart layanan jaringan untuk menerapkan perubahan
systemctl restart networking || echo "Failed to restart networking. Please reboot the system manually."

echo "Configuration complete. IPv4 should now be prioritized over IPv6."
