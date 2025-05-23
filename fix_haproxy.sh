#!/bin/bash

CONFIG="/etc/haproxy/haproxy.cfg"
BACKUP="/etc/haproxy/haproxy.cfg.bak"

echo "Pilih timeout yang ingin diterapkan:"
echo "1) 60s"
echo "2) 30s"
read -rp "Masukkan pilihan Anda [1/2]: " pilihan

case $pilihan in
    1)
        TIMEOUT="60s"
        ;;
    2)
        TIMEOUT="30s"
        ;;
    *)
        echo "Pilihan tidak valid."
        exit 1
        ;;
esac

# Backup terlebih dahulu
cp "$CONFIG" "$BACKUP" && echo "Backup disimpan di $BACKUP"

# Lakukan penggantian pada baris timeout client/server
sed -i -E \
    -e "s/^(\s*timeout\s+client\s+).*/\1$TIMEOUT/" \
    -e "s/^(\s*timeout\s+server\s+).*/\1$TIMEOUT/" \
    "$CONFIG"

echo "Timeout client dan server telah diperbarui menjadi $TIMEOUT"

# Tampilkan perubahan
echo "Ringkasan perubahan:"
grep -E 'timeout\s+(client|server)' "$CONFIG"

# (Opsional) Restart HAProxy
read -rp "Ingin me-restart HAProxy sekarang? [y/n]: " restart
if [[ "$restart" =~ ^[Yy]$ ]]; then
    systemctl restart haproxy && echo "HAProxy berhasil direstart." || echo "Gagal me-restart HAProxy."
fi
