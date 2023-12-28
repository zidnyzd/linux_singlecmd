# Menambah Swap RAM
sudo fallocate -l 2G /swapfile && ls -lh /swapfile
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
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf