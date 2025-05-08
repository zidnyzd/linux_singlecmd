#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<pre>
<h2 style="text-align:center">
<font color='#ff0000'>Z</font><font color='#ff0000'>I</font><font color='#ff0000'>D</font><font color='#FFFFFF'>S</font><font color='#FFFFFF'>T</font><font color='#FFFFFF'>O</font><font color='#FFFFFF'>R</font><font color='#FFFFFF'>E</font>
</h2>

<font color="white">⚡ PREMIUM VPN & SSH SERVICE ⚡</font>

<font color="yellow">📋 SERVER RULES:</font>
<font color="white">❌ No DDOS/Torrent/Multi Login/Sharing</font>
<font color="white">🔄 Auto Reboot: 02:00 AM GMT+7</font>

<font color="cyan">📱 CONTACT US:</font>
<font color="white">📲 WA: https://wa.me/+6285184673439</font>
<font color="white">📨 TG: https://t.me/storezid2</font>
<font color="white">📢 CH: https://t.me/zidstorevpn</font>

<font color="green">🤖 BOT AUTO ORDER:</font>
<font color="white">🔗 https://t.me/zidvpnstorebot</font>
<font color="white">⏰ 24/7 Service Available</font>

<font color="yellow">🛍️ OUR SERVICES:</font>
<font color="white">🔹 VPS UB: http://t.me/zidstorevpn/16</font>
<font color="white">🔹 VPS DO: http://t.me/zidstorevpn/17</font>
<font color="white">🔹 XL: http://t.me/zidstorevpn/19</font>
</pre>
EOF

# Set permission agar bisa dibaca
chmod 644 /etc/fightertunnel.txt

# Restart services
systemctl restart sshd
systemctl restart dropbear
systemctl restart ws
systemctl restart badvpn

echo "Banner SSH telah diperbarui!"
