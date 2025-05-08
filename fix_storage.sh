#!/bin/bash

echo "🚀 Memulai proses fix penuh disk karena log OpenVPN..."

# 1. Cek apakah file log besar ada
LOG_FILE="/etc/openvpn/log-tcp.log"
if [ -f "$LOG_FILE" ]; then
  echo "✅ File ditemukan: $LOG_FILE"
  echo "📛 Mengosongkan isi file log tanpa menghapusnya..."
  truncate -s 0 "$LOG_FILE"
else
  echo "⚠️ File log $LOG_FILE tidak ditemukan."
fi

# 2. Buat konfigurasi logrotate untuk OpenVPN jika belum ada
LOGROTATE_FILE="/etc/logrotate.d/openvpn"
if [ ! -f "$LOGROTATE_FILE" ]; then
  echo "🛠️  Membuat file logrotate: $LOGROTATE_FILE"
  cat <<EOF > "$LOGROTATE_FILE"
/etc/openvpn/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 root adm
}
EOF
  echo "✅ Logrotate untuk OpenVPN berhasil ditambahkan."
else
  echo "ℹ️ Logrotate untuk OpenVPN sudah ada. Tidak dibuat ulang."
fi

# 3. Tampilkan penggunaan disk setelah dibersihkan
echo "📊 Penggunaan disk setelah pembersihan:"
df -h /
systemctl restart openvpn
echo "✅ Proses selesai. Disarankan untuk me-restart OpenVPN jika perlu."
