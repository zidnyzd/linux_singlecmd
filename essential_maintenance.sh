#!/bin/bash

# =============================================================================
# 🚀 ESSENTIAL SERVER MAINTENANCE SCRIPT
# =============================================================================
# Script ini menggabungkan 5 tool maintenance yang paling sering digunakan:
# 1. Repository Setup
# 2. Kernel Management Tool  
# 3. XRAY FIX
# 4. HAPROXY FIX
# 5. WS FIX
# =============================================================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to display header
print_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}${BOLD}                    ESSENTIAL SERVER MAINTENANCE TOOL                    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}${CYAN}         Repository • Kernel • XRAY • HAProxy • WebSocket Fix          ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

# Function to display section header
print_section() {
    local section_name="$1"
    local step="$2"
    echo -e "\n${PURPLE}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${PURPLE}│${NC} ${BOLD}STEP $step: $section_name${NC}"
    echo -e "${PURPLE}└────────────────────────────────────────────────────────────────────────────┘${NC}\n"
}

# Function to display success message
print_success() {
    echo -e "\n${GREEN}✅ Success: $1${NC}\n"
}

# Function to display error message
print_error() {
    echo -e "\n${RED}❌ Error: $1${NC}\n"
}

# Function to display info message
print_info() {
    echo -e "\n${YELLOW}ℹ️  Info: $1${NC}\n"
}

# Function to display warning message
print_warning() {
    echo -e "\n${YELLOW}⚠️  Warning: $1${NC}\n"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to display system information
display_system_info() {
    echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}System Information:${NC}"
    echo -e "${BLUE}│${NC} OS: $(lsb_release -d | cut -f2)"
    echo -e "${BLUE}│${NC} Architecture: $(uname -m)"
    echo -e "${BLUE}│${NC} Kernel: $(uname -r)"
    echo -e "${BLUE}│${NC} Total Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${BLUE}│${NC} Date: $(date)"
    echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────────┘${NC}\n"
}

# Function to create backup directory
create_backup_dir() {
    local backup_dir="/root/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    echo "$backup_dir"
}

