#!/bin/bash

echo "[1/6] Pastikan grup & user Debian-exim ada (sementara, agar dpkg bisa jalan)..."
if ! getent group Debian-exim >/dev/null; then
  addgroup --system Debian-exim
fi
if ! id -u Debian-exim >/dev/null 2>&1; then
  adduser --system --home /var/spool/exim4 --no-create-home --ingroup Debian-exim --disabled-login Debian-exim
fi

echo "[2/6] Cek entri statoverride yang menyebut Debian-exim..."
grep -n 'Debian-exim' /var/lib/dpkg/statoverride || true

echo "[3/6] Hapus entri statoverride yang bermasalah..."
# Format file: <mode> <user> <group> <path>
if grep -q 'Debian-exim' /var/lib/dpkg/statoverride; then
  # Hapus dengan dpkg-statoverride agar bersih
  while read -r path; do
    echo "  -> remove override: $path"
    dpkg-statoverride --remove "$path" || true
  done < <(awk '$3 == "Debian-exim" {print $4}' /var/lib/dpkg/statoverride)

  # Jika masih ada sisa (format tidak biasa), fallback edit langsung:
  if grep -q 'Debian-exim' /var/lib/dpkg/statoverride; then
    cp -a /var/lib/dpkg/statoverride /var/lib/dpkg/statoverride.bak.$(date +%F-%H%M%S)
    sed -i '/Debian-exim/d' /var/lib/dpkg/statoverride
  fi
fi

echo "[4/6] Perbaiki state dpkg/apt..."
dpkg --configure -a || true
apt-get -f install -y || true

echo "[5/6] (Opsional) Jika TIDAK pakai exim, purge paketnya..."
# Komentari baris berikut jika Anda tetap gunakan exim
# apt-get purge -y exim4-base exim4-config exim4-daemon-light exim4-daemon-heavy exim4 || true

echo "[5b/6] (Opsional) Jika memang BUTUH exim, reinstall agar membuat override/permission yang benar..."
# Hanya jalankan salah satu dari 5 atau 5b. Contoh reinstall ringan:
# apt-get install -y --reinstall exim4-base exim4-config exim4-daemon-light

echo "[6/6] Final check"
dpkg --audit || true
echo "Selesai."