#!/bin/bash

# Skrip reset usage
RESET_SCRIPT_PATH="/usr/local/bin/reset_usage.sh"
cat << 'EOF' > $RESET_SCRIPT_PATH
#!/bin/bash

# Daftar direktori yang akan diproses
directories=(
    "/etc/xray/vmess/usage"
    "/etc/xray/vless/usage"
    "/etc/xray/trojan/usage"
    "/etc/xray/shadowsocks/usage"
)

# Loop melalui setiap direktori
for dir in "${directories[@]}"; do
    # Cek apakah direktori ada
    if [ -d "$dir" ]; then
        # Loop melalui setiap file dalam direktori
        for file in "$dir"/*; do
            # Cek apakah file ada dan merupakan file biasa
            if [ -f "$file" ]; then
                # Ganti nilai dalam file menjadi 0
                echo "0" > "$file"
                echo "Nilai dalam file $file telah diubah menjadi 0"
            fi
        done
    else
        echo "Direktori $dir tidak ditemukan"
    fi
done
EOF

# Berikan izin eksekusi pada skrip
chmod +x $RESET_SCRIPT_PATH

# Systemd service file
SERVICE_FILE="/etc/systemd/system/reset-usage.service"
cat << EOF > $SERVICE_FILE
[Unit]
Description=Reset Xray Usage Service
After=network.target

[Service]
Type=simple
ExecStart=$RESET_SCRIPT_PATH
Restart=no

[Install]
WantedBy=multi-user.target
EOF

# Systemd timer file
TIMER_FILE="/etc/systemd/system/reset-usage.timer"
cat << EOF > $TIMER_FILE
[Unit]
Description=Run Reset Xray Usage Service on the 1st of Every Month

[Timer]
OnCalendar=*-*-01 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd dan aktifkan timer
systemctl daemon-reload
systemctl enable reset-usage.timer
systemctl start reset-usage.timer

# Verifikasi timer
echo "Installasi selesai. Berikut status timer:"
systemctl list-timers | grep reset-usage