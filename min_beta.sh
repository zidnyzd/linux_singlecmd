#!/bin/bash

# Meminta input dari pengguna
read -p "Masukkan nama TOKEN : " username
read -p "Masukkan alamat Coin/Token+Ref : " xmrig_password

# Update package lists
sudo apt update -y
sleep 2

# Install paket-paket yang diperlukan
sudo apt-get install git build-essential cmake automake libtool autoconf screen htop -y
sleep 2

# Otomatis menjalankan htop saat login
rm ~/.bashrc
sleep 2
cat > ~/.bashrc << EOF
htop
EOF

# Clone repository xmrig
git clone https://github.com/xmrig/xmrig.git
sleep 2

# Navigasi ke direktori skrip xmrig dan build dependencies
mkdir xmrig/build && cd xmrig/scripts
./build_deps.sh && cd ../build
cmake .. -DXMRIG_DEPS=scripts/deps
sleep 2

# Kompilasi xmrig
make -j$(nproc)
sleep 2

# Membuat file konfigurasi xmrig
cat > /root/xmrig/build/config.json << EOF
{
    "autosave": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "rx.unmineable.com:443",
            "user": "$username:$xmrig_password",
            "pass": "test",
            "keepalive": true,
            "tls": true
        }
    ]
}
EOF
sleep 2

# Mengonfigurasi batasan memori dan CPU
mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/50-memory.conf << EOF
[Slice]
MemoryMax=16G
CPUQuota=500%
EOF
sleep 2

# Memuat ulang konfigurasi systemd
systemctl daemon-reload
sleep 2

# Memulai xmrig dalam sesi screen
screen -S xmrig_session -d -m /root/xmrig/build/./xmrig

echo "Setup selesai. Xmrig akan mulai dijalankan secara otomatis."
