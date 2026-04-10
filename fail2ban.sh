#!/bin/bash
set -e

echo "==> Updating package list"
apt update

echo "==> Installing fail2ban"
apt install -y fail2ban

echo "==> Enabling fail2ban service"
systemctl enable fail2ban

echo "==> Starting fail2ban service"
systemctl start fail2ban

echo "==> Creating aggressive SSH jail configuration"
mkdir -p /etc/fail2ban/jail.d

cat > /etc/fail2ban/jail.d/sshd-aggressive.conf << 'EOF'
[sshd]
enabled = true
maxretry = 1
findtime = 600
bantime = 1h
backend = systemd
EOF

echo "==> Testing fail2ban configuration"
if ! fail2ban-client -t > /dev/null 2>&1; then
    echo "ERROR: Fail2ban configuration test failed"
    fail2ban-client -t
    exit 1
fi

echo "==> Restarting fail2ban service"
systemctl restart fail2ban

echo "==> Verifying fail2ban is running"
if ! systemctl is-active --quiet fail2ban; then
    echo "ERROR: Fail2ban service failed to start"
    systemctl status fail2ban
    exit 1
fi

echo "==> Checking fail2ban SSH jail status"
fail2ban-client status sshd || echo "Warning: Could not get jail status"

echo
echo "✅ Fail2ban setup completed successfully!"
echo
echo "Configuration details:"
echo "- SSH jail: 1 failed attempt = 1 hour ban"
echo "- Monitoring: systemd journal"
echo "- Existing configurations preserved"
echo
echo "Optional: Whitelist your IP address"
echo "fail2ban-client set sshd addignoreip YOUR_IP"
