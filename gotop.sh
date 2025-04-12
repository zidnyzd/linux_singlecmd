#!/bin/bash

# Ask user for interface
read -p "Masukkan nama interface yang akan digunakan (contoh: eth0): " INTERFACE

# Cek dan install golang jika belum ada
if ! command -v go &> /dev/null; then
  echo "[INFO] Golang tidak ditemukan. Menginstall Go 1.24.2..."
  cd /tmp
  wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
  source ~/.bashrc
  echo "[OK] Golang terinstall."
fi

# Clone gotop
cd /tmp
rm -rf gotop
git clone https://github.com/xxxserxxx/gotop.git
cd gotop

# Build gotop
VERS="$(git tag -l --sort=-v:refname | sed 's/v\([^-].*\)/\1/g' | head -1 | tr -d '-' ).$(git describe --long --tags | sed 's/\([^-].*\)-\([0-9]*\)-\(g.*\)/r\2.\3/g' | tr -d '-')"
DAT=$(date +%Y%m%dT%H%M%S)
go build -o gotop -ldflags "-X main.Version=v${VERS} -X main.BuildDate=${DAT}" ./cmd/gotop

# Remove existing binary if any
if [ -f /usr/local/bin/gotop ]; then
  echo "[INFO] Menghapus binary gotop sebelumnya..."
  rm -f /usr/local/bin/gotop
fi

# Copy to /usr/local/bin
cp gotop /usr/local/bin/
chmod +x /usr/local/bin/gotop

# Generate config
gotop --write-config

# Update config dengan interface pilihan
CONFIG_FILE="$HOME/.config/gotop/gotop.conf"
if [ -f "$CONFIG_FILE" ]; then
  sed -i "/^interface = /c\interface = \"$INTERFACE\"" "$CONFIG_FILE"
else
  echo "interface = \"$INTERFACE\"" >> "$CONFIG_FILE"
fi

echo "[✅ SELESAI] gotop berhasil terinstall dan dikonfigurasi."
echo "[ℹ️  INFO] Jalankan dengan perintah: gotop"
