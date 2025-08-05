#!/bin/bash

# =============================================================================
# FAIL2BAN COMPLETE SETUP SCRIPT
# =============================================================================
# Script ini menginstall dan mengkonfigurasi fail2ban dengan fitur lengkap:
# - SSH protection dengan permanent ban
# - ICMP (ping) blocking untuk IP yang di-ban
# - Telegram notifications untuk security alerts
# - Automatic maintenance dan sync IP
# - Semua dalam satu script (tidak perlu script tambahan)
# =============================================================================

# Function untuk test Telegram notifications
test_telegram() {
    echo "🧪 Testing Telegram Notifications..."
    
    # Load variables from .vars file
    if [ -f ".vars" ]; then
        source .vars
        echo "Loaded Telegram bot configuration from .vars file"
    else
        echo "Error: .vars file not found"
        exit 1
    fi
    
    # Test 1: Basic connectivity
    echo "Test 1: Basic Telegram connectivity..."
    test_message="🧪 FAIL2BAN TELEGRAM TEST 🧪%0A%0A✅ Basic connectivity test%0A✅ Server: $(hostname)%0A✅ Time: $(date '+%Y-%m-%d %H:%M:%S')%0A%0A🔔 This is a test message to verify Telegram notifications are working."
    
    if curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=${telegram_id}" \
        -d "text=${test_message}" > /dev/null; then
        echo "✅ Test 1 PASSED: Basic connectivity works"
    else
        echo "❌ Test 1 FAILED: Basic connectivity failed"
        exit 1
    fi
    
    # Test 2: Simulate ban notification
    echo "Test 2: Simulating ban notification..."
    ban_message="🚨 FAIL2BAN ALERT 🚨%0A%0A🔴 IP Address: 192.168.1.100%0A🔴 Jail: SSH%0A🔴 Action: BANNED%0A🔴 Time: $(date '+%Y-%m-%d %H:%M:%S')%0A🔴 Server: $(hostname)%0A%0A⚠️ This IP has been permanently banned for suspicious activity.%0A%0A🛡️ ICMP blocking also activated for this IP.%0A%0A🧪 This is a TEST notification"
    
    if curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=${telegram_id}" \
        -d "text=${ban_message}" > /dev/null; then
        echo "✅ Test 2 PASSED: Ban notification format works"
    else
        echo "❌ Test 2 FAILED: Ban notification failed"
    fi
    
    # Test 3: Check fail2ban action configuration
    echo "Test 3: Checking fail2ban action configuration..."
    if fail2ban-client get sshd actions | grep -q "telegram-notify"; then
        echo "✅ Test 3 PASSED: Telegram action is configured in fail2ban"
    else
        echo "❌ Test 3 FAILED: Telegram action not found in fail2ban"
        echo "Current actions:"
        fail2ban-client get sshd actions
    fi
    
    # Test 4: Check action file
    echo "Test 4: Checking action file..."
    if [ -f "/etc/fail2ban/action.d/telegram-notify.conf" ]; then
        echo "✅ Test 4 PASSED: Action file exists"
        echo "Action file contents:"
        cat /etc/fail2ban/action.d/telegram-notify.conf
    else
        echo "❌ Test 4 FAILED: Action file not found"
    fi
    
    echo ""
    echo "🎉 Telegram notification test completed!"
    echo "Check your Telegram for test messages."
}

