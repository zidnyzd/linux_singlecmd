#!/bin/bash

# Global Variables
DIR="/etc/zivpn"
CONFIG_FILE="$DIR/config.json"
USER_DB="$DIR/passwd"
BIN="/usr/local/bin/zivpn-core" # Rename binary core agar tidak bentrok dengan menu command
SERVICE_FILE="/etc/systemd/system/zivpn.service"

# Set Timezone to GMT+7 (Asia/Jakarta) for this script session
export TZ='Asia/Jakarta'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helper Functions
mkdir -p $DIR
if [[ ! -f "$USER_DB" ]]; then touch "$USER_DB"; fi

# --- Core Logic: Sync DB to Config ---
update_config() {
    # Ambil semua password dari DB yang belum expired
    local current_time=$(date +%s)
    local passwords=()
    
    # Baca DB baris per baris
    # Gunakan variabel lokal loop yang unik atau declare local
    local l_user l_pass l_exp
    while IFS=':' read -r l_user l_pass l_exp; do
        # Skip baris kosong atau format salah
        if [[ -z "$l_user" || -z "$l_pass" || -z "$l_exp" ]]; then continue; fi
        
        if [[ "$l_exp" -gt "$current_time" ]]; then
            passwords+=("$l_pass")
        fi
    done < "$USER_DB"

    # Jika tidak ada user, gunakan default 'zi' agar service tidak error
    if [ ${#passwords[@]} -eq 0 ]; then
        passwords=("zi")
    fi

    # Buat format JSON array string secara manual untuk SED
    # Contoh target: "config": ["pass1","pass2"]
    local json_str=""
    for p in "${passwords[@]}"; do
        json_str+="\"$p\","
    done
    # Hapus koma terakhir
    json_str="${json_str%,}"
    
    local new_config_line="\"config\": [$json_str]"

    # Pastikan config file ada
    if [ ! -f "$CONFIG_FILE" ]; then
        wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O $CONFIG_FILE > /dev/null 2>&1
    fi

    # Baca config lama untuk perbandingan
    local old_config_line=$(grep -o '"config":.*' "$CONFIG_FILE" | head -1)
    
    # Bandingkan config baru dengan config lama
    if [ "$old_config_line" = "$new_config_line" ]; then
        # Config tidak berubah, tidak perlu restart
        return 0
    fi

    # Gunakan SED untuk mengganti baris "config": [...]
    # Asumsi format file asli: "config": [ ... ]
    # Kita cari baris yang mengandung "config": dan ganti seluruhnya
    sed -i "s/\"config\":.*/$new_config_line/g" "$CONFIG_FILE"
    
    # Restart service hanya jika config benar-benar berubah
    systemctl restart zivpn
}

# --- Install Function ---
install_zivpn() {
    echo -e "${GREEN}Updating server...${NC}"
    apt-get update && apt-get upgrade -y
    apt-get install iptables ufw iproute2 -y

    systemctl stop zivpn.service > /dev/null 2>&1

    echo -e "${GREEN}Downloading UDP Service...${NC}"
    wget https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O $BIN > /dev/null 2>&1
    chmod +x $BIN

    mkdir -p $DIR
    
    # Download Config Default
    wget https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O $CONFIG_FILE > /dev/null 2>&1

    echo "Generating cert files..."
    openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" -keyout "$DIR/zivpn.key" -out "$DIR/zivpn.crt" 2>/dev/null

    # Tuning Network
    sysctl -w net.core.rmem_max=16777216 > /dev/null 2>&1
    sysctl -w net.core.wmem_max=16777216 > /dev/null 2>&1
    
    # Disable IPv6 (Optional but recommended for stability)
    echo -e "${YELLOW}Disabling IPv6...${NC}"
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1 > /dev/null 2>&1
    
    # Persist Disable IPv6
    if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
        echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
        sysctl -p > /dev/null 2>&1
    fi

    # Create Service
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$DIR
ExecStart=$BIN server -c $CONFIG_FILE
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable zivpn.service
    
    # Setup Firewall
    if command -v iptables &> /dev/null; then
        local iface=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
        iptables -t nat -A PREROUTING -i $iface -p udp --dport 6000:19999 -j DNAT --to-destination :5667
    fi
    
    if command -v ufw &> /dev/null; then
        ufw allow 6000:19999/udp
        ufw allow 5667/udp
    fi

    # Initialize DB with default if empty
    if [ ! -s "$USER_DB" ]; then
        # Default user
        echo "admin:admin:$(date -d "+30 days" +%s)" > "$USER_DB"
    fi

    update_config
    
    # Setup Cron otomatis saat install
    setup_cron

    # Setup Alias / Command Shortcut
    echo -e "${GREEN}Creating system shortcuts...${NC}"
    # Copy script ke lokasi permanen jika belum
    if [ "$0" != "/usr/local/bin/zivpn" ]; then
        cp "$0" /usr/local/bin/zivpn
        chmod +x /usr/local/bin/zivpn
    fi
    
    # Symlink 'menu' command (Optional, be careful overwriting existing menu)
    ln -sf /usr/local/bin/zivpn /usr/bin/zivpn
    # ln -sf /usr/local/bin/zivpn /usr/bin/menu
    
    echo -e "${GREEN}Shortcuts created! You can now type 'zivpn' to run this script.${NC}"
    
    echo -e "${GREEN}ZIVPN Installed Successfully!${NC}"
}

update_script() {
    echo -e "${YELLOW}Checking for updates...${NC}"
    
    # URL Script Terbaru (Sesuaikan dengan Repo Anda)
    local UPDATE_URL="https://raw.githubusercontent.com/zidnyzd/linux/main/zivpn.sh"
    local CURRENT_SCRIPT="/usr/local/bin/zivpn"
    
    # Download script baru ke temp
    wget -q $UPDATE_URL -O /tmp/zivpn-update.sh
    
    if [ $? -eq 0 ]; then
        # Cek apakah file valid
        if grep -q "ZIVPN MANAGER" /tmp/zivpn-update.sh; then
            echo -e "${GREEN}Update found! Installing...${NC}"
            
            # Pindahkan ke lokasi utama
            mv /tmp/zivpn-update.sh $CURRENT_SCRIPT
            chmod +x $CURRENT_SCRIPT
            
            # Update juga file di direktori kerja saat ini jika ada
            if [ -f "zivpn.sh" ]; then
                cp $CURRENT_SCRIPT zivpn.sh
            fi
            
            echo -e "${GREEN}Script updated successfully! Restarting menu...${NC}"
            sleep 2
            exec $CURRENT_SCRIPT menu
        else
            echo -e "${RED}Download failed or invalid script content.${NC}"
            rm -f /tmp/zivpn-update.sh
        fi
    else
        echo -e "${RED}Failed to check for updates. Check internet connection.${NC}"
    fi
}

uninstall_zivpn() {
    echo -e "${YELLOW}Uninstalling ZIVPN...${NC}"
    systemctl stop zivpn.service 2>/dev/null
    systemctl disable zivpn.service 2>/dev/null
    rm -f $SERVICE_FILE
    systemctl daemon-reload
    
    # Remove binary core
    rm -f $BIN
    
    # Remove menu shortcuts
    rm -f /usr/local/bin/zivpn
    rm -f /usr/bin/zivpn
    rm -f /usr/bin/menu
    
    rm -rf $DIR
    
    # Remove cron
    crontab -l 2>/dev/null | grep -v "zivpn.sh" > /tmp/cron_zivpn
    crontab /tmp/cron_zivpn
    rm -f /tmp/cron_zivpn
    
    # Attempt to remove firewall rules
    if command -v iptables &> /dev/null; then
        local iface=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
        iptables -t nat -D PREROUTING -i $iface -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null
    fi
    if command -v ufw &> /dev/null; then
        ufw delete allow 6000:19999/udp 2>/dev/null
        ufw delete allow 5667/udp 2>/dev/null
    fi
    
    echo -e "${GREEN}ZIVPN Uninstalled.${NC}"
}

# --- User Management ---

add_user() {
    local user=$1
    local pass=$2
    local days=$3
    
    # Auto-detect arguments (if days is empty, assume 2nd arg is days and pass=user)
    if [[ -z "$days" ]]; then
        if [[ -n "$pass" ]]; then
            days="$pass"
            pass="$user"
        fi
    fi

    # Jika input kosong, minta input interaktif
    if [[ -z "$user" ]]; then
        read -p "Username : " user
    fi
    
    if [[ -z "$pass" ]]; then
         read -p "Password (Enter for '$user'): " pass
         if [[ -z "$pass" ]]; then pass="$user"; fi
    fi
    
    if [[ -z "$days" ]]; then
        read -p "Days     : " days
    fi

    # Validasi input
    if [[ -z "$user" || -z "$days" ]]; then
        echo -e "${RED}Error: Username and Days are required.${NC}"
        return
    fi

    # Cek user exist
    if grep -q "^$user:" "$USER_DB"; then
        echo -e "${RED}User $user already exists!${NC}"
        return
    fi
    
    # Ensure pass is set
    if [[ -z "$pass" ]]; then pass="$user"; fi

    # Sanitize days (numbers only)
    days=$(echo "$days" | tr -dc '0-9')
    if [[ -z "$days" ]]; then
        echo -e "${RED}Error: Invalid Days.${NC}"
        return
    fi

    local exp_date=$(date -d "+$days days" +%s)

    # Simpan ke DB
    echo "$user:$pass:$exp_date" >> "$USER_DB"
    
    # Update Config ZIVPN
    update_config
    
    # Jika Mode API (ZIVPN_API_MODE=1), skip output interaktif/clear
    if [[ "$ZIVPN_API_MODE" == "1" ]]; then
        # Output simple format for parsing
        echo "Domain : $(cat /etc/zivpn/domain 2>/dev/null || curl -s ifconfig.me)"
        echo "Username : $user"
        echo "Password : $pass"
        echo "Expires On : $(date -d "@$exp_date" "+%d-%m-%Y %H:%M")"
        return
    fi
    
    # Get info for display
    local domain=$(cat /etc/zivpn/domain 2>/dev/null || curl -s ifconfig.me)
    local exp_display=$(date -d "@$exp_date" "+%d-%m-%Y %H:%M")
    
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "          ZIVPN ACCOUNT CREATED          "
    echo -e "${BLUE}=========================================${NC}"
    echo -e " Domain     : ${GREEN}$domain${NC}"
    echo -e " Port UDP   : ${GREEN}5667${NC} (or 6000-19999)"
    echo -e " Username   : ${GREEN}$user${NC}"
    echo -e " Password   : ${GREEN}$pass${NC}"
    echo -e " Valid Days : ${GREEN}$days Days${NC}"
    echo -e " Expires On : ${GREEN}$exp_display${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e " ${YELLOW}Copy this info to your ZIVPN Client${NC}"
    echo -e "${BLUE}=========================================${NC}"
    read -p "Press Enter to return..."
}

add_trial() {
    local user=$1
    local mins=$2
    
    echo -e "${BLUE}Create Trial Account${NC}"
    
    if [[ -z "$user" ]]; then
        read -p "Username : " user
    fi
    
    if [[ -z "$mins" ]]; then
        read -p "Minutes  : " mins
    fi

    if [[ -z "$user" || -z "$mins" ]]; then
        echo -e "${RED}Error: Username and Minutes are required.${NC}"
        return
    fi

    if grep -q "^$user:" "$USER_DB"; then
        echo -e "${RED}User $user already exists!${NC}"
        return
    fi

    local pass="$user"
    local now=$(date +%s)
    local exp_date=$((now + (mins * 60))) # Kalkulasi menit ke detik

    echo "$user:$pass:$exp_date" >> "$USER_DB"
    update_config
    
    local domain=$(cat /etc/zivpn/domain 2>/dev/null || curl -s ifconfig.me)
    local exp_time=$(date -d "@$exp_date" "+%H:%M:%S")
    
    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "           ZIVPN TRIAL CREATED           "
    echo -e "${BLUE}=========================================${NC}"
    echo -e " Domain     : ${GREEN}$domain${NC}"
    echo -e " Username   : ${GREEN}$user${NC}"
    echo -e " Password   : ${GREEN}$pass${NC}"
    echo -e " Valid Mins : ${GREEN}$mins Minutes${NC}"
    echo -e " Expires At : ${GREEN}$exp_time${NC}"
    echo -e "${BLUE}=========================================${NC}"
    read -p "Press Enter to return..."
}

del_user() {
    local user=$1
    
    # Jika argumen kosong, tampilkan menu pilih user
    if [[ -z "$user" ]]; then
        echo -e "${YELLOW}Select User to Delete:${NC}"
        echo "--------------------------------------------------------------"
        printf "%-5s %-15s %-35s\n" "No" "Username" "Expired"
        echo "--------------------------------------------------------------"
        
        local i=1
        local users=()
        local now=$(date +%s)
        while IFS=':' read -r u p e; do
            if [[ -z "$u" ]]; then continue; fi
            if [[ -z "$e" || ! "$e" =~ ^[0-9]+$ ]]; then e=0; fi
            
            local exp_readable=$(date -d "@$e" "+%d-%m-%Y %H:%M")
            local diff=$((e - now))
            local days_left=$((diff / 86400))
            if [[ "$e" -lt "$now" ]]; then days_left=0; fi
            
            local exp_display="$exp_readable ($days_left Days)"
            
            printf "%-5s %-15s %-35s\n" "$i" "$u" "$exp_display"
            users[$i]="$u"
            ((i++))
        done < "$USER_DB"
        echo "--------------------------------------------------------------"
        
        read -p "Enter Number: " num
        user="${users[$num]}"
    fi

    if [[ -z "$user" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        return
    fi

    if ! grep -q "^$user:" "$USER_DB"; then
        echo -e "${RED}User $user not found!${NC}"
        return
    fi

    # Jika Mode API, skip konfirmasi
    if [[ "$ZIVPN_API_MODE" == "1" ]]; then
        sed -i "/^$user:/d" "$USER_DB"
        update_config
        echo "User $user deleted"
        return
    fi

    read -p "Are you sure you want to delete '$user'? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        sed -i "/^$user:/d" "$USER_DB"
        update_config
        echo -e "${GREEN}User $user deleted!${NC}"
    else
        echo -e "${YELLOW}Deletion cancelled.${NC}"
    fi
}

renew_user() {
    local user=$1
    local days=$2
    
    # Jika argumen kosong, tampilkan menu pilih user
    if [[ -z "$user" ]]; then
        echo -e "${YELLOW}Select User to Renew:${NC}"
        echo "--------------------------------------------------------------"
        printf "%-5s %-15s %-35s\n" "No" "Username" "Expired"
        echo "--------------------------------------------------------------"
        
        local i=1
        local users=()
        local now=$(date +%s)
        while IFS=':' read -r u p e; do
            if [[ -z "$u" ]]; then continue; fi
            if [[ -z "$e" || ! "$e" =~ ^[0-9]+$ ]]; then e=0; fi
            
            local exp_readable=$(date -d "@$e" "+%d-%m-%Y %H:%M")
            local diff=$((e - now))
            local days_left=$((diff / 86400))
            if [[ "$e" -lt "$now" ]]; then days_left=0; fi
            
            local exp_display="$exp_readable ($days_left Days)"
            
            printf "%-5s %-15s %-35s\n" "$i" "$u" "$exp_display"
            users[$i]="$u"
            ((i++))
        done < "$USER_DB"
        echo "--------------------------------------------------------------"
        
        read -p "Enter Number: " num
        user="${users[$num]}"
    fi
    
    if [[ -z "$days" ]]; then
        read -p "Add Days: " days
    fi

    # Sanitize days
    days=$(echo "$days" | tr -dc '0-9')
    if [[ -z "$days" ]]; then
        echo -e "${RED}Invalid Days.${NC}"
        return
    fi

    if [[ -z "$user" ]]; then
        echo -e "${RED}Invalid selection!${NC}"
        return
    fi

    if ! grep -q "^$user:" "$USER_DB"; then
        echo -e "${RED}User $user not found!${NC}"
        return
    fi

    # Ambil expiry lama (epoch timestamp)
    local current_exp=$(grep "^$user:" "$USER_DB" | cut -d: -f3)
    local now=$(date +%s)
    
    # Validasi jika user ditemukan tapi corrupt (timestamp kosong)
    if [[ -z "$current_exp" ]]; then
        echo -e "${YELLOW}Warning: User data corrupted (no expiry date). Resetting expiry.${NC}"
        current_exp=0
    fi

    local days_in_seconds=$((days * 86400))
    local new_exp=0

    # Logika renew
    if [[ "$current_exp" -lt "$now" ]]; then
        # Jika expired, mulai dari sekarang + hari
        new_exp=$((now + days_in_seconds))
    else
        # Jika belum expired, tambah dari exp lama
        new_exp=$((current_exp + days_in_seconds))
    fi

    # Gunakan temp file dan loop untuk update
    local temp_db="$USER_DB.tmp"
    rm -f "$temp_db"
    local l_user l_pass l_exp
    while IFS=':' read -r l_user l_pass l_exp; do
        if [[ "$l_user" == "$user" ]]; then
            echo "$l_user:$l_pass:$new_exp" >> "$temp_db"
        else
            echo "$l_user:$l_pass:$l_exp" >> "$temp_db"
        fi
    done < "$USER_DB"
    mv "$temp_db" "$USER_DB"
    
    update_config

    # Jika Mode API (ZIVPN_API_MODE=1), output format parsing
    if [[ "$ZIVPN_API_MODE" == "1" ]]; then
        echo "Domain : $(cat /etc/zivpn/domain 2>/dev/null || curl -s ifconfig.me)"
        echo "Username : $user"
        echo "Expires On : $(date -d "@$new_exp" "+%d-%m-%Y %H:%M")"
        return
    fi

    echo -e "${GREEN}User $user renewed until $(date -d @$new_exp)!${NC}"
}

count_active_users() {
    # Fungsi untuk menghitung jumlah akun aktif (belum expired)
    local now=$(date +%s)
    local active_count=0
    local expired_count=0
    local total_count=0
    
    local l_user l_pass l_exp
    while IFS=':' read -r l_user l_pass l_exp; do
        if [[ -z "$l_user" ]]; then continue; fi
        
        total_count=$((total_count + 1))
        
        # Handle corrupt date
        if [[ -z "$l_exp" || ! "$l_exp" =~ ^[0-9]+$ ]]; then
            l_exp=0
        fi
        
        if [[ "$l_exp" -gt "$now" ]]; then
            active_count=$((active_count + 1))
        else
            expired_count=$((expired_count + 1))
        fi
    done < "$USER_DB"
    
    echo "$active_count:$expired_count:$total_count"
}

check_user() {
    echo -e "${YELLOW}Checking User Database...${NC}"
    echo "----------------------------------------------------------------------------------"
    printf "%-15s %-15s %-35s %b\n" "Username" "Password" "Expires On" "Status"
    echo "----------------------------------------------------------------------------------"
    
    local now=$(date +%s)
    local l_user l_pass l_exp
    while IFS=':' read -r l_user l_pass l_exp; do
        if [[ -z "$l_user" ]]; then continue; fi
        
        # Handle corrupt date
        if [[ -z "$l_exp" || ! "$l_exp" =~ ^[0-9]+$ ]]; then
            l_exp=0
        fi
        
        local exp_readable=$(date -d "@$l_exp" "+%d-%m-%Y %H:%M")
        local diff=$((l_exp - now))
        local days_left=$((diff / 86400))
        
        local status="${GREEN}Active${NC}"
        if [[ "$l_exp" -lt "$now" ]]; then
            status="${RED}Expired${NC}"
            days_left=0
        fi
        
        # Format: DD-MM-YYYY HH:MM (X Days)
        local exp_display="$exp_readable ($days_left Days)"
        
        printf "%-15s %-15s %-35s %b\n" "$l_user" "$l_pass" "$exp_display" "$status"
    done < "$USER_DB"
    echo "----------------------------------------------------------------------------------"
    
    # Tampilkan summary jumlah akun
    local user_stats=$(count_active_users)
    local active_count=$(echo "$user_stats" | cut -d: -f1)
    local expired_count=$(echo "$user_stats" | cut -d: -f2)
    local total_count=$(echo "$user_stats" | cut -d: -f3)
    
    echo -e "${BLUE}Summary:${NC}"
    echo -e "  Total Accounts  : $total_count"
    echo -e "  ${GREEN}Active Accounts${NC} : $active_count"
    echo -e "  ${RED}Expired Accounts${NC}: $expired_count"
    echo "----------------------------------------------------------------------------------"
}

backup_tg() {
    local tg_file="/etc/zivpn/telegram.conf"
    
    # Load config if exists
    if [ -f "$tg_file" ]; then
        source "$tg_file" 2>/dev/null
    fi
    
    # Check variables, if empty prompt user
    if [[ -z "$ZIVPN_TG_TOKEN" || -z "$ZIVPN_TG_CHATID" ]]; then
        echo -e "${YELLOW}Telegram configuration not found!${NC}"
        echo -e "Please enter your Telegram Bot Token and Chat ID."
        
        read -p "Bot Token : " ZIVPN_TG_TOKEN
        read -p "Chat ID   : " ZIVPN_TG_CHATID
        
        if [[ -n "$ZIVPN_TG_TOKEN" && -n "$ZIVPN_TG_CHATID" ]]; then
            # Save to file
            echo "ZIVPN_TG_TOKEN=\"$ZIVPN_TG_TOKEN\"" > "$tg_file"
            echo "ZIVPN_TG_CHATID=\"$ZIVPN_TG_CHATID\"" >> "$tg_file"
            echo -e "${GREEN}Configuration saved to $tg_file${NC}"
        else
            echo -e "${RED}Error: Token and Chat ID cannot be empty.${NC}"
            return
        fi
    fi

    echo -e "${YELLOW}Creating backup...${NC}"
    local backup_file="/tmp/zivpn_backup_$(date +%Y%m%d).tar.gz"
    tar -czf "$backup_file" "$DIR"
    
    echo -e "${YELLOW}Sending to Telegram...${NC}"
    curl -s -F chat_id="$ZIVPN_TG_CHATID" \
         -F document=@"$backup_file" \
         -F caption="ZIVPN Backup $(date)" \
         "https://api.telegram.org/bot$ZIVPN_TG_TOKEN/sendDocument" > /dev/null
         
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Backup sent successfully to Telegram!${NC}"
    else
        echo -e "\n${RED}Failed to send backup. Check your Token/Chat ID.${NC}"
    fi
    
    rm -f "$backup_file"
}

restore_menu() {
    echo -e "${BLUE}Select Restore Method:${NC}"
    echo "1. Restore from Telegram (Auto-download)" # Future development
    echo "2. Restore via Web Upload (Browser)"
    echo "3. Manual File (/root/zivpn_restore.tar.gz)"
    read -p "Select Option: " res_opt
    
    case $res_opt in
        1)
            # Simpel: minta user forward file ke bot, lalu bot kasih link? 
            # Karena parsing update TG agak rumit di bash, kita arahkan ke Web Upload saja dulu atau tetap manual
            echo -e "${YELLOW}Feature under development. Please use Web Upload.${NC}"
            restore_web
            ;;
        2) restore_web ;;
        3) restore_manual ;;
        *) echo -e "${RED}Invalid option!${NC}" ;;
    esac
}

