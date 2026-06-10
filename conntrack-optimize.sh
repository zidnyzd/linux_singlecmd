#!/bin/bash

echo "=== Optimasi nf_conntrack ==="

# 1. Pastikan modul nf_conntrack di-load SEKARANG (biar key sysctl tersedia)
modprobe nf_conntrack 2>/dev/null

# 2. Pastikan modul di-load otomatis SETIAP BOOT
#    Tanpa ini, key net.netfilter.* belum ada saat systemd-sysctl jalan,
#    sehingga setting "reset" ke default setelah reboot.
cat > /etc/modules-load.d/nf_conntrack.conf << 'EOF'
nf_conntrack
EOF

# 3. Set hashsize modul (opsional tapi disarankan biar konsisten dgn max)
#    Berlaku saat modul di-load.
echo "options nf_conntrack hashsize=65536" > /etc/modprobe.d/nf_conntrack.conf

# 4. Naikkan limit conntrack (persisten)
cat > /etc/sysctl.d/99-conntrack.conf << 'EOF'
net.netfilter.nf_conntrack_max = 262144

net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_established = 300

net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
EOF

# 5. Terapkan sekarang
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
echo "Selesai. Setting akan tetap persisten setelah reboot."