# Function untuk fix ICMP blocking
fix_icmp() {
    echo "🔧 Fixing ICMP blocking for banned IPs..."
    
    # Memastikan chain fail2ban-icmp-block ada
    iptables -L fail2ban-icmp-block >/dev/null 2>&1 || iptables -N fail2ban-icmp-block
    
    # Memastikan rule ICMP ada di INPUT chain
    iptables -C INPUT -p icmp -j fail2ban-icmp-block >/dev/null 2>&1 || iptables -I INPUT -p icmp -j fail2ban-icmp-block
    
    # Ambil semua IP yang di-ban dari fail2ban
    echo "📋 Getting banned IPs from fail2ban..."
    banned_status=$(fail2ban-client status sshd | grep "Banned IP list:")
    if [ -n "$banned_status" ]; then
        # Extract IPs using improved method
        banned_ips=$(echo "$banned_status" | sed 's/.*Banned IP list:[[:space:]]*//' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
        
        if [ -n "$banned_ips" ]; then
            echo "Found banned IPs: $banned_ips"
            ip_count=0
            
            for ip in $banned_ips; do
                echo "➕ Adding $ip to ICMP block chain..."
                iptables -C fail2ban-icmp-block -s $ip -j REJECT >/dev/null 2>&1 || iptables -I fail2ban-icmp-block 1 -s $ip -j REJECT
                ((ip_count++))
            done
            
            echo "✅ Successfully added $ip_count IPs to ICMP block chain"
            echo ""
            echo "📊 Current ICMP block chain:"
            iptables -L fail2ban-icmp-block -n
        else
            echo "❌ No valid IPs found in banned list"
        fi
    else
        echo "❌ No banned IPs found"
    fi
}

# Function untuk show status
show_status() {
    echo "📊 FAIL2BAN STATUS REPORT"
    echo "=========================="
    
    # Check fail2ban service
    echo ""
    echo "🔧 Fail2ban Service:"
    if systemctl is-active --quiet fail2ban; then
        echo "✅ Fail2ban is running"
        fail2ban-client status sshd
    else
        echo "❌ Fail2ban is not running"
    fi
    
    # Check ICMP blocking
    echo ""
    echo "🛡️ ICMP Blocking Status:"
    if iptables -L fail2ban-icmp-block >/dev/null 2>&1; then
        echo "✅ ICMP block chain is active"
        banned_in_chain=$(iptables -L fail2ban-icmp-block -n | grep REJECT | awk '{print $4}' | sort -u)
        if [ -n "$banned_in_chain" ]; then
            echo "📋 Banned IPs in ICMP chain:"
            echo "$banned_in_chain"
        else
            echo "⚠️ No IPs in ICMP block chain"
        fi
    else
        echo "❌ ICMP block chain not found"
    fi
    
    # Check Telegram configuration
    echo ""
    echo "📱 Telegram Configuration:"
    if [ -f ".vars" ]; then
        source .vars
        if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
            echo "✅ Telegram credentials configured"
            echo "Bot Token: ${bot_token:0:20}..."
            echo "Chat ID: $telegram_id"
        else
            echo "❌ Telegram credentials not found"
        fi
    else
        echo "❌ .vars file not found"
    fi
    
    # Check log files
    echo ""
    echo "📋 Log Files Status:"
    for logfile in /var/log/auth.log /var/log/secure /var/log/messages; do
        if [ -f "$logfile" ]; then
            echo "✅ $logfile exists"
            recent_failures=$(grep -i "failed password\|authentication failure" "$logfile" | tail -5)
            if [ -n "$recent_failures" ]; then
                echo "   Recent failures:"
                echo "$recent_failures" | sed 's/^/   /'
            fi
        else
            echo "❌ $logfile not found"
        fi
    done
    
    # Check fail2ban log
    echo ""
    echo "🔍 Fail2ban Log (last 10 lines):"
    if [ -f "/var/log/fail2ban.log" ]; then
        tail -10 /var/log/fail2ban.log
    else
        echo "❌ Fail2ban log not found"
    fi
}

# Check command line arguments
if [ "$1" = "--test-telegram" ]; then
    test_telegram
    exit 0
elif [ "$1" = "--fix-icmp" ]; then
    fix_icmp
    exit 0
elif [ "$1" = "--status" ]; then
    show_status
    exit 0
elif [ "$1" = "--fix-config" ]; then
    echo "🔧 Fixing fail2ban configuration..."
    
    # Stop fail2ban
    systemctl stop fail2ban
    
    # Backup current config
    if [ -f "/etc/fail2ban/jail.local" ]; then
        cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.$(date +%Y%m%d_%H%M%S)
        echo "✅ Backed up current configuration"
    fi
    
    # Detect log file
    if [ -f "/var/log/auth.log" ]; then
        ssh_logpath="/var/log/auth.log"
    elif [ -f "/var/log/secure" ]; then
        ssh_logpath="/var/log/secure"
    elif [ -f "/var/log/messages" ]; then
        ssh_logpath="/var/log/messages"
    else
        ssh_logpath="/var/log/auth.log"
    fi
    
    # Load Telegram credentials
    if [ -f ".vars" ]; then
        source .vars
        if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
            telegram_action=", telegram-notify[name=SSH]"
        else
            telegram_action=""
        fi
    else
        telegram_action=""
    fi
    
    # Create clean configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = $ssh_logpath
maxretry = 2
findtime = 600
bantime = -1
action = iptables-multiport[name=SSH, port="ssh,22"], iptables-icmp-block[name=ICMP, protocol=all]$telegram_action
EOF
    
    echo "✅ Created clean configuration using $ssh_logpath"
    
    # Start fail2ban
    if systemctl start fail2ban; then
        echo "✅ Fail2ban started successfully"
        sleep 3
        echo ""
        echo "📊 Current status:"
        fail2ban-client status sshd 2>/dev/null || echo "Service starting..."
    else
        echo "❌ Failed to start fail2ban"
        systemctl status fail2ban
    fi
    
    exit 0
elif [ "$1" = "--restart" ]; then
    echo "🔄 Restarting fail2ban with proper configuration..."
    
    # Stop fail2ban
    systemctl stop fail2ban
    
    # Wait a moment
    sleep 2
    
    # Start fail2ban
    systemctl start fail2ban
    
    # Wait for service to be ready
    sleep 5
    
    # Check status
    if systemctl is-active --quiet fail2ban; then
        echo "✅ Fail2ban restarted successfully"
        echo ""
        echo "📊 Current status:"
        fail2ban-client status sshd 2>/dev/null || echo "Service starting..."
        
        # Re-sync ICMP blocking
        echo ""
        echo "🛡️ Re-syncing ICMP blocking..."
        fix_icmp
    else
        echo "❌ Failed to restart fail2ban"
        systemctl status fail2ban
    fi
    
    exit 0
elif [ "$1" = "--debug" ]; then
    echo "🔍 FAIL2BAN DEBUG MODE"
    echo "======================"
    
    echo ""
    echo "📋 Checking SSH log files..."
    for logfile in /var/log/auth.log /var/log/secure /var/log/messages; do
        if [ -f "$logfile" ]; then
            echo "✅ $logfile exists"
            echo "   Size: $(ls -lh $logfile | awk '{print $5}')"
            echo "   Last modified: $(ls -l $logfile | awk '{print $6, $7, $8}')"
            echo "   Recent SSH failures:"
            grep -i "failed password\|authentication failure" "$logfile" | tail -3 | sed 's/^/   /'
        else
            echo "❌ $logfile not found"
        fi
        echo ""
    done
    
    echo "🔧 Checking fail2ban configuration..."
    echo "Jail configuration:"
    fail2ban-client get sshd logpath
    fail2ban-client get sshd maxretry
    fail2ban-client get sshd findtime
    
    echo ""
    echo "📊 Current fail2ban status:"
    fail2ban-client status sshd
    
    echo ""
    echo "🔍 Recent fail2ban log:"
    if [ -f "/var/log/fail2ban.log" ]; then
        tail -20 /var/log/fail2ban.log
    else
        echo "❌ Fail2ban log not found"
    fi
    
    echo ""
    echo "🔄 Restarting fail2ban to reload configuration..."
    systemctl restart fail2ban
    sleep 2
    
    echo ""
    echo "📊 Status after restart:"
    fail2ban-client status sshd
    
    exit 0
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "FAIL2BAN COMPLETE SETUP SCRIPT"
    echo "=============================="
    echo ""
    echo "Usage:"
    echo "  sudo bash fail2ban.sh                    # Install/Setup fail2ban"
    echo "  sudo bash fail2ban.sh --test-telegram    # Test Telegram notifications"
    echo "  sudo bash fail2ban.sh --fix-icmp         # Fix ICMP blocking"
    echo "  sudo bash fail2ban.sh --fix-config       # Fix configuration issues"
    echo "  sudo bash fail2ban.sh --status           # Show current status"
    echo "  sudo bash fail2ban.sh --restart          # Restart fail2ban properly"
    echo "  sudo bash fail2ban.sh --debug            # Debug fail2ban issues"
    echo "  sudo bash fail2ban.sh --help             # Show this help"
    echo ""
    echo "Features:"
    echo "  • SSH protection with permanent bans"
    echo "  • ICMP (ping) blocking for banned IPs"
    echo "  • Telegram notifications for security alerts"
    echo "  • Automatic maintenance every 5 minutes"
    echo "  • All-in-one script (no additional files needed)"
    exit 0
fi

# Memastikan script dijalankan dengan hak akses root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function untuk mengecek versi OS
check_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "ubuntu" ]; then
            if [ "$(echo $VERSION_ID | cut -d. -f1)" -lt 20 ]; then
                echo "This script requires Ubuntu 20.04 or later"
                exit 1
            fi
        elif [ "$ID" = "debian" ]; then
            if [ "$(echo $VERSION_ID | cut -d. -f1)" -lt 10 ]; then
                echo "This script requires Debian 10 or later"
                exit 1
            fi
        else
            echo "This script only supports Ubuntu and Debian systems"
            exit 1
        fi
    else
        echo "Could not determine OS version"
        exit 1
    fi
}