restore_manual() {
    if [ -f "/root/zivpn_restore.tar.gz" ]; then
        echo -e "${YELLOW}File found. Restoring...${NC}"
        tar -xzf "/root/zivpn_restore.tar.gz" -C /
        update_config
        echo -e "${GREEN}Restored successfully!${NC}"
        rm -f "/root/zivpn_restore.tar.gz"
    else
        echo -e "${RED}File /root/zivpn_restore.tar.gz not found!${NC}"
    fi
}

restore_web() {
    local port=8888
    local ip=$(curl -s ifconfig.me)
    local temp_py="/tmp/zivpn_upload.py"
    
    # Install python3 jika belum ada (harusnya sudah)
    if ! command -v python3 &> /dev/null; then
        apt-get install python3 -y > /dev/null 2>&1
    fi

    # Allow port firewall sementara
    if command -v ufw &> /dev/null; then ufw allow $port/tcp >/dev/null 2>&1; fi
    if command -v iptables &> /dev/null; then iptables -I INPUT -p tcp --dport $port -j ACCEPT >/dev/null 2>&1; fi

    # Buat script python server sementara
    cat <<EOF > $temp_py
import http.server
import cgi
import os
import sys

PORT = $port
UPLOAD_FILE = "/root/zivpn_restore.tar.gz"

class UploadHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(b'''
            <html>
            <body style="font-family:sans-serif; text-align:center; padding-top:50px; background:#f0f0f0;">
                <div style="background:white; padding:20px; border-radius:10px; width:300px; margin:auto; box-shadow:0 0 10px rgba(0,0,0,0.1);">
                    <h2 style="color:#333;">ZIVPN Restore</h2>
                    <p>Upload your <b>.tar.gz</b> backup file here.</p>
                    <form method="POST" enctype="multipart/form-data">
                        <input type="file" name="file" accept=".gz,.tar" required style="margin-bottom:15px;"><br>
                        <input type="submit" value="Upload & Restore" style="background:#007bff; color:white; border:none; padding:10px 20px; border-radius:5px; cursor:pointer;">
                    </form>
                </div>
            </body>
            </html>
        ''')

    def do_POST(self):
        try:
            ctype, pdict = cgi.parse_header(self.headers['content-type'])
            if ctype == 'multipart/form-data':
                pdict['boundary'] = bytes(pdict['boundary'], "utf-8")
                fields = cgi.parse_multipart(self.rfile, pdict)
                if 'file' in fields:
                    with open(UPLOAD_FILE, 'wb') as f:
                        f.write(fields['file'][0])
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'text/html')
                    self.end_headers()
                    self.wfile.write(b'<html><body style="text-align:center; font-family:sans-serif; padding-top:50px;"><h2>Upload Successful!</h2><p>Restoring data... You can close this page.</p></body></html>')
                    
                    # Exit server after successful upload
                    os._exit(0)
        except Exception as e:
            print(e)

