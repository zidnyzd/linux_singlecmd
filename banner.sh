#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt

    ============================================
         Z I D S T O R E . N E T
         Premium Tunneling Service
    ============================================

      Web Order : https://zidstore.net
      Telegram  : @storezid2
      WhatsApp  : +62 851-8467-3439

    --------------------------------------------
      Produk : SSH WS / VMess / VLESS / Trojan
      Pulsa  : XL / AXIS / TRI / INDOSAT / By.U

      Topup 24/7 | Login Google | Tanpa Biaya Admin
    --------------------------------------------

      !! NO TORRENT / NO MULTILOGIN / NO RESHARE

    ============================================

EOF

systemctl restart dropbear

echo "Banner SSH telah diperbarui!"