#!/bin/bash

# Fungsi untuk mengubah backend dari nftables ke iptables
function switch_to_iptables() {
  echo "Mengubah backend iptables dari nf_tables ke iptables legacy..."

  # Menginstall iptables-legacy, arptables-legacy, dan ebtables-legacy jika belum terpasang
  apt-get update
  apt-get install -y iptables iptables-persistent arptables ebtables

  # Mengubah link simbolik iptables ke iptables-legacy
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
  
  # Mengatur arptables dan ebtables ke versi legacy
  update-alternatives --install /usr/sbin/arptables arptables /usr/sbin/arptables-legacy 100
  update-alternatives --set arptables /usr/sbin/arptables-legacy

  update-alternatives --install /usr/sbin/ebtables ebtables /usr/sbin/ebtables-legacy 100
  update-alternatives --set ebtables /usr/sbin/ebtables-legacy

  echo "Backend iptables telah diubah ke iptables legacy."
}

# Fungsi untuk mengatur batas penggunaan
function set_usage_limit() {
  echo "Masukkan batas penggunaan (dalam TB):"
  read USAGE_LIMIT_TB

  # Validasi input apakah numerik
  if ! [[ "$USAGE_LIMIT_TB" =~ ^[0-9]+$ ]]; then
    echo "Error: Masukkan angka yang valid untuk batas penggunaan."
    exit 1
  fi

  # Menghitung batas penggunaan dalam byte
  USAGE_LIMIT_BYTES=$((USAGE_LIMIT_TB * 1024 * 1024 * 1024 * 1024))

  # Tampilkan batas penggunaan yang dipilih
  echo "Batas penggunaan diatur menjadi $USAGE_LIMIT_TB TB ($USAGE_LIMIT_BYTES bytes)."
}

# Fungsi untuk mereset aturan iptables dan menghitung ulang
function reset_usage() {
  echo "Mereset penggunaan jaringan untuk bulan baru..."

  # Menghapus aturan COUNT_TRAFFIC_IN dan COUNT_TRAFFIC_OUT dan membuat ulang untuk reset
  iptables -D INPUT -i $INTERFACE -j COUNT_TRAFFIC_IN 2>/dev/null
  iptables -D OUTPUT -o $INTERFACE -j COUNT_TRAFFIC_OUT 2>/dev/null
  iptables -F COUNT_TRAFFIC_IN 2>/dev/null
  iptables -F COUNT_TRAFFIC_OUT 2>/dev/null
  iptables -X COUNT_TRAFFIC_IN 2>/dev/null
  iptables -X COUNT_TRAFFIC_OUT 2>/dev/null

  # Membuat chain baru COUNT_TRAFFIC_IN dan COUNT_TRAFFIC_OUT
  iptables -N COUNT_TRAFFIC_IN
  iptables -N COUNT_TRAFFIC_OUT

  # Menambahkan aturan untuk menghitung lalu lintas pada interface tertentu
  iptables -A INPUT -i $INTERFACE -j COUNT_TRAFFIC_IN
  iptables -A OUTPUT -o $INTERFACE -j COUNT_TRAFFIC_OUT

  echo "Penggunaan jaringan berhasil direset."
}

# Fungsi untuk menerapkan throttle jika batas tercapai
function apply_throttle() {
  echo "Mengaktifkan pembatasan kecepatan jaringan menjadi $LIMIT_SPEED karena batas tercapai..."
  tc qdisc add dev $INTERFACE root tbf rate $LIMIT_SPEED burst 32kbit latency 400ms 2>/dev/null
  echo "Throttle diterapkan."
}

# Fungsi untuk menghapus throttle jika belum mencapai batas
function remove_throttle() {
  echo "Menghapus throttle kecepatan jaringan..."
  tc qdisc del dev $INTERFACE root 2>/dev/null
  echo "Throttle dihapus."
}

# Fungsi untuk mengatur cron job
function setup_cron_job() {
  echo "Mengatur cron job untuk otomatisasi monitoring dan reset bulanan..."

  # Menambahkan cron job untuk menjalankan script setiap jam
  (crontab -l 2>/dev/null; echo "0 * * * * /usr/local/bin/network_limit.sh") | crontab -

  # Menambahkan cron job untuk reset bulanan pada tanggal 1 pukul 00:00
  (crontab -l 2>/dev/null; echo "0 0 1 * * /usr/local/bin/network_limit.sh") | crontab -

  echo "Cron job berhasil diatur."
}

# Interface yang digunakan
INTERFACE="eth0"

# Kecepatan setelah limit tercapai (10 Mbps)
LIMIT_SPEED="10mbit"

# Mengubah backend ke iptables legacy
switch_to_iptables

# Mengatur batas penggunaan jaringan
set_usage_limit

# Mengatur cron job otomatis jika belum diatur
setup_cron_job

# Mendapatkan tanggal hari ini
CURRENT_DATE=$(date +%d)

# Reset iptables pada hari pertama setiap bulan
if [ "$CURRENT_DATE" -eq 1 ]; then
  reset_usage
fi

# Memastikan chain COUNT_TRAFFIC_IN dan COUNT_TRAFFIC_OUT ada sebelum mencoba mendapatkan byte yang digunakan
iptables -L COUNT_TRAFFIC_IN -v -x > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: Chain COUNT_TRAFFIC_IN tidak ada. Membuat ulang chain..."
  reset_usage
fi

iptables -L COUNT_TRAFFIC_OUT -v -x > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error: Chain COUNT_TRAFFIC_OUT tidak ada. Membuat ulang chain..."
  reset_usage
fi

# Mendapatkan total byte yang digunakan pada interface dengan iptables (incoming dan outgoing)
IN_BYTES=$(iptables -L COUNT_TRAFFIC_IN -v -x | grep $INTERFACE | awk '{print $2}')
OUT_BYTES=$(iptables -L COUNT_TRAFFIC_OUT -v -x | grep $INTERFACE | awk '{print $2}')

# Validasi apakah IN_BYTES dan OUT_BYTES berisi nilai numerik
if ! [[ "$IN_BYTES" =~ ^[0-9]+$ ]] || ! [[ "$OUT_BYTES" =~ ^[0-9]+$ ]]; then
  echo "Error: Tidak bisa mendapatkan jumlah byte yang digunakan. Pastikan iptables terkonfigurasi dengan benar."
  exit 1
fi

# Menghitung total byte (incoming + outgoing)
TOTAL_BYTES=$((IN_BYTES + OUT_BYTES))

# Mengecek apakah batas tercapai
if [ "$TOTAL_BYTES" -gt "$USAGE_LIMIT_BYTES" ]; then
  apply_throttle
else
  remove_throttle
fi
