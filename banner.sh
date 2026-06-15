#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<p align="center">
  <font color="#3399FF" size="5"><b>ZIDSTORE.NET</b></font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#3399FF"><b>🛍️ LAYANAN YANG TERSEDIA DI WEBSITE</b></font><br>
  <font color="#FFFF00"><b>https://zidstore.net</b></font><br>
  <font color="#ffffff">
    • Order Pulsa & Paket Data ALL Operator<br>
    • Order SSH WS, VMess, VLESS, Trojan<br>
    • Daftar dan Login Instan dengan Google 1x Klik<br>
    • QRIS Tanpa Biaya Admin Rp.0 fee<br>
    • Pilih Paket - SCAN QRIS - Paket Masuk Otomatis<br>
    • Tanpa Perlu Topup Saldo Web<br>
    <br>
    <b>📦 PAKET DATA POPULER:</b><br>
    XL Edukasi 15GB (8K-an!), XL Conference 15GB (11K-an!), XL Xtra Kuota / iFlix 14GB (12K-an!),<br>
    XL Akrab & XL Circle, AXIS, By.U, Tri, Indosat, & banyak lagi!<br>
    <br>
    <b>🖥️ OTHER SERVICES:</b><br>
    VPS Unlimited Bandwidth: <font color="#FFFF00">t.me/zidstorevpn/16</font>
  </font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#3399FF"><b>📞 CONTACT US & CHANNELS</b></font><br>
  <font color="#ffffff">
    • Telegram Chat: t.me/storezid2<br>
    • Telegram Channel: t.me/zidstorevpn<br>
    • Whatsapp Support: wa.me/+6285184673439<br>
    • Whatsapp Channel: whatsapp.com/channel/0029Vb7SCT4A2pLI7JkFKN2w
  </font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#3399FF"><i>Thank you for choosing us!</i></font>
</p>
EOF

systemctl restart dropbear

echo "Banner SSH telah diperbarui!"