#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<h2 style="text-align:center;">
  <font color="#ff0000">Z</font>
  <font color="#ff0000">I</font>
  <font color="#ff0000">D</font>
  <font color="#FFFFFF">S</font>
  <font color="#FFFFFF">T</font>
  <font color="#FFFFFF">O</font>
  <font color="#FFFFFF">R</font>
  <font color="#FFFFFF">E</font>
</h2>
<br>
<h3 style="text-align:center;"><font color="white">Server Rules :</font></h3>
<div style="text-align:center;">
  <font color="white">No Torrent<br>
  No MultiLogin<br>
  No Reshare Account<br>
  Melanggar? Delete Account<br><br>
  Web Auto Order UDP ZIVPN, SSH WS, VMess, VLESS, Trojan. dan juga Tembak Paket Data dalam satu Website<br>
  <br>
  https://panel.zidstore.net<br>
  <br> 
  Bisa order kapan saja 24/7. Top Up Instan tanpa biaya admin<br>
  <br>
  Paket Data yang Tersedia di Web :<br>
  XL Edukasi 15GB hanya 8K-an!, XL Conference 15GB hanya 11K-an!, XL Akrab Kuota s/d 163GB dan Bisa untuk AXIS, XL Circle Kuota s/d 84GB, XL Xtra Combo Plus 5GB / XCP 0KB + Bonus Kuota / Addon XCP 10-15GB, Masa Aktif All Operator, AXIS Data, By.U Data, TRI & INDOSAT Data & HiFi, Kuota s/d 500GB, dan banyak lagi<br>
  <br>
  <b>OUR SERVICES:</b><br>
  VPS Unlimited Bandwidth: https://t.me/zidstorevpn/16<br>
  <br><b>CONTACT US:</b><br>
  Telegram: https://t.me/storezid2<br>
  Telegram Channel: https://t.me/zidstorevpn<br>
  Whatsapp: https://wa.me/+6285184673439<br>
  Whatsapp Channel: https://whatsapp.com/channel/0029Vb7SCT4A2pLI7JkFKN2w<br><br>
  </font>
</div>
EOF

systemctl restart dropbear

echo "Banner SSH telah diperbarui!"