if __name__ == '__main__':
    try:
        from http.server import HTTPServer
        server = HTTPServer(('', PORT), UploadHandler)
        print(f"Server started on port {PORT}")
        server.serve_forever()
    except:
        pass
EOF

    clear
    echo -e "${BLUE}=========================================${NC}"
    echo -e "       WAITING FOR FILE UPLOAD...        "
    echo -e "${BLUE}=========================================${NC}"
    echo -e "Open this link in your browser:"
    echo -e "${GREEN}http://$ip:$port${NC}"
    echo -e ""
    echo -e "${YELLOW}The server will stop automatically after upload.${NC}"
    echo -e "Press Ctrl+C to cancel."
    
    # Jalankan python server
    python3 $temp_py
    
    # Hapus file temp & tutup port
    rm -f $temp_py
    if command -v ufw &> /dev/null; then ufw delete allow $port/tcp >/dev/null 2>&1; fi
    if command -v iptables &> /dev/null; then iptables -D INPUT -p tcp --dport $port -j ACCEPT >/dev/null 2>&1; fi
    
    echo -e "\n${BLUE}Processing file...${NC}"
    
    # Proses Restore
    if [ -f "/root/zivpn_restore.tar.gz" ]; then
        # Hapus config lama dulu biar bersih
        rm -rf $DIR/*
        
        tar -xzf "/root/zivpn_restore.tar.gz" -C /
        rm -f "/root/zivpn_restore.tar.gz"
        
        # Fix permission & restart
        chmod -R 755 $DIR
        update_config
        
        echo -e "${GREEN}Restore Completed Successfully!${NC}"
        echo -e "${YELLOW}Your users and settings are back.${NC}"
    else
        echo -e "${RED}Restore failed. File not received.${NC}"
    fi
    
    read -p "Press Enter to return..."
}

install_api() {
    echo -e "${BLUE}Installing ZIVPN API Service...${NC}"
    
    # Install Python3 if missing
    if ! command -v python3 &> /dev/null; then
        apt-get install python3 -y
    fi
    
    local api_file="/etc/zivpn/api.py"
    local api_svc="/etc/systemd/system/zivpn-api.service"
    local api_key_file="/etc/zivpn/api_key"
    
    # Generate random key if not exists
    if [ ! -f "$api_key_file" ]; then
        tr -dc A-Za-z0-9 </dev/urandom | head -c 16 > "$api_key_file"
    fi
    local current_key=$(cat "$api_key_file")
    
    # Write API Script
    cat <<'EOF_PY' > "$api_file"
import http.server
import socketserver
import urllib.parse
import subprocess
import json
import re
import os

PORT = 9999
API_KEY_FILE = "/etc/zivpn/api_key"

def run_zivpn_cmd(args):
    # Add --api flag to bypass interactivity if supported, or rely on args presence
    cmd = ["/usr/local/bin/zivpn"] + args
    try:
        # Set environment var to tell zivpn script to be quiet/non-interactive
        env = os.environ.copy()
        env["ZIVPN_API_MODE"] = "1" 
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        return result.stdout
    except Exception as e:
        return str(e)

def parse_zivpn_output(output):
    data = {}
    # Regex patterns
    patterns = {
        "domain": r"Domain\s*:\s*(.+)", 
        "username": r"Username\s*:\s*(.+)",
        "password": r"Password\s*:\s*(.+)",
        "expired": r"Expires (On|At)\s*:\s*(.+)",
        "port": r"Port UDP\s*:\s*(\d+)"
    }
    
    # Clean ANSI codes
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)
    
    for key, pattern in patterns.items():
        match = re.search(pattern, clean_output)
        if match:
            data[key] = match.group(1).strip()
            
    return data

class MyRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed_path.query)
        
        # Auth Check
        auth = params.get("auth", [""])[0]
        real_key = "zivpn123"
        if os.path.exists(API_KEY_FILE):
            with open(API_KEY_FILE, "r") as f:
                real_key = f.read().strip()
            
        if auth != real_key:
            self.send_response(401)
            self.end_headers()
            self.wfile.write(json.dumps({"status": "error", "message": "Unauthorized"}).encode())
            return

        path = parsed_path.path
        response = {"status": "error", "message": "Invalid endpoint"}
        
        try:
            if path == "/add":
                user = params.get("user", [""])[0]
                days = params.get("days", ["30"])[0]
                if user:
                    raw = run_zivpn_cmd(["add", user, days])
                    data = parse_zivpn_output(raw)
                    if data.get("username"):
                        response = {"status": "success", "data": data}
                    else:
                        response = {"status": "error", "message": "Failed", "raw": raw}
                else:
                    response["message"] = "Missing user"

            elif path == "/trial":
                user = params.get("user", [""])[0]
                mins = params.get("mins", ["30"])[0]
                if user:
                    raw = run_zivpn_cmd(["trial", user, mins])
                    data = parse_zivpn_output(raw)
                    if data.get("username"):
                        response = {"status": "success", "data": data}
                    else:
                        response = {"status": "error", "message": "Failed", "raw": raw}
                else:
                    response["message"] = "Missing user"
            
            elif path == "/del":
                user = params.get("user", [""])[0]
                if user:
                    # Force delete logic must be handled in zivpn.sh
                    raw = run_zivpn_cmd(["del", user]) 
                    response = {"status": "success", "raw": raw}
                else:
                    response["message"] = "Missing user"
                    
        except Exception as e:
            response = {"status": "error", "message": str(e)}

        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(response).encode())

if __name__ == "__main__":
    os.chdir("/tmp") 
    with socketserver.TCPServer(("", PORT), MyRequestHandler) as httpd:
        print(f"ZIVPN API serving at port {PORT}")
        httpd.serve_forever()
EOF_PY

    # Create Service
    cat <<EOF > $api_svc
[Unit]
Description=ZIVPN API Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 $api_file
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable zivpn-api
    systemctl restart zivpn-api
    
    # Open Port
    if command -v ufw &> /dev/null; then ufw allow 9999/tcp; fi
    if command -v iptables &> /dev/null; then iptables -I INPUT -p tcp --dport 9999 -j ACCEPT; fi
    
    echo -e "${GREEN}API Service Installed!${NC}"
    echo -e "Port    : 9999"
    echo -e "Auth Key: ${YELLOW}$current_key${NC}"
    echo -e "Endpoints:"
    echo -e "  /add?user=...&days=...&auth=KEY"
    echo -e "  /trial?user=...&mins=...&auth=KEY"
    echo -e "  /del?user=...&auth=KEY"
    read -p "Press Enter to return..."
}

setup_cron() {
    echo -e "${GREEN}Setting up Cron jobs for Auto-Expired & Auto-Backup...${NC}"
    
    local script_path=$(readlink -f "$0")
    
    # Default backup settings
    local cron_time="0 5 * * *" # Jam 5 pagi default
    local backup_desc="05:00"
    
    # Load custom setting
    if [ -f "/etc/zivpn/backup_cron" ]; then
        cron_time=$(cat /etc/zivpn/backup_cron)
        if [ -f "/etc/zivpn/backup_desc" ]; then
            backup_desc=$(cat /etc/zivpn/backup_desc)
        fi
    fi

    # Clean old jobs
    crontab -l 2>/dev/null | grep -v "zivpn.sh" > /tmp/cron_zivpn
    
    # 1. Check expired every minute (for trial accuracy)
    echo "* * * * * $script_path xp" >> /tmp/cron_zivpn
    
    # 2. Auto backup based on custom config
    echo "$cron_time $script_path backup_auto" >> /tmp/cron_zivpn
    
    crontab /tmp/cron_zivpn
    rm -f /tmp/cron_zivpn
    
    echo -e "${GREEN}Cron jobs installed! (Auto Backup: $backup_desc)${NC}"
}

set_autobackup_time() {
    echo -e "${BLUE}Set Auto-Backup Interval${NC}"
    read -p "Enter Interval Hours (1-23): " interval
    
    if [[ ! "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 1 ] || [ "$interval" -gt 23 ]; then
        echo -e "${RED}Invalid interval! Please enter between 1 and 23.${NC}"
        return
    fi
    
    local new_cron="0 */$interval * * *"
    local new_desc="Every $interval hours"
    
    echo "$new_cron" > /etc/zivpn/backup_cron
    echo "$new_desc" > /etc/zivpn/backup_desc
    
    setup_cron
}

