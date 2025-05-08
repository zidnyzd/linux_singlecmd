#!/bin/bash

# Hapus file jika ada
rm -f /etc/fightertunnel.txt

# Buat ulang dengan konten baru
cat << 'EOF' > /etc/fightertunnel.txt
<pre>
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  ⚡ VPN & SSH SERVICE by ZidStore ⚡                        ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  📋 RULES:                                                 ┃
┃  ❌ No DDOS/Torrent/Multi Login/Sharing                    ┃
┃  🔄 Auto Reboot: 02:00 AM GMT+7                           ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  📱 CONTACT:                                               ┃
┃  📲 WA: https://wa.me/+6285184673439                      ┃
┃  📨 TG: https://t.me/storezid2                            ┃
┃  📢 CH: https://t.me/zidstorevpn                          ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  🤖 BOT Auto Order Akun VPN/SSH:                          ┃
┃  🔗 https://t.me/zidvpnstorebot                           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
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