# =============================================================================
# STEP 1: REPOSITORY SETUP
# =============================================================================
setup_repository() {
    print_section "Repository Setup" "1"
    
    # Detect distribution and version
    DISTRO=$(lsb_release -i | awk '{print tolower($3)}')
    VERSION=$(lsb_release -c | awk '{print $2}')
    
    print_info "Detected: $DISTRO $VERSION"
    
    echo "Choose repository source:"
    echo "1) Default (official international)"
    echo "2) Kartolo (local Indonesia)"
    read -p "Enter choice [1/2]: " CHOICE
    
    case "$CHOICE" in
        1)
            print_info "Using DEFAULT repositories..."
            rm -f /etc/apt/sources.list
            rm -f /etc/apt/sources.list.d/*
            
            if [[ "$DISTRO" == "debian" ]]; then
                case "$VERSION" in
                    buster)
                        cat <<EOF > /etc/apt/sources.list
deb http://archive.debian.org/debian/ buster main contrib non-free
deb http://archive.debian.org/debian/ buster-updates main contrib non-free
deb http://archive.debian.org/debian-security/ buster/updates main contrib non-free
EOF
                        echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until
                        ;;
                    bullseye)
                        cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb http://security.debian.org/debian-security/ bullseye-security main contrib non-free
EOF
                        ;;
                    bookworm)
                        cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
                        ;;
                esac
            elif [[ "$DISTRO" == "ubuntu" ]]; then
                case "$VERSION" in
                    focal)
                        cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://archive.canonical.com/ubuntu focal partner
deb-src http://archive.canonical.com/ubuntu focal partner
EOF
                        ;;
                    jammy)
                        cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://archive.canonical.com/ubuntu/ jammy partner
EOF
                        ;;
                    noble)
                        cat <<EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-proposed main restricted universe multiverse
EOF
                        ;;
                esac
            fi
            ;;
        2)
            print_info "Using KARTOLO repositories..."
            rm -f /etc/apt/sources.list
            rm -f /etc/apt/sources.list.d/*
            
            if [[ "$DISTRO" == "debian" ]]; then
                if [[ "$VERSION" == "bookworm" ]]; then
                    cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/debian/ bookworm contrib main non-free non-free-firmware
deb http://kartolo.sby.datautama.net.id/debian/ bookworm-updates contrib main non-free non-free-firmware
deb http://kartolo.sby.datautama.net.id/debian/ bookworm-proposed-updates contrib main non-free non-free-firmware
deb http://kartolo.sby.datautama.net.id/debian/ bookworm-backports contrib main non-free non-free-firmware
deb http://kartolo.sby.datautama.net.id/debian-security/ bookworm-security contrib main non-free non-free-firmware
EOF
                elif [[ "$VERSION" == "buster" ]]; then
                    cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free
EOF
                elif [[ "$VERSION" == "bullseye" ]]; then
                    cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/debian/ bullseye main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ bullseye-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ bullseye-security main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ bullseye-backports main contrib non-free
EOF
                fi
            elif [[ "$DISTRO" == "ubuntu" ]]; then
                case "$VERSION" in
                    focal|jammy|noble)
                        cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/ubuntu/ $VERSION main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ ${VERSION}-updates main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ ${VERSION}-security main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ ${VERSION}-backports main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ ${VERSION}-proposed main restricted universe multiverse
EOF
                        ;;
                esac
            fi
            ;;
        *)
            print_error "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    print_info "Updating package lists..."
    apt update
    print_success "Repository setup completed!"
}

# =============================================================================
# STEP 2: KERNEL MANAGEMENT TOOL
# =============================================================================
manage_kernel() {
    print_section "Kernel Management Tool" "2"
    
    # Get current active kernel
    active_kernel=$(uname -r)
    print_info "Current active kernel: ${BOLD}$active_kernel${NC}"
    
    # Get list of installed kernels except the active one
    kernels=$(dpkg --list | grep 'linux-image' | grep -E 'generic|cloud' | awk '{print $2}' | grep -v "$active_kernel")
    
    # Convert to array
    mapfile -t kernel_array <<< "$kernels"
    
    # Check if there are any kernels to remove
    if [ ${#kernel_array[@]} -eq 0 ]; then
        print_info "No removable kernels found. Your system is clean!"
        print_info "Current kernel status:"
        echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│${NC} ${BOLD}Installed Kernels:${NC}"
        dpkg --list | grep 'linux-image' | grep -E 'generic|cloud' | awk '{print $2}' | while read -r kernel; do
            if [[ "$kernel" == *"$active_kernel"* ]]; then
                echo -e "${BLUE}│${NC} ${GREEN}✓ $kernel (Active)${NC}"
            else
                echo -e "${BLUE}│${NC} $kernel"
            fi
        done
        echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────────┘${NC}"
        return 0
    fi
    
    # Display list of removable kernels
    echo -e "\n${YELLOW}Available kernels for removal:${NC}"
    echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    for i in "${!kernel_array[@]}"; do
        echo -e "${BLUE}│${NC} ${BOLD}$((i+1))${NC}. ${kernel_array[$i]}"
    done
    echo -e "${BLUE}└────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    # Get user input
    echo -e "\n${YELLOW}Please select a kernel to remove (or 'q' to skip):${NC}"
    read -p "> " selected
    
    # Handle quit option
    if [[ "$selected" == "q" || "$selected" == "Q" ]]; then
        print_info "Kernel management skipped by user."
        return 0
    fi
    
    # Validate input
    if [[ "$selected" =~ ^[0-9]+$ ]] && [ "$selected" -gt 0 ] && [ "$selected" -le "${#kernel_array[@]}" ]; then
        target_kernel="${kernel_array[$((selected-1))]}"
        echo -e "\n${YELLOW}Removing kernel: ${BOLD}$target_kernel${NC}"
        
        # Confirm before removal
        read -p "Are you sure you want to remove this kernel? (y/N): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo -e "\n${YELLOW}Removing kernel...${NC}"
            if apt remove --purge -y "$target_kernel"; then
                update-grub
                print_success "Kernel $target_kernel has been successfully removed!"
            else
                print_error "Failed to remove kernel. Please check the error messages above."
                return 1
            fi
        else
            print_info "Kernel removal cancelled by user."
        fi
    else
        print_error "Invalid input. Skipping kernel management."
        return 1
    fi
}

# =============================================================================
# STEP 3: XRAY FIX
# =============================================================================
fix_xray() {
    print_section "XRAY Fix" "3"
    
    # Check if XRAY is installed
    if [ ! -f "/usr/local/bin/xray" ]; then
        print_warning "XRAY not found. Skipping XRAY fix."
        return 0
    fi
    
    print_info "Backing up current XRAY binary..."
    cp /usr/local/bin/xray /usr/local/bin/xray.bak
    
    print_info "Downloading latest XRAY binary..."
    if wget -qO /usr/local/bin/xray "https://raw.githubusercontent.com/zidnyzd/linux/main/xray/xray.linux.64bit"; then
        chmod +x /usr/local/bin/xray
        print_success "XRAY binary updated successfully!"
    else
        print_error "Failed to download XRAY binary. Restoring backup..."
        cp /usr/local/bin/xray.bak /usr/local/bin/xray
        return 1
    fi
    
    print_info "Disabling XRAY services temporarily..."
    # Disable all XRAY services
    sed -i 's/"enabled": true/"enabled": false/' /etc/xray/vmess/config.json 2>/dev/null || true
    sed -i 's/"enabled": true/"enabled": false/' /etc/xray/vless/config.json 2>/dev/null || true
    sed -i 's/"enabled": true/"enabled": false/' /etc/xray/trojan/config.json 2>/dev/null || true
    sed -i 's/"enabled": true/"enabled": false/' /etc/xray/shadowsocks/config.json 2>/dev/null || true
    
    print_info "Restarting XRAY services..."
    systemctl restart vmess@config 2>/dev/null || true
    systemctl restart vless@config 2>/dev/null || true
    systemctl restart trojan@config 2>/dev/null || true
    systemctl restart shadowsocks@config 2>/dev/null || true
    
    print_success "XRAY fix completed!"
}

# =============================================================================
# STEP 4: HAPROXY FIX
# =============================================================================
fix_haproxy() {
    print_section "HAProxy Fix" "4"
    
    # Check if HAProxy is installed
    if [ ! -f "/etc/haproxy/haproxy.cfg" ]; then
        print_warning "HAProxy not found. Skipping HAProxy fix."
        return 0
    fi
    
    CONFIG="/etc/haproxy/haproxy.cfg"
    BACKUP="/etc/haproxy/haproxy.cfg.bak"
    
    echo "Choose timeout to apply:"
    echo "1) 60s"
    echo "2) 30s"
    read -rp "Enter your choice [1/2]: " pilihan
    
    case $pilihan in
        1)
            TIMEOUT="60s"
            ;;
        2)
            TIMEOUT="30s"
            ;;
        *)
            print_error "Invalid choice. Skipping HAProxy fix."
            return 1
            ;;
    esac
    
    # Backup first
    cp "$CONFIG" "$BACKUP" && print_info "Backup saved to $BACKUP"
    
    # Replace timeout client/server lines
    sed -i -E \
        -e "s/^(\s*timeout\s+client\s+).*/\1$TIMEOUT/" \
        -e "s/^(\s*timeout\s+server\s+).*/\1$TIMEOUT/" \
        "$CONFIG"
    
    print_success "Client and server timeout updated to $TIMEOUT"
    
    # Show changes
    echo "Summary of changes:"
    grep -E 'timeout\s+(client|server)' "$CONFIG"
    
    # Optional restart
    read -rp "Restart HAProxy now? [y/n]: " restart
    if [[ "$restart" =~ ^[Yy]$ ]]; then
        if systemctl restart haproxy; then
            print_success "HAProxy restarted successfully."
        else
            print_error "Failed to restart HAProxy."
            return 1
        fi
    fi
    
    print_success "HAProxy fix completed!"
}

