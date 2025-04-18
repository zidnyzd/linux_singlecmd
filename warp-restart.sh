#!/bin/bash

# Cek apakah cron sudah terpasang
if ! command -v crontab &> /dev/null; then
  echo "cron belum terpasang. Silakan install terlebih dahulu."
  exit 1
fi

# Tambah cron job jika belum ada
cron_job="0 * * * * /bin/systemctl restart warp-go"
(crontab -l 2>/dev/null | grep -Fv "$cron_job" ; echo "$cron_job") | crontab -

echo "✅ Cron job berhasil ditambahkan: restart warp-go tiap 1 jam"
