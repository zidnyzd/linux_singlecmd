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

echo "==> Restart fail2ban"
systemctl restart fail2ban

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