monitor_login() {
    echo -e "${YELLOW}Checking Active UDP Connections...${NC}"
    
    # Pastikan net-tools terinstall untuk netstat, atau gunakan ss
    if ! command -v netstat &> /dev/null; then
        apt-get install net-tools -y > /dev/null 2>&1
    fi

    echo "-------------------------------------------------------------"
    echo -e "Total Unique IPs Connected to ZIVPN (Port 5667)"
    echo "-------------------------------------------------------------"
    
    # Cek koneksi ke port 5667 (backend port zivpn)
    # Format netstat: Proto Recv-Q Send-Q Local Address Foreign Address State
    # Kita ambil Foreign Address (kolom 5), buang port, sort, uniq
    
    local count=$(netstat -nu | grep ":5667" | awk '{print $5}' | cut -d: -f1 | sort | uniq | wc -l)
    
    # Jika 0, coba cek menggunakan ss karena kadang netstat beda output
    if [ "$count" -eq 0 ]; then
        count=$(ss -nu state established '( sport = :5667 )' | grep -v "Recv-Q" | awk '{print $4}' | cut -d: -f1 | sort | uniq | wc -l)
    fi
    
    echo -e "Total Connected IPs : ${GREEN}$count${NC}"
    echo "-------------------------------------------------------------"
    
    # Tampilkan list IP jika ada
    if [ "$count" -gt 0 ]; then
        echo -e "List of Connected IPs:"
        netstat -nu | grep ":5667" | awk '{print $5}' | cut -d: -f1 | sort | uniq
    fi
    echo "-------------------------------------------------------------"
    read -p "Press Enter to return..."
}

