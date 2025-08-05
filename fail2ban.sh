#!/bin/bash

# Fail2Ban Installation and Configuration Script
# Script untuk install dan konfigurasi fail2ban dengan ban permanen setelah 1x salah

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Script ini harus dijalankan sebagai root!"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        print_status "Detected Debian/Ubuntu system"
    elif [[ -f /etc/redhat-release ]]; then
        OS="redhat"
        print_status "Detected RedHat/CentOS system"
    else
        print_error "Unsupported operating system"
        exit 1
    fi
}

# Function to install fail2ban
install_fail2ban() {
    print_status "Installing fail2ban..."
    
    if [[ $OS == "debian" ]]; then
        apt update
        apt install -y fail2ban
    elif [[ $OS == "redhat" ]]; then
        yum install -y epel-release
        yum install -y fail2ban
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "Fail2ban installed successfully"
    else
        print_error "Failed to install fail2ban"
        exit 1
    fi
}

# Function to create fail2ban configuration
create_fail2ban_config() {
    print_status "Creating fail2ban configuration..."
    
    # Create jail.local file
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban time in seconds (permanent = -1)
bantime = -1
# Find time in seconds
findtime = 600
# Max retry attempts (1 = ban after first failure)
maxretry = 1
# Ban action
banaction = iptables-allports
# Log level
loglevel = INFO
# Log target
logtarget = /var/log/fail2ban.log

# SSH protection
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 1
bantime = -1

# HTTP/HTTPS protection
[http-get-dos]
enabled = true
port = http,https
filter = http-get-dos
logpath = /var/log/apache2/access.log
maxretry = 1
bantime = -1

# Nginx protection
[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 1
bantime = -1

# FTP protection
[vsftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
filter = vsftpd
logpath = /var/log/vsftpd.log
maxretry = 1
bantime = -1

# Mail protection
[postfix]
enabled = true
port = smtp,465,submission
filter = postfix
logpath = /var/log/mail.log
maxretry = 1
bantime = -1

# WordPress protection
[wordpress]
enabled = true
port = http,https
filter = wordpress
logpath = /var/log/apache2/access.log
maxretry = 1
bantime = -1

# Custom rule for any suspicious activity
[suspicious]
enabled = true
port = 0:65535
filter = suspicious
logpath = /var/log/fail2ban.log
maxretry = 1
bantime = -1
EOF

    print_success "Fail2ban configuration created"
}

# Function to create custom filters
create_custom_filters() {
    print_status "Creating custom filters..."
    
    # Create filter directory if it doesn't exist
    mkdir -p /etc/fail2ban/filter.d
    
    # HTTP GET DoS filter
    cat > /etc/fail2ban/filter.d/http-get-dos.conf << 'EOF'
[Definition]
failregex = ^<HOST> - .* "(GET|POST|HEAD|PUT|DELETE|CONNECT|OPTIONS|TRACE|PATCH) .* HTTP/.*" (404|403|500|502|503|504) .*$
ignoreregex =
EOF

    # Suspicious activity filter
    cat > /etc/fail2ban/filter.d/suspicious.conf << 'EOF'
[Definition]
failregex = ^<HOST> - .* "(GET|POST) .* (wp-admin|admin|login|phpmyadmin|mysql|sql|union|select|insert|update|delete|drop|create|exec|eval|system|shell|cmd|bash|sh) .*$
ignoreregex =
EOF

    print_success "Custom filters created"
}

# Function to configure fail2ban actions
configure_actions() {
    print_status "Configuring fail2ban actions..."
    
    # Create action directory if it doesn't exist
    mkdir -p /etc/fail2ban/action.d
    
    # Create permanent ban action
    cat > /etc/fail2ban/action.d/iptables-permanent.conf << 'EOF'
[Definition]
actionstart = iptables -N fail2ban-<name>
              iptables -A fail2ban-<name> -j RETURN
              iptables -I INPUT -p tcp -m multiport --dports <port> -j fail2ban-<name>

actionstop = iptables -D INPUT -p tcp -m multiport --dports <port> -j fail2ban-<name>
             iptables -F fail2ban-<name>
             iptables -X fail2ban-<name>

actioncheck = iptables -n -L INPUT | grep -q 'fail2ban-<name>[ \t]'

actionban = iptables -I fail2ban-<name> 1 -s <ip> -j DROP

actionunban = iptables -D fail2ban-<name> -s <ip> -j DROP

[Init]
name = default
port = ssh
protocol = tcp
EOF

    print_success "Fail2ban actions configured"
}

# Function to create fail2ban service configuration
configure_service() {
    print_status "Configuring fail2ban service..."
    
    # Enable fail2ban service
    systemctl enable fail2ban
    
    # Start fail2ban service
    systemctl start fail2ban
    
    # Check if service is running
    if systemctl is-active --quiet fail2ban; then
        print_success "Fail2ban service is running"
    else
        print_error "Failed to start fail2ban service"
        exit 1
    fi
}

# Function to create monitoring script
create_monitoring_script() {
    print_status "Creating monitoring script..."
    
    cat > /usr/local/bin/fail2ban-monitor.sh << 'EOF'
#!/bin/bash

# Fail2Ban Monitoring Script
echo "=== Fail2Ban Status ==="
fail2ban-client status

echo -e "\n=== Banned IPs ==="
fail2ban-client banned

echo -e "\n=== Recent Fail2Ban Logs ==="
tail -20 /var/log/fail2ban.log

echo -e "\n=== Active Jails ==="
fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr ',' '\n' | sed 's/^[ \t]*//'
EOF

    chmod +x /usr/local/bin/fail2ban-monitor.sh
    print_success "Monitoring script created at /usr/local/bin/fail2ban-monitor.sh"
}

# Function to create unban script
create_unban_script() {
    print_status "Creating unban script..."
    
    cat > /usr/local/bin/fail2ban-unban.sh << 'EOF'
#!/bin/bash

# Fail2Ban Unban Script
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <ip_address> [jail_name]"
    echo "Example: $0 192.168.1.100 sshd"
    exit 1
fi

IP=$1
JAIL=${2:-sshd}

echo "Unbanning IP $IP from jail $JAIL..."
fail2ban-client set $JAIL unbanip $IP

if [[ $? -eq 0 ]]; then
    echo "Successfully unbanned $IP from $JAIL"
else
    echo "Failed to unban $IP from $JAIL"
fi
EOF

    chmod +x /usr/local/bin/fail2ban-unban.sh
    print_success "Unban script created at /usr/local/bin/fail2ban-unban.sh"
}

# Function to create firewall rules
setup_firewall() {
    print_status "Setting up firewall rules..."
    
    # Allow SSH (important to not lock yourself out)
    if command -v ufw &> /dev/null; then
        ufw allow ssh
        ufw --force enable
        print_success "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        print_success "Firewalld configured"
    else
        print_warning "No firewall manager detected, using iptables"
        iptables -A INPUT -p tcp --dport 22 -j ACCEPT
        iptables -A INPUT -j DROP
    fi
}

# Function to create backup script
create_backup_script() {
    print_status "Creating backup script..."
    
    cat > /usr/local/bin/fail2ban-backup.sh << 'EOF'
#!/bin/bash

# Fail2Ban Backup Script
BACKUP_DIR="/var/backups/fail2ban"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup configuration files
tar -czf $BACKUP_DIR/fail2ban_config_$DATE.tar.gz /etc/fail2ban/

# Backup banned IPs
fail2ban-client banned > $BACKUP_DIR/banned_ips_$DATE.txt

echo "Backup created: $BACKUP_DIR/fail2ban_config_$DATE.tar.gz"
echo "Banned IPs saved: $BACKUP_DIR/banned_ips_$DATE.txt"
EOF

    chmod +x /usr/local/bin/fail2ban-backup.sh
    print_success "Backup script created at /usr/local/bin/fail2ban-backup.sh"
}

# Function to display usage information
display_usage() {
    echo -e "${GREEN}=== Fail2Ban Installation Complete ===${NC}"
    echo ""
    echo "Fail2Ban telah berhasil diinstall dan dikonfigurasi dengan pengaturan:"
    echo "• Ban permanen setelah 1x percobaan gagal"
    echo "• Proteksi untuk SSH, HTTP, FTP, Mail, dan WordPress"
    echo "• Filter custom untuk aktivitas mencurigakan"
    echo ""
    echo "${YELLOW}Perintah yang tersedia:${NC}"
    echo "• fail2ban-client status                    - Cek status fail2ban"
    echo "• fail2ban-client banned                    - Lihat IP yang dibanned"
    echo "• /usr/local/bin/fail2ban-monitor.sh       - Monitoring lengkap"
    echo "• /usr/local/bin/fail2ban-unban.sh <IP>    - Unban IP"
    echo "• /usr/local/bin/fail2ban-backup.sh        - Backup konfigurasi"
    echo ""
    echo "${YELLOW}File konfigurasi:${NC}"
    echo "• /etc/fail2ban/jail.local                 - Konfigurasi utama"
    echo "• /var/log/fail2ban.log                    - Log fail2ban"
    echo ""
    echo "${RED}PERINGATAN:${NC} IP yang dibanned akan diblokir PERMANEN!"
    echo "Gunakan script unban jika perlu membuka akses kembali."
}

# Main execution
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Fail2Ban Installation Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    check_root
    detect_os
    install_fail2ban
    create_fail2ban_config
    create_custom_filters
    configure_actions
    configure_service
    create_monitoring_script
    create_unban_script
    setup_firewall
    create_backup_script
    display_usage
    
    echo ""
    print_success "Installation completed successfully!"
}

# Run main function
main "$@"
