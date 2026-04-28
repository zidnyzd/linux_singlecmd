#!/bin/bash

# Disable DNSTT Client
systemctl disable dnstt-client
sleep 2
systemctl stop dnstt-client
sleep 2
rm /etc/systemd/system/dnstt-client.service
echo "Done Remove DNSTT Step 1"
sleep 2

# Disable Server Client
systemctl disable dnstt-server
sleep 2
systemctl stop dnstt-server
sleep 2
rm /etc/systemd/system/dnstt-server.service
echo "Done Remove DNSTT Step 2"
echo "DNSTT CLEARED"
sleep 2

# Disable Auto Reboot
rm /etc/cron.d/daily_reboot
sleep 2
systemctl restart cron
echo "Done Remove Auto Reboot"

# fix kernel
mv /var/lib/dpkg/info/linux-image-unsigned-7.0.2-070002-generic.postrm \
   /var/lib/dpkg/info/linux-image-unsigned-7.0.2-070002-generic.postrm.bak
sleep 2
dpkg --remove --force-remove-reinstreq linux-image-unsigned-7.0.2-070002-generic
apt --fix-broken install -y
echo "Done Remove Kernel 7.0.2-070002-generic"
sleep 2

echo "Script Done, Server now should be more lighter"