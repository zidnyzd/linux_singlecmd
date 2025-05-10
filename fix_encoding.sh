#!/bin/bash

# Tambahkan LANG ke ~/.bashrc jika belum ada
grep -qxF 'export LANG=C.UTF-8' ~/.bashrc || echo 'export LANG=C.UTF-8' >> ~/.bashrc

# Tambahkan LANG ke /etc/environment jika belum ada
if ! grep -q '^LANG=' /etc/environment; then
  echo 'LANG=C.UTF-8' | sudo tee -a /etc/environment
else
  sudo sed -i 's/^LANG=.*/LANG=C.UTF-8/' /etc/environment
fi

# Tambahkan LANG ke /etc/default/locale jika belum ada
if [ -f /etc/default/locale ]; then
  if ! grep -q '^LANG=' /etc/default/locale; then
    echo 'LANG=C.UTF-8' | sudo tee -a /etc/default/locale
  else
    sudo sed -i 's/^LANG=.*/LANG=C.UTF-8/' /etc/default/locale
  fi
else
  echo 'LANG=C.UTF-8' | sudo tee /etc/default/locale
fi

# Pastikan SSH menerima environment variable LANG
if ! grep -q '^AcceptEnv LANG' /etc/ssh/sshd_config; then
  echo 'AcceptEnv LANG LC_*' | sudo tee -a /etc/ssh/sshd_config
fi

# Restart SSH dan reload bashrc
sudo systemctl restart sshd
source ~/.bashrc

echo "Selesai. Silakan logout dan login ulang untuk memastikan LANG permanen."
