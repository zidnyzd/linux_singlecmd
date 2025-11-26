#!/bin/bash

# Global Variables
DIR="/etc/zivpn"
CONFIG_FILE="$DIR/config.json"
USER_DB="$DIR/passwd"
BIN="/usr/local/bin/zivpn"
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

    # Gunakan SED untuk mengganti baris "config": [...]
    # Asumsi format file asli: "config": [ ... ]
    # Kita cari baris yang mengandung "config": dan ganti seluruhnya
    sed -i "s/\"config\":.*/$new_config_line/g" "$CONFIG_FILE"
    
    # Restart service
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
    rm -f $BIN
    rm -rf $DIR
    
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
    local days=$2
    
    # Jika input kosong, minta input interaktif
    if [[ -z "$user" ]]; then
        read -p "Username : " user
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

    # Set password = user
    local pass="$user"
    local exp_date=$(date -d "+$days days" +%s)

    # Simpan ke DB
    echo "$user:$pass:$exp_date" >> "$USER_DB"
    
    # Update Config ZIVPN
    update_config
    
    # Get info for display
    local domain=$(cat /etc/zivpn/domain 2>/dev/null || curl -s ifconfig.me)
    local exp_display=$(date -d "@$exp_date" "+%d-%m-%Y")
    
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

del_user() {
    local user=$1
    
    # Jika argumen kosong, tampilkan menu pilih user
    if [[ -z "$user" ]]; then
        echo -e "${YELLOW}Select User to Delete:${NC}"
        echo "--------------------------------------------------------------"
        printf "%-5s %-15s %-30s\n" "No" "Username" "Expired"
        echo "--------------------------------------------------------------"
        
        local i=1
        local users=()
        local now=$(date +%s)
        while IFS=':' read -r u p e; do
            if [[ -z "$u" ]]; then continue; fi
            if [[ -z "$e" || ! "$e" =~ ^[0-9]+$ ]]; then e=0; fi
            
            local exp_readable=$(date -d "@$e" "+%d-%m-%Y")
            local diff=$((e - now))
            local days_left=$((diff / 86400))
            if [[ "$e" -lt "$now" ]]; then days_left=0; fi
            
            local exp_display="$exp_readable ($days_left Days)"
            
            printf "%-5s %-15s %-30s\n" "$i" "$u" "$exp_display"
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
        printf "%-5s %-15s %-30s\n" "No" "Username" "Expired"
        echo "--------------------------------------------------------------"
        
        local i=1
        local users=()
        local now=$(date +%s)
        while IFS=':' read -r u p e; do
            if [[ -z "$u" ]]; then continue; fi
            if [[ -z "$e" || ! "$e" =~ ^[0-9]+$ ]]; then e=0; fi
            
            local exp_readable=$(date -d "@$e" "+%d-%m-%Y")
            local diff=$((e - now))
            local days_left=$((diff / 86400))
            if [[ "$e" -lt "$now" ]]; then days_left=0; fi
            
            local exp_display="$exp_readable ($days_left Days)"
            
            printf "%-5s %-15s %-30s\n" "$i" "$u" "$exp_display"
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
    
    # Validasi jika user ditemukan tapi corrupt (timestamp kosong)
    if [[ -z "$current_exp" ]]; then
        echo -e "${YELLOW}Warning: User data corrupted (no expiry date). Resetting expiry.${NC}"
        current_exp=0
    fi

    local now=$(date +%s)
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
    echo -e "${GREEN}User $user renewed until $(date -d @$new_exp)!${NC}"
}

check_user() {
    echo -e "${YELLOW}Checking User Database...${NC}"
    echo "------------------------------------------------------------------------------"
    printf "%-15s %-15s %-30s %b\n" "Username" "Password" "Expires On" "Status"
    echo "------------------------------------------------------------------------------"
    
    local now=$(date +%s)
    local l_user l_pass l_exp
    while IFS=':' read -r l_user l_pass l_exp; do
        if [[ -z "$l_user" ]]; then continue; fi
        
        # Handle corrupt date
        if [[ -z "$l_exp" || ! "$l_exp" =~ ^[0-9]+$ ]]; then
            l_exp=0
        fi
        
        local exp_readable=$(date -d "@$l_exp" "+%d-%m-%Y")
        local diff=$((l_exp - now))
        local days_left=$((diff / 86400))
        
        local status="${GREEN}Active${NC}"
        if [[ "$l_exp" -lt "$now" ]]; then
            status="${RED}Expired${NC}"
            days_left=0
        fi
        
        # Format: DD-MM-YYYY (X Days)
        local exp_display="$exp_readable ($days_left Days)"
        
        printf "%-15s %-15s %-30s %b\n" "$l_user" "$l_pass" "$exp_display" "$status"
    done < "$USER_DB"
    echo "------------------------------------------------------------------------------"
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
    
    # 1. Check expired every hour
    echo "0 * * * * $script_path xp" >> /tmp/cron_zivpn
    
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
    update_config
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

    echo -e "${BLUE}=========================================${NC}"
    echo -e "           ZIVPN MANAGER v2.3            "
    echo -e "${BLUE}=========================================${NC}"
    echo -e "OS        : $os_name"
    echo -e "Domain/IP : $domain"
    echo -e "Public IP : $public_ip"
    echo -e "ISP/Loc   : $isp, $country"
    echo -e "Status    : ZIVPN Service is $status_zivpn"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "  Credits By: ZidStore (t.me/storezid2)  "
    echo -e "${BLUE}=========================================${NC}"
    echo -e "1.  Add User"
    echo -e "2.  Delete User"
    echo -e "3.  Renew User"
    echo -e "4.  List Users (Check)"
    echo -e "5.  Monitor Connections"
    echo -e "6.  Backup to Telegram"
    echo -e "7.  Install / Re-Install ZIVPN"
    echo -e "8.  Uninstall ZIVPN"
    echo -e "9.  Update Script"
    echo -e "10. Set Auto-Backup Time"
    echo -e "11. Set/Change Domain"
    echo -e "12. Exit"
    echo -e "${BLUE}=========================================${NC}"
    read -p "Select Option: " opt
    case $opt in
        1) add_user ;;
        2) del_user ;;
        3) renew_user ;;
        4) check_user ;;
        5) monitor_login ;;
        6) backup_tg ;;
        7) install_zivpn ;;
        8) uninstall_zivpn ;;
        9) update_script ;;
        10) set_autobackup_time ;;
        11) set_domain ;;
        12) exit 0 ;;
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
    add) add_user "$2" "$3" ;;
    del) del_user "$2" ;;
    renew) renew_user "$2" "$3" ;;
    list|info) check_user ;;
    monitor) monitor_login ;;
    backup) backup_tg ;;
    menu) menu ;;
    *) menu ;;
esac
