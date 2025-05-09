#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to display header
print_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}${BOLD}                  Kernel Management Tool                    ${NC}${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}\n"
}

# Function to display error message
print_error() {
    echo -e "\n${RED}❌ Error: $1${NC}\n"
}

# Function to display success message
print_success() {
    echo -e "\n${GREEN}✅ Success: $1${NC}\n"
}

# Function to display info message
print_info() {
    echo -e "\n${YELLOW}ℹ️  Info: $1${NC}\n"
}

# Function to display system information
display_system_info() {
    echo -e "${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}System Information:${NC}"
    echo -e "${BLUE}│${NC} OS: $(lsb_release -d | cut -f2)"
    echo -e "${BLUE}│${NC} Architecture: $(uname -m)"
    echo -e "${BLUE}│${NC} Total Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${BLUE}└────────────────────────────────────────────────────────┘${NC}\n"
}

# Display header
print_header

# Display system information
display_system_info

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
    echo -e "${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${BOLD}Installed Kernels:${NC}"
    dpkg --list | grep 'linux-image' | grep -E 'generic|cloud' | awk '{print $2}' | while read -r kernel; do
        if [[ "$kernel" == *"$active_kernel"* ]]; then
            echo -e "${BLUE}│${NC} ${GREEN}✓ $kernel (Active)${NC}"
        else
            echo -e "${BLUE}│${NC} $kernel"
        fi
    done
    echo -e "${BLUE}└────────────────────────────────────────────────────────┘${NC}"
    exit 0
fi

# Display list of removable kernels
echo -e "\n${YELLOW}Available kernels for removal:${NC}"
echo -e "${BLUE}┌────────────────────────────────────────────────────────┐${NC}"
for i in "${!kernel_array[@]}"; do
    echo -e "${BLUE}│${NC} ${BOLD}$((i+1))${NC}. ${kernel_array[$i]}"
done
echo -e "${BLUE}└────────────────────────────────────────────────────────┘${NC}"

# Get user input
echo -e "\n${YELLOW}Please select a kernel to remove (or 'q' to quit):${NC}"
read -p "> " selected

# Handle quit option
if [[ "$selected" == "q" || "$selected" == "Q" ]]; then
    print_info "Operation cancelled by user."
    exit 0
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
            exit 1
        fi
    else
        print_info "Operation cancelled by user."
        exit 0
    fi
else
    print_error "Invalid input. Please enter a valid number."
    exit 1
fi
