#!/bin/bash

# Periksa apakah file /etc/resolv.conf adalah symlink
if [ -L /etc/resolv.conf ]; then
    echo "/etc/resolv.conf is a symlink. Removing it..."
    rm -f /etc/resolv.conf
else
    echo "/etc/resolv.conf is not a symlink."
fi

# Membuat file resolv.conf statis
cat << EOF > /etc/resolv.conf
# Static resolv.conf
nameserver 45.90.28.109
nameserver 45.90.30.109
EOF

echo "DNS configuration has been set to 45.90.28.109 and 45.90.30.109."

# Melindungi file resolv.conf dari perubahan
chattr +i /etc/resolv.conf

echo "File /etc/resolv.conf is now immutable. Changes by systemd-resolved or other processes are disabled."

# Menonaktifkan systemd-resolved jika diperlukan
read -p "Do you want to disable systemd-resolved to avoid conflicts? [y/N]: " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    systemctl disable --now systemd-resolved
    echo "systemd-resolved has been disabled."
else
    echo "systemd-resolved is still running. Ensure it does not conflict with /etc/resolv.conf."
fi
