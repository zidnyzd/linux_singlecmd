#!/bin/bash

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
logpath = /var/log/auth.log
maxretry = 2
findtime = 600
bantime = -1  # permanent ban
EOL

# Restart dan aktifkan fail2ban
echo "Restarting fail2ban service..."
if ! systemctl restart fail2ban; then
    echo "Failed to restart fail2ban service"
    exit 1
fi

if ! systemctl enable fail2ban; then
    echo "Failed to enable fail2ban service"
    exit 1
fi

# Periksa status fail2ban
echo "Fail2ban has been installed and configured for permanent ban."
fail2ban-client status sshd

# Verify installation
if systemctl is-active --quiet fail2ban; then
    echo "Fail2ban is running successfully"
else
    echo "Warning: Fail2ban service is not running"
    exit 1
fi
