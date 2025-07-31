#!/bin/bash

# Fungsi untuk menulis repo default internasional
write_default_repos() {
    DISTRO=$1
    VERSION=$2

    echo "Menggunakan repositori DEFAULT (resmi internasional)..."
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
                # Disable Check-Valid-Until for EOL repos
                echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until
                ;;
            bullseye)
                cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
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
}

# Fungsi untuk menulis repo lokal kartolo.sby
write_kartolo_repos() {
    DISTRO=$1
    VERSION=$2

    echo "Menggunakan repositori KARTOLO (Indonesia)..."
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
}

# Deteksi distribusi dan versinya
DISTRO=$(lsb_release -i | awk '{print tolower($3)}')  # debian/ubuntu
VERSION=$(lsb_release -c | awk '{print $2}')          # buster/bookworm/etc

echo "Distribusi terdeteksi: $DISTRO"
echo "Versi rilis: $VERSION"
echo "Pilih repositori:"
echo "1) Default (resmi internasional)"
echo "2) Kartolo (lokal Indonesia)"
read -p "Masukkan pilihan [1/2]: " CHOICE

case "$CHOICE" in
    1)
        write_default_repos "$DISTRO" "$VERSION"
        ;;
    2)
        write_kartolo_repos "$DISTRO" "$VERSION"
        ;;
    *)
        echo "Pilihan tidak valid. Keluar."
        exit 1
        ;;
esac

echo "Melakukan update apt..."
apt update
echo "Selesai."
