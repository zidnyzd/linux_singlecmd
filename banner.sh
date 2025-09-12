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
  Bot Auto Order VPN/SSH<br>
  https://t.me/zidvpnstorebot<br>
  Buat Akun Kapan Saja, Online 24/7<br>
  <br>
  Tembak Paket XL di Web <br>https://panel.zidstore.net<br>
  Top Up Instant 24/7<br>
  <br>
  <b>OUR SERVICES:</b><br>
  VPS Unlimited Bandwidth: https://t.me/zidstorevpn/16<br>
  VPS Digital Ocean: https://t.me/zidstorevpn/17<br>
  Tembak Paket XL VIDIO, IFLIX, XCV, Akrab, Akrab Bekasan, Masa Aktif 1 Tahun, dll : https://t.me/zidstorevpn/19<br>
  <br><b>CONTACT US:</b><br>
  Telegram: https://t.me/storezid2<br>
  Telegram Channel: https://t.me/zidstorevpn<br>
  Whatsapp: https://wa.me/+6285184673439<br><br>
  </font>
</div>
EOF

systemctl restart dropbear

echo "Banner SSH telah diperbarui!"