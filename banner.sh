#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<h2 style="text-align:center";><font
color='#ff0000'>Z</font><font
color='#ff0000'>I</font><font
color='#ff0000'>D</font><font
color='#FFFFFF'>V</font><font
color='#FFFFFF'>P</font><font
color='#FFFFFF'>N</font><font
color='#FFCC00'></font></b><br><br>
<b><h2 style="text-align:center";><font
<font color="white">Server Rules :</font>
</b><br><br>
<b><h3 style="text-align:center";><font
<font color="white">No DDOS</font><br>
<font color="white">No Torrent</font><br>
<font color="white">No MultiLogin</font><br>
<font color="white">No Reshare Account</font><br>
<font color="white">Auto Reboot 02:00 AM GMT+7</font><br><br>
<font color="white">Melanggar? Auto Delete Account</font><br<br>
<br><br>
<font color="white">Whatsapp : https://wa.me/+6285184673439</font><br><br>
<font color="white">Telegram : https://t.me/storezid2</font><br><br>
<font color="white">Telegram Channel : https://t.me/zidstorevpn</font><br>
<br><br>
<font color="white">Bot Auto Order VPN/SSH</font><br>
<font color="white">https://t.me/zidvpnstorebot</font><br>
<font color="white">Buat Akun Kapan Saja, Online 24/7</font><br>
EOF

# Set permission agar bisa dibaca
chmod 644 /etc/fightertunnel.txt
