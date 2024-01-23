#!/bin/bash

# Meminta input dari pengguna
echo "Contoh Input Token (TRX)"
echo "Contoh Input Alamat Coin / Token + Refferal (TH1qe8x7dhoWKwtYvWvmh52N6B4y438Lwo.coba7#m4w4-m8hv)"
echo "Contoh Input CPU (1) Otomatis akan dilimit 80% PerCore CPU"
echo "Contoh Input RAM (1) dalam satuan GB"
read -p "Input nama TOKEN : " username
read -p "Input Address Coin/Token + Referral : " xmrig_password
read -p "Input Jumlah CPU : " cpu
read -p "Input Kapasitas RAM : " ram

# Perhitungan CPUQuota sesuai dengan kriteria (80% per core)
cpu_quota=$((cpu * 80))

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
cmake .. -DXMRIG_DEPS=scripts/deps -DWITH_TLS=OFF
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
            "url": "rx.unmineable.com:80",
            "user": "$username:$xmrig_password",
            "pass": "test",
            "keepalive": true,
            "tls": false
        }
    ]
}
EOF
sleep 2

# Mengonfigurasi batasan memori dan CPU
mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/50-memory.conf << EOF
[Slice]
MemoryMax=${ram}G
CPUQuota=${cpu_quota}%
EOF
sleep 2

# Memuat ulang konfigurasi systemd
systemctl daemon-reload
sleep 2

# Memulai xmrig dalam sesi screen
screen -S xmrig_session -d -m /root/xmrig/build/./xmrig

# Menambahkan konfigurasi systemd untuk memulai kembali saat reboot
cat > /etc/systemd/system/xmrig-restart.service << EOF
[Unit]
Description=XMRig Restart Service
After=network.target

[Service]
ExecStart=/usr/bin/screen -S xmrig_session -d -m /root/xmrig/build/./xmrig
Restart=always
User=root

[Install]
WantedBy=default.target
EOF
sleep 2

# Memulai layanan dan mengaktifkannya agar dimulai saat reboot
systemctl start xmrig-restart.service
systemctl enable xmrig-restart.service

echo "Setup selesai. Xmrig akan mulai dijalankan secara otomatis."