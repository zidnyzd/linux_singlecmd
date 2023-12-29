#!/bin/bash

# Instal Fail2Ban
sudo apt-get update
sudo apt-get install fail2ban -y

# Konfigurasi Fail2Ban untuk SSH
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i '/^\[sshd\]$/,/^\[/ s/enabled = .*/enabled = true/' /etc/fail2ban/jail.local

# Atur waktu blokir dan jumlah percobaan
sudo sed -i '/^\[sshd\]$/,/^\[/ s/maxretry = .*/maxretry = 1/' /etc/fail2ban/jail.local
sudo sed -i '/^\[sshd\]$/,/^\[/ s/bantime = .*/bantime = 3600/' /etc/fail2ban/jail.local

# Restart Fail2Ban
sudo service fail2ban restart

echo "Fail2Ban berhasil diinstal dan dikonfigurasi untuk melindungi SSH."
