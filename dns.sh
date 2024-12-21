#!/bin/bash

# Nama file resolv.conf
RESOLV_CONF="/etc/resolv.conf"

# Backup file resolv.conf sebelumnya
if [ ! -f "${RESOLV_CONF}.backup" ]; then
    cp "$RESOLV_CONF" "${RESOLV_CONF}.backup"
    echo "Backup created at ${RESOLV_CONF}.backup"
fi

# Menulis ulang konfigurasi resolv.conf
cat << EOF > "$RESOLV_CONF"
# Static resolv.conf
nameserver 45.90.28.109
nameserver 45.90.30.109
EOF

echo "DNS has been set to 45.90.28.109 and 45.90.30.109."

# Melindungi resolv.conf agar tidak bisa diubah proses lain
chattr +i "$RESOLV_CONF"

echo "File $RESOLV_CONF is now immutable. Changes by other processes are disabled."

# Informasi tambahan
echo "To edit or restore resolv.conf, run: chattr -i $RESOLV_CONF"
