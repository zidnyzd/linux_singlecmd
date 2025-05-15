#!/bin/bash

#==== CONFIGURATION ====
NEXTDNS_IP1="45.90.28.57"
NEXTDNS_IP2="45.90.30.57"
NEXTDNS_NAME="91ac82.dns.nextdns.io"
BACKUP_STUBBY="/etc/stubby/stubby.yml.bak"
BACKUP_RESOLV="/etc/resolv.conf.bak"
RESOLV_CONF="/etc/resolv.conf"
#=======================

#==== ASCII HEADER ====
clear
echo "=========================================="
echo "     🌐 NextDNS DoT Setup for Debian 10    "
echo "=========================================="
echo ""
echo " Pilih aksi:"
echo "  1️⃣  Install & Konfigurasi NextDNS DoT"
echo "  2️⃣  Uninstall / Rollback"
echo "  3️⃣  Keluar"
echo ""
read -rp "Masukkan pilihan (1/2/3): " choice
echo ""

#==== ROLLBACK FUNCTION ====
rollback() {
  echo "⚠️ Terjadi kesalahan. Melakukan rollback konfigurasi..."

  if [ -f "$BACKUP_STUBBY" ]; then
    cp "$BACKUP_STUBBY" /etc/stubby/stubby.yml
    echo "✅ stubby.yml dikembalikan."
  fi

  if [ -f "$BACKUP_RESOLV" ]; then
    cp "$BACKUP_RESOLV" "$RESOLV_CONF"
    echo "✅ resolv.conf dikembalikan."
  fi

  systemctl restart stubby
  echo "⛔ Setup dibatalkan. Sistem dikembalikan ke keadaan semula."
  exit 1
}

#==== INSTALL FUNCTION ====
install_nextdns() {
  echo "🔧 Memasang Stubby dan mengatur NextDNS..."

  # Backup konfigurasi awal
  cp /etc/stubby/stubby.yml "$BACKUP_STUBBY"
  cp "$RESOLV_CONF" "$BACKUP_RESOLV"

  # Instalasi stubby
  apt update && apt install -y stubby dnsutils || rollback

  # Konfigurasi stubby
  cat > /etc/stubby/stubby.yml <<EOF
resolution_type: GETDNS_RESOLUTION_STUB
dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: GETDNS_AUTH_REQUIRED
tls_query_padding_blocksize: 128
edns_client_subnet_private: 1
round_robin_upstreams: 1

upstream_recursive_servers:
  - address_data: $NEXTDNS_IP1
    tls_auth_name: "$NEXTDNS_NAME"
    tls_port: 853
  - address_data: $NEXTDNS_IP2
    tls_auth_name: "$NEXTDNS_NAME"
    tls_port: 853
EOF

  # ✅ Validasi config menggunakan -i (fix)
  stubby -C /etc/stubby/stubby.yml -i || rollback

  # Enable & restart
  systemctl enable stubby
  systemctl restart stubby || rollback

  # Atur resolv.conf
  if systemctl is-active --quiet systemd-resolved; then
    sed -i 's/^#*DNS=.*/DNS=127.0.0.1/' /etc/systemd/resolved.conf
    sed -i 's/^#*FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
    ln -sf /run/systemd/resolve/resolv.conf "$RESOLV_CONF"
  else
    echo "nameserver 127.0.0.1" > "$RESOLV_CONF"
  fi

  echo ""
  echo "🎉 NextDNS berhasil diaktifkan dengan DNS-over-TLS!"
}

#==== UNINSTALL FUNCTION ====
uninstall_nextdns() {
  echo "🗑️ Menghapus konfigurasi dan mengembalikan sistem DNS..."

  if [ -f "$BACKUP_STUBBY" ]; then
    cp "$BACKUP_STUBBY" /etc/stubby/stubby.yml
    echo "✅ stubby.yml dikembalikan."
  fi

  if [ -f "$BACKUP_RESOLV" ]; then
    cp "$BACKUP_RESOLV" "$RESOLV_CONF"
    echo "✅ resolv.conf dikembalikan."
  fi

  systemctl stop stubby
  systemctl disable stubby
  apt remove --purge -y stubby
  apt autoremove -y

  echo ""
  echo "✅ Uninstall selesai. Sistem telah dikembalikan ke konfigurasi DNS sebelumnya."
}

#==== PILIHAN EKSEKUSI ====
case "$choice" in
  1)
    install_nextdns
    ;;
  2)
    uninstall_nextdns
    ;;
  3)
    echo "👋 Keluar."
    exit 0
    ;;
  *)
    echo "❌ Pilihan tidak valid."
    exit 1
    ;;
esac
