#!/bin/bash
# =============================================================
#  hostname_expire.sh
#  Atur hostname VPS + jadwalkan shutdown otomatis (expired VPS)
#  - Hostname akan memuat tanggal expired (format: <nama>-expYYYYMMDD)
#  - Shutdown otomatis berjalan via cron pada tanggal expired
#  - MOTD/banner login menampilkan sisa hari aktif
# =============================================================

# --- Warna ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

EXPIRY_CONF="/etc/vps_expiry.conf"
EXPIRY_CHECK="/usr/local/sbin/vps_expiry_check.sh"
MOTD_FILE="/etc/update-motd.d/99-vps-expiry"
CRON_FILE="/etc/cron.d/vps_expiry"

# --- Cek root ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Jalankan script ini sebagai root atau dengan sudo.${NC}"
        exit 1
    fi
}

# --- Validasi tanggal (DD-MM-YYYY) -> set TANGGAL_ISO ---
TANGGAL_ISO=""
validate_date() {
    local d="$1"
    # Wajib format DD-MM-YYYY
    if ! [[ "$d" =~ ^([0-9]{2})-([0-9]{2})-([0-9]{4})$ ]]; then
        return 1
    fi
    local dd="${BASH_REMATCH[1]}"
    local mm="${BASH_REMATCH[2]}"
    local yyyy="${BASH_REMATCH[3]}"
    local iso="${yyyy}-${mm}-${dd}"

    # Pastikan tanggal valid (mis. 31-02-2026 ditolak)
    if ! date -d "$iso" >/dev/null 2>&1; then
        return 1
    fi
    local epoch_in epoch_now
    epoch_in=$(date -d "$iso" +%s)
    epoch_now=$(date +%s)
    if [ "$epoch_in" -le "$epoch_now" ]; then
        return 2
    fi
    TANGGAL_ISO="$iso"
    return 0
}

# --- Tulis ulang script pemeriksa expired ---
write_expiry_check_script() {
    cat > "$EXPIRY_CHECK" <<'EOSCRIPT'
#!/bin/bash
# Auto-shutdown saat VPS expired
CONF="/etc/vps_expiry.conf"
[ -f "$CONF" ] || exit 0
# shellcheck disable=SC1090
. "$CONF"
[ -z "$EXPIRY_DATE" ] && exit 0

now_epoch=$(date +%s)
exp_epoch=$(date -d "$EXPIRY_DATE 23:59:59" +%s 2>/dev/null) || exit 0

if [ "$now_epoch" -ge "$exp_epoch" ]; then
    logger -t vps_expiry "VPS expired pada $EXPIRY_DATE. Mematikan sistem."
    /sbin/shutdown -h now "VPS expired pada $EXPIRY_DATE"
fi
EOSCRIPT
    chmod 755 "$EXPIRY_CHECK"
}

# --- Tulis MOTD penampil sisa hari ---
write_motd_script() {
    mkdir -p /etc/update-motd.d 2>/dev/null
    cat > "$MOTD_FILE" <<'EOMOTD'
#!/bin/bash
CONF="/etc/vps_expiry.conf"
[ -f "$CONF" ] || exit 0
. "$CONF"
[ -z "$EXPIRY_DATE" ] && exit 0

now_epoch=$(date +%s)
exp_epoch=$(date -d "$EXPIRY_DATE 23:59:59" +%s 2>/dev/null) || exit 0
diff=$(( (exp_epoch - now_epoch) / 86400 ))
exp_human=$(date -d "$EXPIRY_DATE" +%d-%m-%Y 2>/dev/null)

echo ""
echo "============================================================"
echo "  HOSTNAME : $(hostname)"
echo "  CLIENT   : ${CLIENT_NAME:-unknown}"
echo "  EXPIRED  : ${exp_human:-$EXPIRY_DATE}"
if [ "$diff" -lt 0 ]; then
    echo "  STATUS   : VPS SUDAH EXPIRED!"
elif [ "$diff" -le 3 ]; then
    echo "  STATUS   : SEGERA PERPANJANG ($diff hari lagi)"
else
    echo "  STATUS   : Aktif ($diff hari tersisa)"
fi
echo "============================================================"
echo ""
EOMOTD
    chmod 755 "$MOTD_FILE"

    # Pastikan dipanggil saat login (untuk distro tanpa update-motd.d)
    if ! grep -q "$MOTD_FILE" /etc/profile 2>/dev/null; then
        echo "[ -x \"$MOTD_FILE\" ] && \"$MOTD_FILE\"" >> /etc/profile
    fi
}

# --- Pasang cron untuk pengecekan setiap menit ---
install_cron() {
    cat > "$CRON_FILE" <<EOF
# VPS expiry auto-shutdown checker
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
* * * * * root $EXPIRY_CHECK >/dev/null 2>&1
EOF
    chmod 644 "$CRON_FILE"
    # Reload cron service jika ada
    systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
}

