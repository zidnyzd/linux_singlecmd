#!/bin/bash

# Unduh Nezha Agent terbaru
wget -O nezha-agent.zip https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip

# Buat direktori Nezha dan ekstrak file
mkdir -p /opt/nezha
unzip nezha-agent.zip -d /opt/nezha

# Beri izin eksekusi pada binary Nezha Agent
chmod +x /opt/nezha/nezha-agent

# Buat file konfigurasi config.yml di /opt/nezha
UUID=$(uuidgen)
cat <<EOF > /opt/nezha/config.yml
client_secret: dzRwN0jWBuubx2nr58orR14O7rNezprC
debug: false
disable_auto_update: false
disable_command_execute: false
disable_force_update: false
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: 149.129.232.101:8008
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $UUID
EOF

# Buat file service systemd untuk Nezha Agent
cat <<EOF > /etc/systemd/system/nezha-agent.service
[Unit]
Description=Nezha Agent
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/opt/nezha/nezha-agent -c /opt/nezha/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd dan mulai layanan Nezha Agent
sudo systemctl daemon-reload
sudo systemctl start nezha-agent
sudo systemctl enable nezha-agent

# Tampilkan status layanan
sudo systemctl status nezha-agent --no-pager
