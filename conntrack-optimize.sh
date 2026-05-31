#!/bin/bash

echo "=== Optimasi nf_conntrack ==="

# Naikkan limit conntrack
cat > /etc/sysctl.d/99-conntrack.conf << 'EOF'
net.netfilter.nf_conntrack_max = 262144

net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 300

net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
EOF

# Terapkan
sysctl --system

# Tampilkan hasil
echo
echo "=== Status Saat Ini ==="
echo "nf_conntrack_max:"
cat /proc/sys/net/netfilter/nf_conntrack_max

echo
echo "nf_conntrack_count:"
cat /proc/sys/net/netfilter/nf_conntrack_count

echo
echo "Memory:"
free -h

echo
echo "Selesai."