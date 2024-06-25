#!/bin/bash

# Mendeteksi distribusi Linux
if grep -q "VERSION_CODENAME=buster" /etc/os-release; then
    # Debian 10 (Buster)
    echo 'Mendeteksi Debian 10 (Buster)'



    # Hapus file repositori sebelumnya jika sudah ada
    sudo rm -f /etc/apt/sources.list
    # Tambahkan repositori Debian 10 (Buster)
    sudo bash -c 'cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free
EOF
'

    sudo apt update
    sudo apt install gnupg -y && apt install bzip2 -y && apt install screen -y
    sleep 2

    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9 6ED0E7B82643E131
    sleep 2
    sudo apt update

    sudo rm -f /etc/apt/sources.list.d/backports.list
    sudo bash -c 'cat <<EOF > /etc/apt/sources.list.d/backports.list
deb http://archive.debian.org/debian buster-backports main contrib non-free
EOF
'
    sudo apt update

# Mendeteksi distribusi Linux
elif grep -q "VERSION_CODENAME=bullseye" /etc/os-release; then
    # Debian 10 (Buster)
    echo 'Mendeteksi Debian 11 (Bullseye)'



    # Hapus file repositori sebelumnya jika sudah ada
    sudo rm -f /etc/apt/sources.list
    # Tambahkan repositori Debian 10 (Buster)
    sudo bash -c 'cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/debian bullseye main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian bullseye-updates main contrib non-free
deb http://kartolo.sby.datautama.net.id/debian-security bullseye-security main contrib non-free
EOF
'

    sudo apt update
    sudo apt install gnupg -y && apt install bzip2 -y && apt install screen -y
    sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y && sudo apt-get install build-essential python-dev python-setuptools python-pip python-smbus -y && sudo apt-get install libncursesw5-dev libgdbm-dev libc6-dev -y && sudo apt-get install zlib1g-dev libsqlite3-dev tk-dev -y && sudo apt-get install libssl-dev openssl -y
    
    sleep 2

    sudo apt-get install libffi-dev -y

#     sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9 6ED0E7B82643E131
#     sleep 2
#     sudo apt update

#     sudo rm -f /etc/apt/sources.list.d/backports.list
#     sudo bash -c 'cat <<EOF > /etc/apt/sources.list.d/backports.list
# deb http://archive.debian.org/debian bullseye-backports main contrib non-free
# EOF
# '
    sudo apt update

elif grep -q "VERSION_CODENAME=focal" /etc/os-release; then
    # Ubuntu 20 (Focal Fossa)
    echo "Mendeteksi Ubuntu 20 (Focal Fossa)"
    sudo apt update
    # Hapus file repositori sebelumnya jika sudah ada
    sudo rm -f /etc/apt/sources.list
    # Tambahkan repositori Ubuntu 20 (Focal Fossa)
    sudo bash -c 'cat <<EOF > /etc/apt/sources.list
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-updates main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-security main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-backports main restricted universe multiverse
deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-proposed main restricted universe multiverse
EOF
'
    sudo apt update
else
    echo "Distribusi Linux tidak dikenal."
    exit 1
fi

# Memberitahu pengguna bahwa repositori telah diperbarui
echo "Repositori telah diperbarui."


# #!/bin/bash

# # Mendeteksi distribusi Linux
# if grep -q "Debian 10" /etc/os-release; then
#     # Debian 10 (Buster)
#     echo "Mendeteksi Debian 10 (Buster)"

#     sudo apt update
#     sudo apt install gnupg -y
#     sleep 2

#     sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9 6ED0E7B82643E131
#     sleep 2
#     sudo apt update

#     # Hapus file repositori sebelumnya jika sudah ada
#     sudo rm -f /etc/apt/sources.list
#     # Tambahkan repositori Debian 10 (Buster)
#     sudo bash -c 'cat <<EOF > /etc/apt/sources.list
# deb http://kartolo.sby.datautama.net.id/debian/ buster main contrib non-free
# deb http://kartolo.sby.datautama.net.id/debian/ buster-updates main contrib non-free
# deb http://kartolo.sby.datautama.net.id/debian-security/ buster/updates main contrib non-free
# EOF
# '
#     sudo rm -f /etc/apt/sources.list.d/buster-backports.list
#     sudo bash -c 'cat <<EOF > /etc/apt/sources.list.d/buster-backports.list
#     deb http://archive.debian.org/debian buster-backports main contrib non-free
# EOF
# '

# elif grep -q "Ubuntu 20" /etc/os-release; then
#     # Ubuntu 20 (Focal Fossa)
#     sudo apt update
#     echo "Mendeteksi Ubuntu 20 (Focal Fossa)"
#     # Hapus file repositori sebelumnya jika sudah ada
#     sudo rm -f /etc/apt/sources.list
#     # Tambahkan repositori Ubuntu 20 (Focal Fossa)
#     sudo bash -c 'cat <<EOF > /etc/apt/sources.list
# deb http://kartolo.sby.datautama.net.id/ubuntu/ focal main restricted universe multiverse
# deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-updates main restricted universe multiverse
# deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-security main restricted universe multiverse
# deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-backports main restricted universe multiverse
# deb http://kartolo.sby.datautama.net.id/ubuntu/ focal-proposed main restricted universe multiverse
# EOF
# '
#     sudo apt update

# else
#     echo "Distribusi Linux tidak dikenal."
#     exit 1
# fi

# # Memberitahu pengguna bahwa repositori telah diperbarui
# echo "Repositori telah diperbarui."