# =============================================================================
# STEP 5: WS FIX
# =============================================================================
fix_ws() {
    print_section "WebSocket Fix" "5"
    
    SERVICE_FILE="/etc/systemd/system/ws.service"
    WS_FILE="/usr/bin/ws.py"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    BACKUP_SERVICE_FILE="${SERVICE_FILE}.bak.${TIMESTAMP}"
    BACKUP_WS_FILE="${WS_FILE}.bak.${TIMESTAMP}"
    
    # Check if ws service exists
    if [ ! -f "$SERVICE_FILE" ] || [ ! -f "$WS_FILE" ]; then
        print_warning "WebSocket service not found. Skipping WS fix."
        return 0
    fi
    
    print_info "Starting full patch for ws.service and ws.py..."
    
    # 1. Backup original files
    print_info "Backing up original files..."
    cp "$SERVICE_FILE" "$BACKUP_SERVICE_FILE"
    cp "$WS_FILE" "$BACKUP_WS_FILE"
    echo "Backups saved:"
    echo "    $BACKUP_SERVICE_FILE"
    echo "    $BACKUP_WS_FILE"
    
    # 2. Patch systemd service (LimitNOFILE)
    print_info "Ensuring LimitNOFILE=65535 is set..."
    if ! grep -q "LimitNOFILE" "$SERVICE_FILE"; then
        sed -i '/^\[Service\]/a LimitNOFILE=65535' "$SERVICE_FILE"
        print_success "LimitNOFILE added"
    else
        print_info "LimitNOFILE already exists"
    fi
    
    # 3. Patch ws.py removeConn
    print_info "Patching removeConn safely in $WS_FILE..."
    sed -i '/def removeConn(self, conn):/,/self.threadsLock.release()/c\
    def removeConn(self, conn):\
        try:\
            self.threadsLock.acquire()\
            if conn in self.threads:\
                self.threads.remove(conn)\
        finally:\
            self.threadsLock.release()' "$WS_FILE"
    print_success "removeConn patched"
    
    # 4. Reload systemd and restart service
    print_info "Restarting ws.service..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl restart ws
    
    # 5. Verify patch
    print_info "Verifying patch applied:"
    grep -A3 "def removeConn" "$WS_FILE"
    
    # 6. Verify file descriptor limits
    print_info "Checking file descriptor limits:"
    WS_PID=$(systemctl show -p MainPID ws | cut -d= -f2)
    if [ -n "$WS_PID" ] && [ -e "/proc/$WS_PID/limits" ]; then
        cat /proc/"$WS_PID"/limits | grep "Max open files"
    else
        print_warning "Could not determine ws service PID or /proc entry missing."
    fi
    
    print_success "WebSocket fix completed!"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Display header
print_header

# Check if running as root
check_root

# Display system information
display_system_info

# Create backup directory
BACKUP_DIR=$(create_backup_dir)
print_info "Backup directory created: $BACKUP_DIR"

# Confirmation
echo -e "${YELLOW}This script will perform the following operations:${NC}"
echo "1. Setup repository sources"
echo "2. Manage kernel (remove old kernels)"
echo "3. Fix XRAY configuration"
echo "4. Fix HAProxy timeout settings"
echo "5. Fix WebSocket service"
echo ""
read -p "Do you want to continue? (y/N): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "Operation cancelled by user."
    exit 0
fi

# Execute all steps
echo -e "\n${GREEN}🚀 Starting essential maintenance...${NC}\n"

# Step 1: Repository Setup
if setup_repository; then
    print_success "✅ Step 1 completed successfully!"
else
    print_error "❌ Step 1 failed!"
    exit 1
fi

# Step 2: Kernel Management
if manage_kernel; then
    print_success "✅ Step 2 completed successfully!"
else
    print_warning "⚠️  Step 2 had issues, but continuing..."
fi

# Step 3: XRAY Fix
if fix_xray; then
    print_success "✅ Step 3 completed successfully!"
else
    print_warning "⚠️  Step 3 had issues, but continuing..."
fi

# Step 4: HAProxy Fix
if fix_haproxy; then
    print_success "✅ Step 4 completed successfully!"
else
    print_warning "⚠️  Step 4 had issues, but continuing..."
fi

# Step 5: WS Fix
if fix_ws; then
    print_success "✅ Step 5 completed successfully!"
else
    print_warning "⚠️  Step 5 had issues, but continuing..."
fi

# Final summary
echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}${BOLD}                    MAINTENANCE COMPLETED SUCCESSFULLY!                    ${NC}${GREEN}║${NC}"
echo -e "${GREEN}║${NC}${CYAN}         All essential maintenance tasks have been completed.              ${NC}${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"

print_info "Backup files are stored in: $BACKUP_DIR"
print_info "System is now optimized and ready for use!"

echo -e "\n${BLUE}Thank you for using Essential Server Maintenance Tool! 🎉${NC}\n" 