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
  Melanggar? Auto Delete Account<br><br>
  <b>CONTACT US:</b><br>
  Telegram: https://t.me/storezid2<br>
  Telegram Channel: https://t.me/zidstorevpn<br>
  Whatsapp: https://wa.me/+6285184673439<br><br>
  Bot Auto Order VPN/SSH<br>
  https://t.me/zidvpnstorebot<br>
  Buat Akun Kapan Saja, Online 24/7
  <br>
  Tembak Paket XL di web https://panel.zidstore.net
  Top Up Instant 24/7
  <br>
  <b>OUR SERVICES:</b><br>
  VPS Unlimited Bandwidth: https://t.me/zidstorevpn/16<br>
  VPS Digital Ocean: https://t.me/zidstorevpn/17<br>
  Tembak Paket XL XUTS, XUTP, XCV, XCP, Akrab, Masa Aktif 1 Tahun, dll : https://t.me/zidstorevpn/19<br>
  </font>
</div>
EOF

# Set permission agar bisa dibaca
chmod 644 /etc/fightertunnel.txt

# Restart services
systemctl restart sshd
systemctl restart dropbear
systemctl restart ws
systemctl restart badvpn

echo "Banner SSH telah diperbarui!"