#!/bin/bash
set -e

echo "==> Install fail2ban"
apt update
apt install -y fail2ban

echo "==> Enable & start fail2ban"
systemctl enable fail2ban
systemctl start fail2ban

echo "==> Create aggressive sshd override (1x fail = ban)"
mkdir -p /etc/fail2ban/jail.d

cat > /etc/fail2ban/jail.d/sshd-aggressive.conf << 'EOF'
[sshd]
enabled = true
maxretry = 1
findtime = 600
bantime = 1h
backend = systemd
EOF

echo "==> Test fail2ban config"
fail2ban-client -t || { echo "Config test failed"; exit 1; }

echo "==> Restart fail2ban"
systemctl restart fail2ban

if systemctl is-active --quiet fail2ban; then
    echo "Fail2ban restarted successfully"
else
    echo "Fail2ban failed to restart. Checking status..."
    systemctl status fail2ban
    exit 1
fi

echo "==> Fail2ban status (sshd)"
fail2ban-client status sshd || true

echo
echo "DONE ✅"
echo "Info:"
echo "- 1x SSH login failed = immediate ban"
echo "- Existing fail2ban config untouched"
echo "- Safe for tunnel VPS"
echo
echo "TIP (optional): whitelist your IP"
echo "fail2ban-client set sshd addignoreip YOUR_IP"