# Fungsi khusus untuk cronjob (tanpa output berlebih)
check_expired_cron() {
    # Logika: Cek user expired, hapus dari DB, lalu update config
    local now=$(date +%s)
    local tmp_db="$USER_DB.tmp"
    local changed=0

    # Filter hanya user yang MASIH AKTIF (Expire > Now) ke file temp
    # User expired akan otomatis terbuang (terhapus)
    awk -v now="$now" -F: '$3 > now' "$USER_DB" > "$tmp_db"

    # Cek apakah ada perubahan jumlah baris (artinya ada user expired yg dihapus)
    local old_lines=$(wc -l < "$USER_DB")
    local new_lines=$(wc -l < "$tmp_db")

    if [ "$old_lines" -ne "$new_lines" ]; then
        mv "$tmp_db" "$USER_DB"
        # Jika ada yang dihapus, reload config & restart service
        update_config
    else
        rm -f "$tmp_db"
    fi
}

backup_auto_cron() {
    # Hanya backup jika config ada
    if [ -f "/etc/zivpn/telegram.conf" ]; then
        source "/etc/zivpn/telegram.conf"
        if [[ -n "$ZIVPN_TG_TOKEN" && -n "$ZIVPN_TG_CHATID" ]]; then
            local backup_file="/tmp/zivpn_backup_auto_$(date +%Y%m%d).tar.gz"
            tar -czf "$backup_file" "$DIR"
            curl -s -F chat_id="$ZIVPN_TG_CHATID" \
                 -F document=@"$backup_file" \
                 -F caption="ZIVPN Auto Backup $(date)" \
                 "https://api.telegram.org/bot$ZIVPN_TG_TOKEN/sendDocument" > /dev/null
            rm -f "$backup_file"
        fi
    fi
}
set_domain() {
    echo -e "${BLUE}Set Server Domain${NC}"
    echo -e "Current Domain: $(cat /etc/zivpn/domain 2>/dev/null || echo 'Not Set')"
    echo "---------------------------------------------------"
    read -p "Enter New Domain (e.g., vpn.myserver.com): " new_domain
    
    if [[ -z "$new_domain" ]]; then
        echo -e "${RED}Domain cannot be empty!${NC}"
        return
    fi
    
    echo "$new_domain" > /etc/zivpn/domain
    echo -e "${GREEN}Domain updated successfully to: $new_domain${NC}"
}