# --- Set hostname + expiry ---
set_hostname_expiry() {
    echo -e "${YELLOW}Masukkan nama klien/identitas VPS (contoh: budi):${NC} "
    read -r client
    if [ -z "$client" ]; then
        echo -e "${RED}Nama klien tidak boleh kosong.${NC}"
        return 1
    fi
    # Bersihkan karakter ilegal hostname
    client=$(echo "$client" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    echo -e "${YELLOW}Masukkan tanggal expired (format DD-MM-YYYY):${NC} "
    read -r exp_date

    validate_date "$exp_date"
    case $? in
        1) echo -e "${RED}Format tanggal salah. Gunakan DD-MM-YYYY.${NC}"; return 1 ;;
        2) echo -e "${RED}Tanggal expired harus di masa depan.${NC}"; return 1 ;;
    esac

    # ISO date untuk penyimpanan/perhitungan
    local exp_iso="$TANGGAL_ISO"
    local exp_compact
    exp_compact=$(date -d "$exp_iso" +%Y%m%d)
    local new_hostname="${client}-exp${exp_compact}"

    echo -e "${CYAN}Hostname baru : ${new_hostname}${NC}"
    echo -e "${CYAN}Expired       : ${exp_date}${NC}"
    echo -e "${YELLOW}Lanjutkan? (y/n):${NC} "
    read -r confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "Dibatalkan."; return 1; }

    # Set hostname
    hostnamectl set-hostname "$new_hostname" 2>/dev/null || hostname "$new_hostname"
    echo "$new_hostname" > /etc/hostname

    # Update /etc/hosts
    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
    else
        echo -e "127.0.1.1\t$new_hostname" >> /etc/hosts
    fi

    # Simpan konfigurasi expiry (EXPIRY_DATE disimpan dalam format ISO YYYY-MM-DD
    # agar mudah dihitung; tampilan ke user dikonversi ke DD-MM-YYYY)
    cat > "$EXPIRY_CONF" <<EOF
CLIENT_NAME="$client"
EXPIRY_DATE="$exp_iso"
EXPIRY_DATE_HUMAN="$exp_date"
HOSTNAME="$new_hostname"
SET_AT="$(date '+%d-%m-%Y %H:%M:%S')"
EOF
    chmod 644 "$EXPIRY_CONF"

    write_expiry_check_script
    write_motd_script
    install_cron

    echo -e "${GREEN}Hostname dan jadwal expired berhasil diatur.${NC}"
    echo -e "${GREEN}VPS akan otomatis shutdown pada akhir tanggal $exp_date.${NC}"
}

# --- Tampilkan status saat ini ---
show_status() {
    echo -e "\n${YELLOW}=== Status VPS ===${NC}"
    echo -e "Hostname saat ini : ${CYAN}$(hostname)${NC}"
    if [ -f "$EXPIRY_CONF" ]; then
        # shellcheck disable=SC1090
        . "$EXPIRY_CONF"
        local now_epoch exp_epoch diff exp_human
        now_epoch=$(date +%s)
        exp_epoch=$(date -d "$EXPIRY_DATE 23:59:59" +%s 2>/dev/null)
        diff=$(( (exp_epoch - now_epoch) / 86400 ))
        exp_human="${EXPIRY_DATE_HUMAN:-$(date -d "$EXPIRY_DATE" +%d-%m-%Y 2>/dev/null)}"
        echo -e "Klien             : ${CYAN}$CLIENT_NAME${NC}"
        echo -e "Tanggal expired   : ${CYAN}$exp_human${NC}"
        echo -e "Disetel pada      : ${CYAN}$SET_AT${NC}"
        if [ "$diff" -lt 0 ]; then
            echo -e "Status            : ${RED}SUDAH EXPIRED${NC}"
        elif [ "$diff" -le 3 ]; then
            echo -e "Status            : ${YELLOW}$diff hari lagi (segera perpanjang)${NC}"
        else
            echo -e "Status            : ${GREEN}$diff hari tersisa${NC}"
        fi
    else
        echo -e "${YELLOW}Belum ada jadwal expired yang diatur.${NC}"
    fi
    echo ""
}

# --- Hapus jadwal expired ---
remove_expiry() {
    echo -e "${YELLOW}Anda akan menghapus jadwal shutdown expired (hostname tetap).${NC}"
    echo -e "${YELLOW}Lanjutkan? (y/n):${NC} "
    read -r c
    [[ "$c" != "y" && "$c" != "Y" ]] && { echo "Dibatalkan."; return; }
    rm -f "$EXPIRY_CONF" "$EXPIRY_CHECK" "$CRON_FILE" "$MOTD_FILE"
    sed -i "\|$MOTD_FILE|d" /etc/profile 2>/dev/null
    systemctl reload cron 2>/dev/null || systemctl reload crond 2>/dev/null || true
    echo -e "${GREEN}Jadwal expired dihapus.${NC}"
}

# --- Ubah hostname saja (tanpa expiry) ---
change_hostname_only() {
    echo -e "${YELLOW}Masukkan hostname baru:${NC} "
    read -r h
    [ -z "$h" ] && { echo -e "${RED}Hostname kosong.${NC}"; return 1; }
    h=$(echo "$h" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g')
    hostnamectl set-hostname "$h" 2>/dev/null || hostname "$h"
    echo "$h" > /etc/hostname
    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$h/" /etc/hosts
    else
        echo -e "127.0.1.1\t$h" >> /etc/hosts
    fi
    echo -e "${GREEN}Hostname diubah menjadi: $h${NC}"
}

# --- Menu utama ---
show_menu() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  HOSTNAME & EXPIRED SHUTDOWN MANAGER${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo "1. Set hostname + jadwal shutdown expired"
    echo "2. Tampilkan status hostname & expired"
    echo "3. Ubah hostname saja (tanpa jadwal)"
    echo "4. Hapus jadwal shutdown expired"
    echo "5. Keluar"
    echo -e "${CYAN}============================================${NC}"
    echo -n "Pilih menu (1-5): "
}

# --- Main ---
check_root
while true; do
    show_menu
    read -r choice
    case "$choice" in
        1) set_hostname_expiry ;;
        2) show_status ;;
        3) change_hostname_only ;;
        4) remove_expiry ;;
        5) echo -e "${GREEN}Selesai.${NC}"; exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid.${NC}" ;;
    esac
    echo -e "\nTekan Enter untuk lanjut..."
    read -r
done
