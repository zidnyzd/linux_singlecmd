#!/bin/bash

#==== CONFIGURATION ====
NEXTDNS_IP1="45.90.28.57"
NEXTDNS_IP2="45.90.30.57"
NEXTDNS_NAME="91ac82.dns.nextdns.io"
BACKUP_STUBBY="/etc/stubby/stubby.yml.bak"
BACKUP_RESOLV="/etc/resolv.conf.bak"
RESOLV_CONF="/etc/resolv.conf"
LOG_FILE="/var/log/nextdns-setup.log"
#=======================

#==== LOGGING FUNCTION ====
log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

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
  log "⚠️ Terjadi kesalahan. Melakukan rollback konfigurasi..."

  if [ -f "$BACKUP_STUBBY" ]; then
    cp "$BACKUP_STUBBY" /etc/stubby/stubby.yml
    log "✅ stubby.yml dikembalikan."
  fi

  if [ -f "$BACKUP_RESOLV" ]; then
    cp "$BACKUP_RESOLV" "$RESOLV_CONF"
    log "✅ resolv.conf dikembalikan."
  fi

  systemctl restart stubby &>> "$LOG_FILE"
  log "⛔ Setup dibatalkan. Sistem dikembalikan ke keadaan semula."
  exit 1
}

#==== INSTALL FUNCTION ====
install_nextdns() {
  log "🔧 Memasang Stubby dan mengatur NextDNS..."

  # Backup konfigurasi awal
  cp /etc/stubby/stubby.yml "$BACKUP_STUBBY" 2>/dev/null
  cp "$RESOLV_CONF" "$BACKUP_RESOLV" 2>/dev/null

  # Instalasi stubby
  apt update >> "$LOG_FILE" 2>&1
  apt install -y stubby dnsutils >> "$LOG_FILE" 2>&1 || rollback

  # Tulis konfigurasi YAML menggunakan tee (preserve indent)
  tee /etc/stubby/stubby.yml > /dev/null <<'EOF'
# Stubby configuration for NextDNS DoT (Debian 10 Compatible)
resolution_type: GETDNS_RESOLUTION_STUB
dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: GETDNS_AUTH_NONE
tls_query_padding_blocksize: 128
edns_client_subnet_private: true
round_robin_upstreams: true

upstream_recursive_servers:
  - address_data: 45.90.28.57
    tls_auth_name: "91ac82.dns.nextdns.io"
    tls_port: 853
  - address_data: 45.90.30.57
    tls_auth_name: "91ac82.dns.nextdns.io"
    tls_port: 853
EOF

  # Validasi konfigurasi stubby
  stubby -C /etc/stubby/stubby.yml -i >> "$LOG_FILE" 2>&1 || {
    log "❌ Validasi YAML gagal. Isi stubby.yml:"
    cat /etc/stubby/stubby.yml | tee -a "$LOG_FILE"
    rollback
  }

  # Enable dan restart stubby
  systemctl enable stubby >> "$LOG_FILE" 2>&1
  systemctl restart stubby >> "$LOG_FILE" 2>&1 || rollback

  # Atur resolv.conf
  if systemctl is-active --quiet systemd-resolved; then
    sed -i 's/^#*DNS=.*/DNS=127.0.0.1/' /etc/systemd/resolved.conf
    sed -i 's/^#*FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
    systemctl restart systemd-resolved >> "$LOG_FILE" 2>&1
    ln -sf /run/systemd/resolve/resolv.conf "$RESOLV_CONF"
  else
    echo "nameserver 127.0.0.1" > "$RESOLV_CONF"
  fi

  log "🎉 NextDNS berhasil diaktifkan dengan DNS-over-TLS!"
}

#==== UNINSTALL FUNCTION ====
uninstall_nextdns() {
  log "🗑️ Menghapus konfigurasi dan mengembalikan sistem DNS..."

  if [ -f "$BACKUP_STUBBY" ]; then
    cp "$BACKUP_STUBBY" /etc/stubby/stubby.yml
    log "✅ stubby.yml dikembalikan."
  fi

  if [ -f "$BACKUP_RESOLV" ]; then
    cp "$BACKUP_RESOLV" "$RESOLV_CONF"
    log "✅ resolv.conf dikembalikan."
  fi

  systemctl stop stubby >> "$LOG_FILE" 2>&1
  systemctl disable stubby >> "$LOG_FILE" 2>&1
  apt remove --purge -y stubby >> "$LOG_FILE" 2>&1
  apt autoremove -y >> "$LOG_FILE" 2>&1

  log "✅ Uninstall selesai. Sistem telah dikembalikan ke konfigurasi DNS sebelumnya."
}

#==== EKSEKUSI ====
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