# Load variables from .vars file
if [ -f ".vars" ]; then
    source .vars
    echo "Loaded Telegram bot configuration from .vars file"
else
    echo "Warning: .vars file not found. Telegram notifications will be disabled."
    bot_token=""
    telegram_id=""
fi

# Check OS version
check_os_version

# Update dan install fail2ban dengan error handling
echo "Updating package lists and installing fail2ban..."
if ! apt-get update; then
    echo "Failed to update package lists"
    exit 1
fi

if ! apt-get upgrade -y; then
    echo "Failed to upgrade packages"
    exit 1
fi

if ! apt-get install -y fail2ban; then
    echo "Failed to install fail2ban"
    exit 1
fi

# Backup konfigurasi default fail2ban
echo "Backing up default fail2ban configuration..."
if [ -f /etc/fail2ban/jail.conf ]; then
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak
else
    echo "Warning: Default jail.conf not found"
fi

# Detect correct log file
echo "Detecting SSH log file..."
if [ -f "/var/log/auth.log" ]; then
    ssh_logpath="/var/log/auth.log"
    echo "✅ Using /var/log/auth.log"
elif [ -f "/var/log/secure" ]; then
    ssh_logpath="/var/log/secure"
    echo "✅ Using /var/log/secure"
elif [ -f "/var/log/messages" ]; then
    ssh_logpath="/var/log/messages"
    echo "✅ Using /var/log/messages"
