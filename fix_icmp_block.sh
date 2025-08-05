#!/bin/bash

# Script untuk memperbaiki ICMP blocking yang tidak berfungsi
echo "🔧 Fixing ICMP blocking for banned IPs..."

# Memastikan chain fail2ban-icmp-block ada
iptables -L fail2ban-icmp-block >/dev/null 2>&1 || iptables -N fail2ban-icmp-block

# Memastikan rule ICMP ada di INPUT chain
iptables -C INPUT -p icmp -j fail2ban-icmp-block >/dev/null 2>&1 || iptables -I INPUT -p icmp -j fail2ban-icmp-block

# Ambil semua IP yang di-ban dari fail2ban
echo "📋 Getting banned IPs from fail2ban..."
banned_ips=$(fail2ban-client status sshd | grep "Banned IP list:" | sed 's/.*Banned IP list:[[:space:]]*//' | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

if [ -z "$banned_ips" ]; then
    echo "ℹ️  No banned IPs found"
else
    echo "🚫 Found banned IPs: $banned_ips"
    
    # Tambahkan setiap IP ke ICMP block chain
    for ip in $banned_ips; do
        echo "➕ Adding $ip to ICMP block chain..."
        iptables -C fail2ban-icmp-block -s $ip -j REJECT >/dev/null 2>&1 || iptables -I fail2ban-icmp-block 1 -s $ip -j REJECT
    done
    
    echo "✅ ICMP blocking fixed!"
    echo ""
    echo "📊 Current ICMP block chain:"
    iptables -L fail2ban-icmp-block -n
fi 