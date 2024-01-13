#!/bin/bash

# Meminta input dari pengguna
read -p "Input Kapasitas Swap RAM (dalam satuan GB): " ram

# Validasi input untuk memastikan hanya angka yang dimasukkan
if [[ ! "$ram" =~ ^[0-9]+$ ]]; then
    echo "Input tidak valid. Harap masukkan angka."
    exit 1
fi

# Menambah Swap RAM
sudo fallocate -l "${ram}G" /swapfile && ls -lh /swapfile
sleep 5
sudo chmod 600 /swapfile && ls -lh /swapfile
sleep 5
sudo mkswap /swapfile
sleep 5
sudo swapon /swapfile && sudo swapon --show
sleep 5
sudo cp /etc/fstab /etc/fstab.bak
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Mengatur parameter swapiness dan vfs_cache_pressure
sudo sysctl vm.swappiness=10
sudo sysctl vm.vfs_cache_pressure=50

# Menambahkan parameter ke dalam /etc/sysctl.conf
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf

echo "Berhasil Menambah SWAP RAM ${ram}GB"