else
    ssh_logpath="/var/log/auth.log"
    echo "⚠️ Defaulting to /var/log/auth.log"
fi

# Set telegram action based on credentials availability
if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
    telegram_action=", telegram-notify[name=SSH]"
    icmp_telegram_action=", telegram-notify[name=ICMP]"
else
    telegram_action=""
    icmp_telegram_action=""
fi

# Membuat file jail.local untuk konfigurasi kustom fail2ban
echo "Creating jail.local for custom configuration..."
cat <<EOL > /etc/fail2ban/jail.local
[DEFAULT]
# Ban hosts for 24 hours
bantime = 86400
# Time window to count failures
findtime = 600
# Number of failures before a host is banned
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = ${ssh_logpath}
maxretry = 2
findtime = 600
bantime = -1  # permanent ban
action = iptables-multiport[name=SSH, port="ssh,22"], iptables-icmp-block[name=ICMP, protocol=all]${telegram_action}

# Custom jail untuk memblokir ICMP (ping) dari IP yang di-ban
[icmp-block]
enabled = true
filter = icmp-block
logpath = /var/log/fail2ban.log
maxretry = 1
findtime = 60
bantime = -1  # permanent ban
port = all
protocol = all
action = iptables-icmp-block[name=ICMP, protocol=all]${icmp_telegram_action}
EOL

