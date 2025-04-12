#!/bin/bash

# Ask for network interface
read -p "Masukkan nama interface yang akan digunakan (contoh: eth0): " INTERFACE

# Detect current shell config file
SHELL_NAME=$(basename "$SHELL")
if [[ "$SHELL_NAME" == "zsh" ]]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

# Install Go if not exists
if ! command -v go &> /dev/null; then
  echo "[INFO] Golang tidak ditemukan. Menginstall Go 1.24.2..."
  cd /tmp
  wget https://go.dev/dl/go1.24.2.linux-amd64.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf go1.24.2.linux-amd64.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin' >> "$SHELL_RC"
  export PATH=$PATH:/usr/local/go/bin
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

# Remove old binary
if [ -f /usr/local/bin/gotop ]; then
  echo "[INFO] Menghapus gotop lama dari /usr/local/bin"
  rm -f /usr/local/bin/gotop
fi

# Move new binary
cp gotop /usr/local/bin/
chmod +x /usr/local/bin/gotop

# Tambahkan alias ke shell rc
if ! grep -q "alias gotop=" "$SHELL_RC"; then
  echo "alias gotop='gotop --interface=$INTERFACE'" >> "$SHELL_RC"
  echo "[OK] Alias ditambahkan ke $SHELL_RC"
else
  sed -i "s|alias gotop=.*|alias gotop='gotop --interface=$INTERFACE'|" "$SHELL_RC"
  echo "[UPDATED] Alias gotop diperbarui di $SHELL_RC"
fi

# Source shell config supaya alias langsung aktif
echo "[INFO] Memuat ulang shell agar alias aktif..."
exec "$SHELL"

# Akhir
echo -e "\n✅ gotop berhasil diinstall dan dikonfigurasi!"
echo "ℹ️  Silakan jalankan 'gotop' dari terminal mana saja."
