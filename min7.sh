sudo apt update -y
sleep 2
sudo apt-get install git build-essential cmake automake libtool autoconf htop -y
sleep 2
git clone https://github.com/xmrig/xmrig.git
sleep 2
mkdir xmrig/build && cd xmrig/scripts
./build_deps.sh && cd ../build
cmake .. -DXMRIG_DEPS=scripts/deps
sleep 2
make -j$(nproc)
sleep 2

cat > /root/xmrig/build/config.json << EOF
{
    "autosave": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "url": "rx.unmineable.com:443",
            "user": "TRX:TH1qe8x7dhoWKwtYvWvmh52N6B4y438Lwo.coba6",
            "pass": "test",
            "keepalive": true,
            "tls": true
        }
    ]
}
EOF

mkdir -p /etc/systemd/system/user-.slice.d
cat > /etc/systemd/system/user-.slice.d/50-memory.conf << EOF
[Slice]
MemoryMax=8G
CPUQuota=300%
EOF

sleep 2
systemctl daemon-reload
sleep 2

/root/xmrig/build/./xmrig