# Membuat filter untuk ICMP blocking
echo "Creating ICMP block filter..."
cat <<EOL > /etc/fail2ban/filter.d/icmp-block.conf
[Definition]
failregex = ^.*SRC=<HOST>.*PROTO=ICMP.*$
ignoreregex =
EOL

# Membuat action untuk memblokir ICMP
echo "Creating ICMP block action..."
cat <<EOL > /etc/fail2ban/action.d/iptables-icmp-block.conf
[Definition]
actionstart = iptables -N fail2ban-icmp-block
actionstop = iptables -F fail2ban-icmp-block && iptables -X fail2ban-icmp-block
actioncheck = iptables -n -L fail2ban-icmp-block | grep -q '^REJECT'
actionban = iptables -I fail2ban-icmp-block 1 -s <ip> -j REJECT
actionunban = iptables -D fail2ban-icmp-block -s <ip> -j REJECT
EOL

# Membuat action untuk Telegram notification
if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
    echo "Creating Telegram notification action..."
    cat > /etc/fail2ban/action.d/telegram-notify.conf << 'EOF'
[Definition]
actionstart = 
actionstop = 
actioncheck = 
actionban = curl -s -X POST "https://api.telegram.org/botBOT_TOKEN_HERE/sendMessage" \
            -d "chat_id=CHAT_ID_HERE" \
            -d "text=🚨 FAIL2BAN ALERT 🚨%0A%0A🔴 IP Address: <ip>%0A🔴 Jail: <name>%0A🔴 Action: BANNED%0A🔴 Time: $(date '+%Y-%m-%d %H:%M:%S')%0A🔴 Server: $(hostname)%0A%0A⚠️ This IP has been permanently banned for suspicious activity.%0A%0A🛡️ ICMP blocking also activated for this IP."
actionunban = curl -s -X POST "https://api.telegram.org/botBOT_TOKEN_HERE/sendMessage" \
              -d "chat_id=CHAT_ID_HERE" \
              -d "text=✅ FAIL2BAN UNBAN ✅%0A%0A🟢 IP Address: <ip>%0A🟢 Jail: <name>%0A🟢 Action: UNBANNED%0A🟢 Time: $(date '+%Y-%m-%d %H:%M:%S')%0A🟢 Server: $(hostname)"
EOF

    # Replace placeholders with actual values
    sed -i "s/BOT_TOKEN_HERE/$bot_token/g" /etc/fail2ban/action.d/telegram-notify.conf
    sed -i "s/CHAT_ID_HERE/$telegram_id/g" /etc/fail2ban/action.d/telegram-notify.conf
else
    echo "Warning: Telegram credentials not found, creating dummy action file..."
    cat > /etc/fail2ban/action.d/telegram-notify.conf << 'EOF'
[Definition]
actionstart = 
actionstop = 
actioncheck = 
actionban = echo "Telegram notification disabled - no credentials configured"
actionunban = echo "Telegram notification disabled - no credentials configured"
EOF
fi

