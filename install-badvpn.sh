#!/bin/bash

set -e

echo "=== Install dependency ==="
apt update -y
apt install -y make cmake gcc wget unzip

echo "=== Download badvpn ==="
cd /root
wget -q https://github.com/ambrop72/badvpn/archive/refs/tags/1.999.130.zip
unzip -o 1.999.130.zip

echo "=== Build badvpn ==="
cd badvpn-1.999.130
cmake . -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make install

echo "=== Buat systemd service ==="
cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:9090 --max-clients 1000
Restart=always
RestartSec=3
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reload & start service ==="
systemctl daemon-reload
systemctl enable badvpn
systemctl restart badvpn

echo "=== Status ==="
systemctl status badvpn --no-pager

echo "=== Done ==="
