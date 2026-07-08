#!/bin/bash

# Hapus file jika ada
rm -f /etc/zidstoretunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/zidstoretunnel.txt
<p align="center">
  <font color="#3399FF" size="5"><b>ZIDSTORE.NET</b></font><br>
  <font color="#ffffff">──────────────────────</font><br>
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
    XL Edukasi 15GB (8K-an!)<br>
    XL Conference 15GB (11K-an!)<br>
    XL Xtra Kuota / iFlix 14GB (12K-an!)<br>
    Telkomsel Ilmupedia 22GB ALL Area Harga FLAT (14K-an!)<br>
    <br>
    <b>🖥️ OTHER SERVICES:</b><br>
    VPS Unlimited Bandwidth: <font color="#FFFF00">t.me/zidstorevpn/16</font>
  </font><br>
  <font color="#ffffff">──────────────────────</font><br>
  <font color="#3399FF"><b>📞 CONTACT US & CHANNELS</b></font><br>
  <font color="#ffffff">
    • Telegram Chat : t.me/storezid2<br>
    • Telegram Channel : t.me/zidstorevpn<br>
    • Telegram Group : t.me/akrabnotif<br>
    • Telegram VPN bot : t.me/zidvpnstorebot<br>
    • Whatsapp Support : wa.me/+6287728141785<br>
    • Whatsapp Channel : whatsapp.com/channel/0029Vb7SCT4A2pLI7JkFKN2w
  </font><br>
  <font color="#ffffff">──────────────────────</font><br>
  <font color="#3399FF"><i>Thank you for choosing us!</i></font><br>
  <font color="#ffffff">&copy; 2022-2026 ZidStore</font><br>
</p>
EOF

# Matikan SEMUA proses dropbear dan bersihkan stale PID
systemctl stop dropbear 2>/dev/null
sleep 1
while pgrep dropbear &>/dev/null; do
    killall -9 dropbear 2>/dev/null
    sleep 1
done
# Hapus PID file biar init script tidak bingung
rm -f /var/run/dropbear.pid /run/dropbear.pid 2>/dev/null

# Start ulang via systemd
systemctl start dropbear 2>/dev/null || {
    echo "systemd failed, starting manually..."
    dropbear -p 143 -b /etc/zidstoretunnel.txt -W 65536 -p 109 -b /etc/zidstoretunnel.txt
}

echo "Banner SSH telah diperbarui!"
echo "Ukuran banner: $(stat -c%s /etc/zidstoretunnel.txt) bytes"