# Menambahkan rule iptables untuk ICMP blocking
echo "Adding iptables rules for ICMP blocking..."
# Create the chain if it doesn't exist
iptables -L fail2ban-icmp-block >/dev/null 2>&1 || iptables -N fail2ban-icmp-block
# Add the rule to INPUT chain if it doesn't exist
iptables -C INPUT -p icmp -j fail2ban-icmp-block 2>/dev/null || iptables -I INPUT -p icmp -j fail2ban-icmp-block

# Membuat script untuk memastikan ICMP blocking tetap aktif
echo "Creating ICMP block maintenance script..."
cat <<EOL > /usr/local/bin/fail2ban-icmp-maintain.sh
#!/bin/bash
# Script untuk memastikan ICMP blocking tetap aktif

# Memastikan chain fail2ban-icmp-block ada
iptables -L fail2ban-icmp-block >/dev/null 2>&1 || iptables -N fail2ban-icmp-block

# Memastikan rule ICMP ada di INPUT chain
iptables -C INPUT -p icmp -j fail2ban-icmp-block >/dev/null 2>&1 || iptables -I INPUT -p icmp -j fail2ban-icmp-block

# Memastikan semua IP yang di-ban SSH juga di-blokir ICMP
echo "Syncing banned IPs to ICMP block chain..."
banned_status=\$(fail2ban-client status sshd | grep "Banned IP list:")
if [ -n "\$banned_status" ]; then
    existing_banned_ips=\$(echo "\$banned_status" | sed 's/.*Banned IP list:[[:space:]]*//' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
    
    if [ -n "\$existing_banned_ips" ]; then
        for ip in \$existing_banned_ips; do
            if [ -n "\$ip" ]; then
                iptables -C fail2ban-icmp-block -s \$ip -j REJECT >/dev/null 2>&1 || iptables -I fail2ban-icmp-block 1 -s \$ip -j REJECT
                echo "Added \$ip to ICMP block chain"
            fi
        done
    fi
fi
EOL

chmod +x /usr/local/bin/fail2ban-icmp-maintain.sh

# Menambahkan cron job untuk maintenance
echo "Adding cron job for ICMP block maintenance..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/fail2ban-icmp-maintain.sh") | crontab -

# Jalankan maintenance script untuk menambahkan IP yang sudah di-ban
echo "Running initial ICMP block maintenance..."
/usr/local/bin/fail2ban-icmp-maintain.sh

