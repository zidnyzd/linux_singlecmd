#!/bin/bash

echo "=== Stop & disable service ==="
systemctl stop badvpn 2>/dev/null
systemctl disable badvpn 2>/dev/null

echo "=== Hapus service ==="
rm -f /etc/systemd/system/badvpn.service
systemctl daemon-reload

echo "=== Kill process jika masih ada ==="
pkill badvpn-udpgw 2>/dev/null

echo "=== Hapus binary ==="
rm -f /usr/local/bin/badvpn-udpgw

echo "=== Hapus source build ==="
rm -rf /root/badvpn-1.999.130
rm -f /root/1.999.130.zip

echo "=== Done rollback ==="
