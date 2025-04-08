#!/bin/bash

# Fungsi untuk menulis repo baru sesuai distribusi
write_repos() {
    DISTRO=$1
    VERSION=$2

    # Hapus repositori lama
    echo "Menghapus repositori lama..."
    rm -f /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/*

    echo "Menambahkan repositori default untuk $DISTRO $VERSION..."

    # Debian
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
        fi
    fi

    # Ubuntu
    if [[ "$DISTRO" == "ubuntu" ]]; then
        if [[ "$VERSION" == "focal" ]]; then
            cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-updates main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-security main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-backports main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-proposed main restricted universe
EOF
        elif [[ "$VERSION" == "jammy" ]]; then
            cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/ubuntu/ jammy main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ jammy-updates main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ jammy-security main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ jammy-backports main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ jammy-proposed main restricted universe multiverse
EOF
        elif [[ "$VERSION" == "noble" ]]; then
            cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/ubuntu/ noble main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ noble-updates main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ noble-security main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ noble-backports main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ noble-proposed main restricted universe multiverse
EOF
        fi
    fi

    echo "Repositori untuk $DISTRO $VERSION berhasil ditambahkan."
}

# Deteksi distribusi dan versinya
DISTRO=$(lsb_release -i | awk '{print tolower($3)}')  # Debian/Ubuntu
VERSION=$(lsb_release -c | awk '{print $2}')  # buster/bookworm/focal/jammy/noble

# Panggil fungsi untuk menulis repo
write_repos $DISTRO $VERSION

# Update apt
echo "Melakukan pembaruan apt..."
apt update

echo "Selesai."
