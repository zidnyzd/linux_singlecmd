#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if script is run as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root or with sudo${NC}"
        exit 1
    fi
}

# Function to display current swap status
show_swap_status() {
    echo -e "\n${YELLOW}Current Swap Status:${NC}"
    echo "----------------------------------------"
    free -h
    echo -e "\n${YELLOW}Current Swappiness Value:${NC}"
    echo "----------------------------------------"
    cat /proc/sys/vm/swappiness
}

# Function to adjust swappiness
adjust_swappiness() {
    local new_value=$1
    if [ -z "$new_value" ]; then
        echo -e "${YELLOW}Enter new swappiness value (1-100):${NC}"
        read new_value
    fi
    
    if ! [[ "$new_value" =~ ^[0-9]+$ ]] || [ "$new_value" -lt 1 ] || [ "$new_value" -gt 100 ]; then
        echo -e "${RED}Invalid value. Please enter a number between 1 and 100${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Setting swappiness to $new_value...${NC}"
    sysctl vm.swappiness=$new_value
    
    # Make it permanent
    if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
        echo "vm.swappiness=$new_value" >> /etc/sysctl.conf
    else
        sed -i "s/vm.swappiness=.*/vm.swappiness=$new_value/" /etc/sysctl.conf
    fi
    
    echo -e "${GREEN}Swappiness has been set to $new_value${NC}"
}

# Function to clear swap
clear_swap() {
    echo -e "${YELLOW}Clearing swap space...${NC}"
    swapoff -a
    swapon -a
    echo -e "${GREEN}Swap space has been cleared${NC}"
}

# Function to customize swap size
customize_swap() {
    echo -e "\n${YELLOW}Customizing Swap Size${NC}"
    echo "----------------------------------------"
    
    # Turn off all swap
    echo -e "${YELLOW}Turning off current swap...${NC}"
    swapoff -a
    
    # Ask for new swap size
    echo -e "${YELLOW}Enter new swap size (in GB, e.g., 2 for 2GB):${NC}"
    read swap_size
    
    if ! [[ "$swap_size" =~ ^[0-9]+$ ]] || [ "$swap_size" -lt 1 ]; then
        echo -e "${RED}Invalid size. Please enter a positive number${NC}"
        return 1
    fi
    
    # Remove old swap file if exists
    if [ -f /swapfile ]; then
        rm /swapfile
    fi
    
    # Create new swap file
    echo -e "${YELLOW}Creating new swap file of ${swap_size}GB...${NC}"
    fallocate -l ${swap_size}G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    
    # Enable new swap
    echo -e "${YELLOW}Enabling new swap...${NC}"
    swapon /swapfile
    
    # Make swap permanent
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile none swap sw 0 0" >> /etc/fstab
    else
        sed -i "s|/swapfile.*|/swapfile none swap sw 0 0|" /etc/fstab
    fi
    
    echo -e "${GREEN}Swap size has been set to ${swap_size}GB${NC}"
    show_swap_status
}

# Function to optimize system parameters
optimize_system() {
    echo -e "${YELLOW}Optimizing system parameters...${NC}"
    
    # Add or update parameters in sysctl.conf
    local params=(
        "vm.vfs_cache_pressure=50"
        "vm.dirty_ratio=10"
        "vm.dirty_background_ratio=5"
    )
    
    for param in "${params[@]}"; do
        if ! grep -q "${param%=*}" /etc/sysctl.conf; then
            echo "$param" >> /etc/sysctl.conf
        else
            sed -i "s/${param%=*}=.*/$param/" /etc/sysctl.conf
        fi
    done
    
    # Apply changes
    sysctl -p
    echo -e "${GREEN}System parameters have been optimized${NC}"
}

# Function to display menu
show_menu() {
    echo -e "\n${YELLOW}Swap Optimizer Menu${NC}"
    echo "----------------------------------------"
    echo "1. Show current swap status"
    echo "2. Adjust swappiness value"
    echo "3. Clear swap space"
    echo "4. Optimize system parameters"
    echo "5. Customize swap size"
    echo "6. Exit"
    echo "----------------------------------------"
    echo -n "Enter your choice (1-6): "
}

# Main script
check_root

while true; do
    show_menu
    read choice
    
    case $choice in
        1)
            show_swap_status
            ;;
        2)
            adjust_swappiness
            ;;
        3)
            clear_swap
            ;;
        4)
            optimize_system
            ;;
        5)
            customize_swap
            ;;
        6)
            echo -e "${GREEN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read
done 