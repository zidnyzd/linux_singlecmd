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

echo "Script Done, Server now should be more lighter"