menu() {
    clear
    
    # --- Auto Update Check ---
    # Cek update hanya jika belum dicek dalam sesi ini (opsional, atau selalu cek)
    # Untuk kecepatan, kita set timeout pendek
    local REMOTE_URL="https://raw.githubusercontent.com/zidnyzd/linux/main/zivpn.sh"
    local LOCAL_FILE="/usr/local/bin/zivpn"
    
    # Cek koneksi & file size/hash header (cara cepat: cek header content-length atau download head)
    # Kita download file ke tmp untuk membandingkan
    # echo "Checking for updates..." # Debug
    wget -q --no-cache --timeout=3 --tries=1 "$REMOTE_URL" -O /tmp/zivpn-remote.sh
    
    if [ -s "/tmp/zivpn-remote.sh" ]; then
        # Bandingkan file lokal dan remote
        if ! cmp -s "$LOCAL_FILE" "/tmp/zivpn-remote.sh"; then
            echo -e "${YELLOW}New update available! Auto-updating...${NC}"
            cp /tmp/zivpn-remote.sh "$LOCAL_FILE"
            chmod +x "$LOCAL_FILE"
            rm -f /tmp/zivpn-remote.sh
            
            echo -e "${GREEN}Update installed. Restarting...${NC}"
            sleep 1
            exec "$LOCAL_FILE" menu
        fi
        rm -f /tmp/zivpn-remote.sh
    fi
    # -------------------------

    # Get System Info
    local os_name=$(cat /etc/os-release | grep -w PRETTY_NAME | cut -d= -f2 | tr -d '"')
    local public_ip=$(curl -s ifconfig.me)
    local domain=$(cat /etc/zivpn/domain 2>/dev/null || echo "$public_ip")
    local isp_info=$(curl -s http://ip-api.com/json/$public_ip?fields=isp,country)
    local isp=$(echo $isp_info | grep -Po '(?<="isp":")[^"]*')
    local country=$(echo $isp_info | grep -Po '(?<="country":")[^"]*')
    
    # Check Service Status
    local status_zivpn="${RED}OFF${NC}"
    if systemctl is-active --quiet zivpn; then
        status_zivpn="${GREEN}ON${NC}"
    fi
    
    # Get Active Users Count
    local user_stats=$(count_active_users)
    local active_count=$(echo "$user_stats" | cut -d: -f1)
    local expired_count=$(echo "$user_stats" | cut -d: -f2)
    local total_count=$(echo "$user_stats" | cut -d: -f3)

    echo -e "${BLUE}=========================================${NC}"
    echo -e "           ZIVPN MANAGER v2.3            "
    echo -e "${BLUE}=========================================${NC}"
    echo -e "OS        : $os_name"
    echo -e "Domain/IP : $domain"
    echo -e "Public IP : $public_ip"
    echo -e "ISP/Loc   : $isp, $country"
    echo -e "Status    : ZIVPN Service is $status_zivpn"
    echo -e "Accounts  : ${GREEN}$active_count Active${NC} / ${RED}$expired_count Expired${NC} / Total: $total_count"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "  Credits By: ZidStore (t.me/storezid2)  "
    echo -e "${BLUE}=========================================${NC}"
    echo -e "1.  Add User"
    echo -e "2.  Add Trial Account"
    echo -e "3.  Delete User"
    echo -e "4.  Renew User"
    echo -e "5.  List Users (Check)"
    echo -e "6.  Monitor Connections"
    echo -e "7.  Backup to Telegram"
    echo -e "8.  Restore Data"
    echo -e "9.  Install / Re-Install ZIVPN"
    echo -e "10. Uninstall ZIVPN"
    echo -e "11. Update Script"
    echo -e "12. Set Auto-Backup Time"
    echo -e "13. Set/Change Domain"
    echo -e "14. Install API Service"
    echo -e "15. Exit"
    echo -e "${BLUE}=========================================${NC}"
    read -p "Select Option: " opt
    case $opt in
        1) add_user ;;
        2) add_trial ;;
        3) del_user ;;
        4) renew_user ;;
        5) check_user ;;
        6) monitor_login ;;
        7) backup_tg ;;
        8) restore_menu ;;
        9) install_zivpn ;;
        10) uninstall_zivpn ;;
        11) update_script ;;
        12) set_autobackup_time ;;
        13) set_domain ;;
        14) install_api ;;
        15) exit 0 ;;
        *) echo "Invalid option"; sleep 1; menu ;;
    esac
}

