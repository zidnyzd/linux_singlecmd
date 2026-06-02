#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<p align="center">
  <font color="#3399FF" size="5"><b>ZID STORE OFFICIAL</b></font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#ffffff"><b>🔴 PENTING: Server Rules</b></font><br>
  <font color="#FF6666">🚫 No Torrent | 🚫 No Multi-Login | 🚫 No Reshare Account</font><br>
  <font color="#FF3333"><b>Melanggar? Delete Account!</b></font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#3399FF"><b>🛍️ LAYANAN TERSEDIA DI WEBSITE</b></font><br>
  <font color="#FFFF00"><b>https://zidstore.net</b></font><br>
  <font color="#ffffff">
    • Web Auto Order SSH WS, VMess, VLESS, Trojan, Pulsa, & Paket Data.<br>
    • Login Instan Google | Topup Otomatis 24/7 Biaya Admin Rp.0.<br>
    <br>
    <b>📦 PAKET DATA POPULER:</b><br>
    XL Edukasi 15GB (8K-an!), XL Conference 15GB (10K-an!), XL Akrab s/d 163GB,<br>
    XL Circle s/d 84GB, AXIS, By.U, Tri, Indosat s/d 500GB, & banyak lagi!<br>
    <br>
    <b>🖥️ OTHER SERVICES:</b><br>
    VPS Unlimited Bandwidth: <font color="#FFFF00">t.me/zidstorevpn/16</font>
  </font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#3399FF"><b>📞 CONTACT US & CHANNELS</b></font><br>
  <font color="#ffffff">
    • Telegram Chat: @storezid2<br>
    • Telegram Channel: t.me/zidstorevpn<br>
    • Whatsapp Support: +62 851-8467-3439<br>
    • Whatsapp Channel: whatsapp.com/channel/0029Vb7SCT4A2pLI7JkFKN2w
  </font><br>
  <font color="#ffffff">──────────────────────────────────────────</font><br>
  <font color="#3399FF"><i>Thank you for using Zid Store VPN!</i></font>
</p>
EOF

systemctl restart dropbear

echo "Banner SSH telah diperbarui!"