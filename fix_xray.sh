#!/bin/bash

# Path ke file config.json
VMESS_CONFIG="/etc/xray/vmess/config.json"
VLESS_CONFIG="/etc/xray/vless/config.json"
TROJAN_CONFIG="/etc/xray/trojan/config.json"

# Fungsi untuk mengubah sniffing enabled dari true menjadi false
ubah_sniffing() {
    local config_file=$1
    if [[ -f "$config_file" ]]; then
        sed -i 's/"enabled": true/"enabled": false/g' "$config_file"
        echo "Sniffing telah diubah dari true menjadi false pada $config_file."
    else
        echo "File $config_file tidak ditemukan."
    fi
}

# Mengubah sniffing pada vmess/config.json
ubah_sniffing "$VMESS_CONFIG"

# Mengubah sniffing pada vless/config.json
ubah_sniffing "$VLESS_CONFIG"

# Mengubah sniffing pada trojan/config.json
ubah_sniffing "$TROJAN_CONFIG"