# --- Entry Point ---
if [ $(id -u) -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Auto-Sync Local Edit to System Command
# Jika script ini BUKAN di lokasi sistem tapi lokasi sistem ada, maka update lokasi sistem
if [ "$0" != "/usr/local/bin/zivpn" ] && [ -f "/usr/local/bin/zivpn" ]; then
    # Hanya update jika file berbeda (cegah loop atau unnecessary write)
    if ! cmp -s "$0" "/usr/local/bin/zivpn"; then
        cp "$0" "/usr/local/bin/zivpn"
        chmod +x "/usr/local/bin/zivpn"
        # echo "System command 'zivpn' updated from local file."
    fi
fi

# CLI Argument Handling
case $1 in
    install) install_zivpn ;;
    uninstall) uninstall_zivpn ;;
    xp) check_expired_cron ;;
    backup_auto) backup_auto_cron ;;
    add) add_user "$2" "$3" "$4" ;;
    trial) add_trial "$2" "$3" ;;
    del) del_user "$2" ;;
    renew) renew_user "$2" "$3" ;;
    list|info) check_user ;;
    monitor) monitor_login ;;
    backup) backup_tg ;;
    restore) restore_menu ;;
    stats|count) 
        local user_stats=$(count_active_users)
        local active_count=$(echo "$user_stats" | cut -d: -f1)
        local expired_count=$(echo "$user_stats" | cut -d: -f2)
        local total_count=$(echo "$user_stats" | cut -d: -f3)
        echo -e "${BLUE}ZIVPN Account Statistics${NC}"
        echo -e "Total Accounts  : $total_count"
        echo -e "${GREEN}Active Accounts${NC} : $active_count"
        echo -e "${RED}Expired Accounts${NC}: $expired_count"
        ;;
    menu) menu ;;
    *) menu ;;
esac
