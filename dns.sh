#!/bin/bash

# Script: DNS Configuration Tool for VPS
# Description: Set custom DNS with beautiful UI and default options (Google, Cloudflare, PAN-IX/DPI)
# Author: Assistant
# Date: 2026

# === COLOR PALETTE ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# === LOGGING FUNCTION ===
log_info() {
  echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# === ASCII HEADER ===
show_header() {
  clear
  echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║                  ${GREEN}🖥️  DNS Configuration Tool${BLUE}                    ║${NC}"
  echo -e "${BOLD}${BLUE}║              ${CYAN}Custom DNS Setup for VPS${BLUE}                      ║${NC}"
  echo -e "${BOLD}${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}1. Google DNS (8.8.8.8, 8.8.4.4)                                 ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}2. Cloudflare DNS (1.1.1.1, 1.0.0.1)                            ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}3. PAN-IX/DPI DNS (202.46.46.2, 202.46.46.3)                    ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}4. OpenDNS (208.67.222.222, 208.67.220.220)                   ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}5. Custom DNS (Enter manually)                                  ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}6. Reset to Default (Remove custom DNS)                         ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}7. View Current DNS Settings                                    ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}0. Exit                                                         ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}╠══════════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}${BLUE}║  ${WHITE}Select an option (0-7):                                         ${BLUE}║${NC}"
  echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

# === DEFAULT DNS SERVERS ===
declare -A DNS_SERVERS
DNS_SERVERS["google"]="8.8.8.8,8.8.4.4"
DNS_SERVERS["cloudflare"]="1.1.1.1,1.0.0.1"
DNS_SERVERS["pdn"]="202.46.46.2,202.46.46.3"
DNS_SERVERS["opendns"]="208.67.222.222,208.67.220.220"
DNS_NAMES["google"]="Google DNS"
DNS_NAMES["cloudflare"]="Cloudflare DNS"
DNS_NAMES["pdn"]="PAN-IX/DPI DNS"
DNS_NAMES["opendns"]="OpenDNS"

# === BACKUP FUNCTION ===
backup_resolv() {
  if [ ! -f /etc/resolv.conf.bak ]; then
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
  fi
}

# === SET DNS FUNCTION ===
set_dns() {
  local nameservers="$1"
  local dns_name="$2"
  
  log_info "Backing up current DNS configuration..."
  backup_resolv
  
  # Remove immutable attribute if set
  chattr -i /etc/resolv.conf 2>/dev/null || true
  
  # Check if systemd-resolved is active
  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    log_info "systemd-resolved is active. Configuring it..."
    sed -i 's/^#*DNS=.*/DNS='"$nameservers"'/' /etc/systemd/resolved.conf
    sed -i 's/^#*FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
  else
    log_info "Configuring static /etc/resolv.conf..."
    cat > /etc/resolv.conf <<EOF
# Custom DNS Configuration
# Set by DNS Configuration Tool
# Provider: $dns_name
# Nameservers: $nameservers
# Date: $(date '+%Y-%m-%d %H:%M:%S')

nameserver $(echo "$nameservers" | cut -d',' -f1)
nameserver $(echo "$nameservers" | cut -d',' -f2)
EOF
  fi
  
  # Set immutable to protect from changes
  chattr +i /etc/resolv.conf 2>/dev/null || true
  
  log_success "DNS has been set to $dns_name!"
  log_info "Nameservers: $nameservers"
}

# === CUSTOM DNS INPUT ===
input_custom_dns() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Custom DNS Configuration${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  echo -e "${YELLOW}Enter Primary DNS (e.g., 8.8.8.8):${NC}"
  read -r primary_dns
  primary_dns=$(echo "$primary_dns" | xargs) # Trim whitespace
  
  # Validate primary DNS
  if ! [[ "$primary_dns" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid primary DNS format. Using default 1.1.1.1"
    primary_dns="1.1.1.1"
  fi
  
  echo ""
  echo -e "${YELLOW}Enter Secondary DNS (e.g., 8.8.4.4):${NC}"
  read -r secondary_dns
  secondary_dns=$(echo "$secondary_dns" | xargs) # Trim whitespace
  
  # Validate secondary DNS
  if ! [[ "$secondary_dns" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid secondary DNS format. Using default 8.8.8.8"
    secondary_dns="8.8.8.8"
  fi
  
  local custom_nameservers="$primary_dns,$secondary_dns"
  set_dns "$custom_nameservers" "Custom DNS ($primary_dns, $secondary_dns)"
}

# === RESET DNS FUNCTION ===
reset_dns() {
  log_info "Resetting DNS to default configuration..."
  backup_resolv
  
  chattr -i /etc/resolv.conf 2>/dev/null || true
  
  if [ -f /etc/resolv.conf.bak ]; then
    cp /etc/resolv.conf.bak /etc/resolv.conf
    log_success "DNS restored from backup!"
  else
    # Fallback: set to Google DNS
    set_dns "8.8.8.8,8.8.4.4" "Default (Google DNS)"
  fi
  
  # Remove immutable attribute
  chattr -i /etc/resolv.conf 2>/dev/null || true
}

# === VIEW CURRENT DNS ===
view_dns() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Current DNS Configuration${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  if [ -L /etc/resolv.conf ]; then
    echo -e "${YELLOW}Status: ${NC}Symbolic link to $(readlink /etc/resolv.conf)"
  else
    echo -e "${YELLOW}Status: ${NC}Static file"
  fi
  
  echo ""
  echo -e "${BOLD}Current /etc/resolv.conf:${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  cat /etc/resolv.conf 2>/dev/null || echo "(No resolv.conf found)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Check systemd-resolved status
  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo -e "${GREEN}✓ systemd-resolved is active${NC}"
    echo -e "${YELLOW}Systemd-resolved DNS:${NC} $(systemd-resolve --status 2>/dev/null | grep -A1 "DNS Servers" | tail -n +2 | tr '\n' ', ')"
  else
    echo -e "${RED}✗ systemd-resolved is not active${NC}"
  fi
}

# === MAIN MENU ===
show_header
read -rp "Masukkan pilihan Anda: " choice

case "$choice" in
  1)
    log_info "Setting Google DNS..."
    set_dns "${DNS_SERVERS[google]}" "${DNS_NAMES[google]}"
    ;;
  2)
    log_info "Setting Cloudflare DNS..."
    set_dns "${DNS_SERVERS[cloudflare]}" "${DNS_NAMES[cloudflare]}"
    ;;
  3)
    log_info "Setting PAN-IX/DPI DNS..."
    set_dns "${DNS_SERVERS[pdn]}" "${DNS_NAMES[pdn]}"
    ;;
  4)
    log_info "Setting OpenDNS..."
    set_dns "${DNS_SERVERS[opendns]}" "${DNS_NAMES[opendns]}"
    ;;
  5)
    input_custom_dns
    ;;
  6)
    reset_dns
    ;;
  7)
    view_dns
    ;;
  0)
    echo -e "${GREEN}👋Exiting...${NC}"
    exit 0
    ;;
  *)
    log_error "Pilihan tidak valid. Silakan pilih 0-7."
    exit 1
    ;;
esac

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -rn 1 -p "${YELLOW}Press any key to continue...${NC}"
echo ""
