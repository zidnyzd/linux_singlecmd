#!/bin/bash

# Disable DNSTT Client
systemctl disable client
sleep 2
systemctl stop client
sleep 2
rm /etc/systemd/system/client.service
echo "Done Remove DNSTT Step 1"
sleep 2

# Disable Server Client
systemctl disable server
sleep 2
systemctl stop server
sleep 2
rm /etc/systemd/system/server.service
echo "Done Remove DNSTT Step 2"
echo "DNSTT CLEARED"
sleep 2

# Disable OpenVpn
systemctl disable openvpn
sleep 2
systemctl stop openvpn
sleep 2
rm /lib/systemd/system/openvpn.service
echo "Removed OpenVPN Server"
echo "Script Done, Server now should be more lighter"