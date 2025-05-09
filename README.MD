# 🚀 Linux Server Management Scripts

![Linux Logo](https://raw.githubusercontent.com/torvalds/linux/master/Documentation/logo.gif)

## 📋 Overview

Koleksi script otomatis untuk manajemen server Linux Anda. Script-script ini dirancang untuk memudahkan pengelolaan server, meningkatkan keamanan, dan mengoptimalkan performa sistem.

## 🛠️ Script Categories

### 🔒 Security & Protection
- **Fail2Ban Installation** - Blokir serangan brute force SSH
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/fail2ban.sh && chmod +x fail2ban.sh && ./fail2ban.sh
  ```

- **Root Access Management**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/root.sh && chmod +x root.sh && ./root.sh
  ```

### 🌐 Network Management
- **WARP Configuration**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/warp.sh && chmod +x warp.sh && ./warp.sh
  ```

- **WARP Restart**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/warp-restart.sh && chmod +x warp-restart.sh && ./warp-restart.sh
  ```

- **DNS Configuration**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/dns.sh && chmod +x dns.sh && ./dns.sh
  ```

- **IPv4 Priority Setting**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/set_ipv4_priority.sh && chmod +x set_ipv4_priority.sh && ./set_ipv4_priority.sh
  ```

### 💻 System Optimization
- **Repository Setup** (Debian 10/11/12 & Ubuntu 20/22/24)
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/repo.sh && chmod +x repo.sh && ./repo.sh
  ```

- **Kernel Management Tool**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/fix_kernel.sh && chmod +x fix_kernel.sh && ./fix_kernel.sh
  ```

- **LowSpec VPS Optimization**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/fixlow.sh && chmod +x fixlow.sh && ./fixlow.sh
  ```

- **Add Swap RAM**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/add_swap.sh && chmod +x add_swap.sh && ./add_swap.sh
  ```

- **Fix Storage Full**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/fix_storage.sh && chmod +x fix_storage.sh && ./fix_storage.sh
  ```

### 📊 Monitoring & Management
- **Gotop Installation** (System Monitor)
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/gotop.sh && chmod +x gotop.sh && ./gotop.sh
  ```

- **Network Bandwidth Control**
  ```bash
  cd /usr/local/bin && wget https://raw.githubusercontent.com/zidnyzd/linux/main/network_limit.sh && sudo chmod +x /usr/local/bin/network_limit.sh && sudo /usr/local/bin/network_limit.sh
  ```

- **VNStat Fix**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/vnstat.sh && chmod +x vnstat.sh && ./vnstat.sh
  ```

### 🎮 Game Server Management
- **Minecraft Server Installation**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/minecraft.sh && chmod +x minecraft.sh && ./minecraft.sh
  ```

### 🔧 Maintenance & Utilities
- **XRAY Fix**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/fix_xray.sh && chmod +x fix_xray.sh && ./fix_xray.sh
  ```

- **Usage Reset**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/install_reset_usage.sh && chmod +x install_reset_usage.sh && ./install_reset_usage.sh
  ```

- **SSH Banner Update**
  ```bash
  wget https://raw.githubusercontent.com/zidnyzd/linux/main/banner.sh && chmod +x banner.sh && ./banner.sh
  ```

## 📝 Usage Instructions

1. **Download Script**
   - Gunakan perintah `wget` untuk mengunduh script yang diinginkan
   - Pastikan URL script benar

2. **Set Permissions**
   - Berikan izin eksekusi dengan `chmod +x`

3. **Run Script**
   - Jalankan script dengan `./nama_script.sh`

## ⚠️ Important Notes

- Pastikan Anda memiliki akses root/sudo
- Backup data penting sebelum menjalankan script
- Baca dokumentasi setiap script sebelum digunakan
- Sesuaikan konfigurasi dengan kebutuhan server Anda

## 🔍 Troubleshooting

Jika mengalami masalah:
1. Periksa log sistem
2. Pastikan semua dependensi terpenuhi
3. Verifikasi koneksi internet
4. Periksa versi sistem operasi

## 🤝 Contributing

Kontribusi selalu diterima! Silakan:
- Fork repository
- Buat branch baru
- Commit perubahan
- Push ke branch
- Buat Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Made with ❤️ for Linux Server Management
