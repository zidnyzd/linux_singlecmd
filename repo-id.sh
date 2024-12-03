#!/bin/bash

# Fungsi untuk backup dan mengganti repository sources
replace_repo() {
    DISTRO=$1
    CODENAME=$2

    # Backup file sources.list
    echo "Membackup file sources.list ke /etc/apt/sources.list.bak"
    cp /etc/apt/sources.list /etc/apt/sources.list.bak

    # Mengatur repository default sesuai distribusi dan codename
    echo "Mengganti repository default untuk $DISTRO $CODENAME"
    echo "deb http://kartolo.sby.datautama.net.id/$DISTRO/ $CODENAME main contrib non-free" > /etc/apt/sources.list
    echo "deb http://kartolo.sby.datautama.net.id/$DISTRO/ $CODENAME-updates main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://kartolo.sby.datautama.net.id/$DISTRO-security/ $CODENAME/updates main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://kartolo.sby.datautama.net.id/$DISTRO/ $CODENAME-backports main contrib non-free" >> /etc/apt/sources.list
    echo "deb http://kartolo.sby.datautama.net.id/$DISTRO/ $CODENAME-proposed main contrib non-free" >> /etc/apt/sources.list
}

# Fungsi untuk menghapus sumber dari /etc/apt/sources.list.d
remove_sources_d() {
    echo "Menghapus repository di /etc/apt/sources.list.d/"
    rm -f /etc/apt/sources.list.d/*
}

# Memeriksa distribusi dan mengganti repo sesuai
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        debian)
            if [ "$VERSION_ID" == "12" ]; then
                replace_repo "debian" "bookworm"
                remove_sources_d
            else
                echo "Distribusi Debian tidak dikenali atau bukan Debian 12."
            fi
            ;;
        ubuntu)
            case "$VERSION_ID" in
                "20.04")
                    replace_repo "ubuntu" "focal"
                    remove_sources_d
                    ;;
                "22.04")
                    replace_repo "ubuntu" "jammy"
                    remove_sources_d
                    ;;
                "24.04")
                    replace_repo "ubuntu" "noble"
                    remove_sources_d
                    ;;
                *)
                    echo "Distribusi Ubuntu tidak dikenali atau tidak didukung."
                    ;;
            esac
            ;;
        *)
            echo "Distribusi tidak dikenali atau tidak didukung."
            ;;
    esac
else
    echo "File /etc/os-release tidak ditemukan. Pastikan skrip dijalankan di sistem berbasis Debian/Ubuntu."
fi

# Update apt untuk menerapkan perubahan
echo "Melakukan update apt setelah mengganti repository..."
apt update && apt upgrade -y
