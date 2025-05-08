#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<pre>
<font color="#FF0000">┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓</font>
<font color="#FF0000">┃</font>  <font color="#00FF00">███████╗██╗██████╗    ███████╗████████╗ ██████╗ ██████╗ ███████╗</font>  <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#00FF00">╚══███╔╝██║██╔══██╗   ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔════╝</font>  <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#00FF00">  ███╔╝ ██║██║  ██║   ███████╗   ██║   ██║   ██║██████╔╝█████╗</font>  <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#00FF00"> ███╔╝  ██║██║  ██║   ╚════██║   ██║   ██║   ██║██╔══██╗██╔══╝</font>  <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#00FF00">███████╗██║██████╔╝   ███████║   ██║   ╚██████╔╝██║  ██║███████╗</font>  <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#00FF00">╚══════╝╚═╝╚═════╝    ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝</font>  <font color="#FF0000">┃</font>
<font color="#FF0000">┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">⚡ PREMIUM VPN & SSH SERVICE ⚡</font>                        <font color="#FF0000">┃</font>
<font color="#FF0000">┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫</font>
<font color="#FF0000">┃</font>  <font color="#FFCC00">📋 RULES:</font>                                             <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">❌ No DDOS/Torrent/Multi Login/Sharing</font>                <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">🔄 Auto Reboot: 02:00 AM GMT+7</font>                        <font color="#FF0000">┃</font>
<font color="#FF0000">┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫</font>
<font color="#FF0000">┃</font>  <font color="#00FFFF">📱 CONTACT:</font>                                           <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">📲 WA: https://wa.me/+6285184673439</font>                   <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">📨 TG: https://t.me/storezid2</font>                         <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">📢 CH: https://t.me/zidstorevpn</font>                       <font color="#FF0000">┃</font>
<font color="#FF0000">┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫</font>
<font color="#FF0000">┃</font>  <font color="#00FF00">🤖 BOT AUTO ORDER VPN/SSH:</font>                                               <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">🔗 https://t.me/zidvpnstorebot</font>                       <font color="#FF0000">┃</font>
<font color="#FF0000">┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫</font>
<font color="#FF0000">┃</font>  <font color="#FFCC00">🛍️ SERVICES:</font>                                          <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">🔹 VPS UB: http://t.me/zidstorevpn/16</font>                <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">🔹 VPS DO: http://t.me/zidstorevpn/17</font>                <font color="#FF0000">┃</font>
<font color="#FF0000">┃</font>  <font color="#FFFFFF">🔹 XL: http://t.me/zidstorevpn/19</font>                     <font color="#FF0000">┃</font>
<font color="#FF0000">┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛</font>
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
