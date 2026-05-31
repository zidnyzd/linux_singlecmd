#!/bin/bash

echo "================================="
echo " Conntrack Optimization Script"
echo "================================="

# Pastikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    echo "Jalankan sebagai root."
    exit 1
fi

cat > /etc/sysctl.d/99-conntrack-tuning.conf <<EOF
# Conntrack Optimization

net.netfilter.nf_conntrack_max = 200000

# Faster cleanup
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 300

# Optional tuning
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
EOF

sysctl --system

echo ""
echo "===== RESULT ====="
echo -n "nf_conntrack_max: "
cat /proc/sys/net/netfilter/nf_conntrack_max

echo -n "current conntrack count: "
cat /proc/sys/net/netfilter/nf_conntrack_count

echo ""
echo "Optimization completed."