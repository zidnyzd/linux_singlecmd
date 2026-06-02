#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
+======================================================+
|                                                      |
|         Z I D S T O R E . N E T                      |
|         PREMIUM TUNNELING SERVICE                    |
|                                                      |
+======================================================+
|                                                      |
|  WEB ORDER :  https://zidstore.net                   |
|  TELEGRAM  :  @storezid2                             |
|  WHATSAPP  :  +62 851-8467-3439                     |
|                                                      |
+======================================================+
|                                                      |
|  PRODUK :  SSH WS | VMess | VLESS | Trojan          |
|  PULSA  :  XL | AXIS | TRI | INDOSAT | By.U         |
|                                                      |
|  TOPUP 24/7 | Login Google | Tanpa Biaya Admin Rp.0 |
|                                                      |
+======================================================+
|                                                      |
|   (!)  NO TORRENT | NO MULTILOGIN | NO RESHARE      |
|                                                      |
+======================================================+
EOF

systemctl restart dropbear

echo "Banner SSH telah diperbarui!"