# Tambahan: Sync IP yang sudah di-ban ke ICMP chain secara langsung
echo "Syncing existing banned IPs to ICMP block chain..."
banned_status=$(fail2ban-client status sshd | grep "Banned IP list:")
if [ -n "$banned_status" ]; then
    # Extract IPs using a more robust method
    existing_banned_ips=$(echo "$banned_status" | sed 's/.*Banned IP list:[[:space:]]*//' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
    
    if [ -n "$existing_banned_ips" ]; then
        echo "Found existing banned IPs: $existing_banned_ips"
        ip_count=0
        for ip in $existing_banned_ips; do
            echo "Adding $ip to ICMP block chain..."
            iptables -C fail2ban-icmp-block -s $ip -j REJECT >/dev/null 2>&1 || iptables -I fail2ban-icmp-block 1 -s $ip -j REJECT
            ((ip_count++))
        done
        echo "✅ All $ip_count existing banned IPs synced to ICMP block chain"
    else
        echo "ℹ️  No valid IPs found in banned list"
    fi
else
    echo "ℹ️  No banned IPs found"
fi

# Test Telegram bot dan kirim notifikasi IP yang sudah di-ban
if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
    echo "Testing Telegram bot notification..."
    test_message="🧪 FAIL2BAN TEST 🧪%0A%0A✅ Fail2ban has been successfully configured with Telegram notifications%0A✅ Server: $(hostname)%0A✅ Time: $(date '+%Y-%m-%d %H:%M:%S')%0A%0A🔔 You will receive notifications for banned IPs"
    
    if curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=${telegram_id}" \
        -d "text=${test_message}" > /dev/null; then
        echo "✓ Telegram bot test successful"
        
        # Kirim notifikasi untuk IP yang sudah di-ban
        banned_status=$(fail2ban-client status sshd | grep "Banned IP list:")
        if [ -n "$banned_status" ]; then
            banned_ips=$(echo "$banned_status" | sed 's/.*Banned IP list:[[:space:]]*//' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
            if [ -n "$banned_ips" ]; then
                echo "Sending notification for existing banned IPs..."
                ip_count=0
                for ip in $banned_ips; do
                    ((ip_count++))
                done
                
                existing_ban_message="🚨 EXISTING BANNED IPS 🚨%0A%0A🔴 Server: $(hostname)%0A🔴 Total Banned IPs: $ip_count%0A🔴 Time: $(date '+%Y-%m-%d %H:%M:%S')%0A%0A📋 Banned IP List:%0A$(echo "$banned_ips" | tr ' ' '\n' | sed 's/^/• /')%0A%0A⚠️ These IPs were already banned before setup"
                
                curl -s -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
                    -d "chat_id=${telegram_id}" \
                    -d "text=${existing_ban_message}" > /dev/null
                
                echo "✓ Sent notification for $ip_count existing banned IPs"
            fi
        fi
    else
        echo "✗ Telegram bot test failed. Please check your bot token and chat ID"
    fi
else
    echo "⚠️ Telegram notifications disabled - bot token or chat ID not configured"
fi

# Restart dan aktifkan fail2ban
echo "Restarting fail2ban service..."
if ! systemctl restart fail2ban; then
    echo "Failed to restart fail2ban service"
    echo "Checking fail2ban configuration for errors..."
    
    # Check fail2ban configuration
    if fail2ban-client reload 2>&1 | grep -q "ERROR"; then
        echo "❌ Configuration error detected. Attempting to fix..."
        
        # Backup problematic config
        cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.error.$(date +%Y%m%d_%H%M%S)
        
        # Create minimal working config
        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 2
findtime = 600
bantime = -1
EOF
        
        echo "✅ Created minimal configuration"
        
        # Try to restart again
        if systemctl restart fail2ban; then
            echo "✅ Fail2ban started with minimal config"
        else
            echo "❌ Still failed to start fail2ban"
            systemctl status fail2ban
            exit 1
        fi
    else
        echo "❌ Unknown error starting fail2ban"
        systemctl status fail2ban
        exit 1
    fi
fi

# Verifikasi action Telegram terdaftar
echo "Verifying Telegram action configuration..."
if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
    # Wait for fail2ban to be fully started
    sleep 3
    
    # Check if fail2ban is running
    if systemctl is-active --quiet fail2ban; then
        if fail2ban-client get sshd actions 2>/dev/null | grep -q "telegram-notify"; then
            echo "✓ Telegram action is properly configured"
        else
            echo "⚠️ Telegram action not found in jail configuration"
            echo "Checking jail configuration..."
            fail2ban-client get sshd actions 2>/dev/null || echo "Service not ready yet"
        fi
    else
        echo "⚠️ Fail2ban service not running yet, waiting..."
        sleep 5
        if systemctl is-active --quiet fail2ban; then
            if fail2ban-client get sshd actions 2>/dev/null | grep -q "telegram-notify"; then
                echo "✓ Telegram action is properly configured"
            else
                echo "⚠️ Telegram action not found in jail configuration"
            fi
        else
            echo "❌ Fail2ban service failed to start"
        fi
    fi
fi

if ! systemctl enable fail2ban; then
    echo "Failed to enable fail2ban service"
    exit 1
fi

# Periksa status fail2ban
echo "Fail2ban has been installed and configured for permanent ban with ICMP blocking and Telegram notifications."

# Wait for service to be ready
sleep 2
if systemctl is-active --quiet fail2ban; then
    fail2ban-client status sshd 2>/dev/null || echo "Service starting, please wait..."
else
    echo "⚠️ Fail2ban service not running, attempting to start..."
    systemctl start fail2ban
    sleep 3
    if systemctl is-active --quiet fail2ban; then
        fail2ban-client status sshd 2>/dev/null || echo "Service started but not ready yet"
    else
        echo "❌ Failed to start fail2ban service"
    fi
fi

# Tampilkan informasi ICMP blocking
echo ""
echo "=== ICMP Blocking Status ==="
echo "Checking ICMP block chain..."
if iptables -L fail2ban-icmp-block >/dev/null 2>&1; then
    echo "✓ ICMP block chain is active"
    banned_in_chain=$(iptables -L fail2ban-icmp-block -n | grep REJECT | awk '{print $4}' | sort -u)
    if [ -n "$banned_in_chain" ]; then
        echo "Banned IPs in ICMP block chain:"
        echo "$banned_in_chain"
    else
        echo "⚠️  No IPs in ICMP block chain yet"
        echo "   Re-syncing banned IPs to ICMP chain..."
        
        # Re-sync IPs to ICMP chain
        banned_status=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP list:")
        if [ -n "$banned_status" ]; then
            banned_ips=$(echo "$banned_status" | sed 's/.*Banned IP list:[[:space:]]*//' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
            if [ -n "$banned_ips" ]; then
                for ip in $banned_ips; do
                    iptables -C fail2ban-icmp-block -s $ip -j REJECT >/dev/null 2>&1 || iptables -I fail2ban-icmp-block 1 -s $ip -j REJECT
                done
                echo "✅ Re-synced $(echo "$banned_ips" | wc -w) IPs to ICMP block chain"
            fi
        fi
    fi
else
    echo "✗ ICMP block chain not found"
fi

# Tampilkan status Telegram notifications
echo ""
echo "=== Telegram Notification Status ==="
if [ -n "$bot_token" ] && [ -n "$telegram_id" ]; then
    echo "✓ Telegram notifications enabled"
    echo "Bot Token: ${bot_token:0:20}..."
    echo "Chat ID: $telegram_id"
else
    echo "✗ Telegram notifications disabled"
    echo "Please configure bot_token and telegram_id in .vars file"
fi

# Verify installation
if systemctl is-active --quiet fail2ban; then
    echo ""
    echo "✓ Fail2ban is running successfully"
    echo ""
    echo "🎉 Setup Complete! Your fail2ban is now configured with:"
    echo "   • SSH protection with permanent bans"
    echo "   • ICMP (ping) blocking for banned IPs"
    echo "   • Telegram notifications for security alerts"
    echo "   • Automatic maintenance every 5 minutes"
    echo "   • Automatic sync of existing banned IPs to ICMP chain"
    echo ""
    echo "📋 What this script does:"
    echo "   ✅ Installs and configures fail2ban"
    echo "   ✅ Sets up ICMP blocking for banned IPs"
    echo "   ✅ Configures Telegram notifications"
    echo "   ✅ Syncs existing banned IPs to ICMP chain"
    echo "   ✅ Creates maintenance script for auto-sync"
    echo "   ✅ Tests Telegram bot functionality"
    echo ""
    echo "🔧 No additional scripts needed - everything is integrated!"
    echo ""
    echo "🧪 To test Telegram notifications, run:"
    echo "   sudo bash fail2ban.sh --test-telegram"
    echo ""
    echo "🔧 To fix ICMP blocking immediately, run:"
    echo "   sudo bash fail2ban.sh --fix-icmp"
    echo ""
    echo "📋 Available commands:"
    echo "   sudo bash fail2ban.sh                    # Install/Setup fail2ban"
    echo "   sudo bash fail2ban.sh --test-telegram    # Test Telegram notifications"
    echo "   sudo bash fail2ban.sh --fix-icmp         # Fix ICMP blocking"
    echo "   sudo bash fail2ban.sh --status           # Show current status"
else
    echo "Warning: Fail2ban service is not running"
    exit 1
fi
