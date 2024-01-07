# Update package lists
sudo apt update -y
sleep 2

# Install necessary packages
sudo apt-get install git build-essential cmake automake libtool autoconf screen htop -y
sleep 2

# Clone xmrig repository
git clone https://github.com/xmrig/xmrig.git
sleep 2

# Navigate to xmrig scripts directory and build dependencies
mkdir xmrig/build && cd xmrig/scripts
./build_deps.sh && cd ../build
cmake .. -DXMRIG_DEPS=scripts/deps
sleep 2

# Compile xmrig
make -j$(nproc)
sleep 2

# Create xmrig configuration file
cat > /root/xmrig/build/config.json << EOF
{
    "autosave": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "rx.unmineable.com:443",
            "user": "TRX:TH1qe8x7dhoWKwtYvWvmh52N6B4y438Lwo.coba22",
            "pass": "test",
            "keepalive": true,
            "tls": true
        }
    ]
}
EOF

# Configure memory and CPU limits
mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/50-memory.conf << EOF
[Slice]
MemoryMax=8G
CPUQuota=500%
EOF

sleep 2

# Reload systemd configuration
systemctl daemon-reload
sleep 2

# Start xmrig within a screen session
screen -S xmrig_session -d -m /root/xmrig/build/./xmrig
