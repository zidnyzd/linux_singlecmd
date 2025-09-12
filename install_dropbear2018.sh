#!/usr/bin/env bash
set -euo pipefail

# === Konfigurasi ===
VER="2018.76"
URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${VER}.tar.bz2"
SRC_ROOT="/usr/local/src"
SRC_DIR="${SRC_ROOT}/dropbear-${VER}"
BIN_NEW="/usr/local/sbin/dropbear2018"
DBCLIENT_NEW="/usr/local/bin/dbclient2018"
DBKEY_NEW="/usr/local/bin/dropbearkey2018"
DBCONV_NEW="/usr/local/bin/dropbearconvert2018"
SCP_NEW="/usr/local/bin/scp2018"
BIN_SYS="/usr/sbin/dropbear"
BACKUP_DIR="/usr/local/backup-dropbear"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_BIN="${BACKUP_DIR}/dropbear.${TS}.bak"

# === Cek root ===
if [[ "${EUID}" -ne 0 ]]; then
  echo "[!] Jalankan sebagai root." >&2
  exit 1
fi

echo "==> Menyiapkan dependensi build"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential zlib1g-dev curl ca-certificates pkg-config

mkdir -p "${SRC_ROOT}" "${BACKUP_DIR}"
cd "${SRC_ROOT}"

echo "==> Mengunduh Dropbear ${VER}"
curl -fL -o "dropbear-${VER}.tar.bz2" "${URL}"

echo "==> Mengekstrak sumber"
rm -rf "${SRC_DIR}"
tar xjf "dropbear-${VER}.tar.bz2"
cd "${SRC_DIR}"

echo "==> Konfigurasi (static) ..."
# Coba build static dulu (minim ketergantungan runtime).
# Jika gagal (keterbatasan glibc static), fallback ke build dinamis.
BUILD_STATIC=1
if ! CFLAGS="-Os" LDFLAGS="-static" ./configure --enable-static >/tmp/conf.log 2>&1; then
  BUILD_STATIC=0
  echo "[!] Configure static gagal, akan fallback ke build dinamis..."
fi

echo "==> Kompilasi"
if [[ "${BUILD_STATIC}" -eq 1 ]]; then
  if ! make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" -j"$(nproc)"; then
    echo "[!] Build static gagal, mencoba ulang build dinamis..."
    make clean
    ./configure >/tmp/conf2.log 2>&1
    make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" -j"$(nproc)"
    BUILD_STATIC=0
  fi
else
  ./configure >/tmp/conf2.log 2>&1 || true
  make PROGRAMS="dropbear dbclient dropbearkey dropbearconvert scp" -j"$(nproc)"
fi

echo "==> Strip biner"
strip dropbear dbclient dropbearkey dropbearconvert scp || true

echo "==> Install biner ke jalur '2018' (belum menimpa sistem)"
install -m 0755 dropbear        "${BIN_NEW}"
install -m 0755 dbclient        "${DBCLIENT_NEW}"
install -m 0755 dropbearkey     "${DBKEY_NEW}"
install -m 0755 dropbearconvert "${DBCONV_NEW}"
install -m 0755 scp             "${SCP_NEW}"

# Deteksi status servis saat ini
WAS_ACTIVE=0
if systemctl is-active --quiet dropbear; then
  WAS_ACTIVE=1
fi

echo "==> Hentikan servis dropbear (jika ada)"
systemctl stop dropbear || true

echo "==> Backup biner sistem lama (jika ada): ${BACKUP_BIN}"
if [[ -x "${BIN_SYS}" ]]; then
  cp -a "${BIN_SYS}" "${BACKUP_BIN}"
fi

echo "==> Menimpa /usr/sbin/dropbear dengan build 2018"
install -m 0755 "${BIN_NEW}" "${BIN_SYS}"

echo "==> Tahan paket agar tidak diupgrade otomatis"
apt-mark hold dropbear || true

if [[ "${WAS_ACTIVE}" -eq 1 ]]; then
  echo "==> Menyalakan kembali servis dropbear"
  systemctl start dropbear
else
  echo "==> Mengaktifkan dan menyalakan dropbear"
  systemctl enable --now dropbear || true
fi

echo "==> Status servis:"
systemctl status dropbear --no-pager || true

echo "==> Versi biner aktif:"
if "${BIN_SYS}" -V 2>/dev/null; then
  "${BIN_SYS}" -V
else
  echo "(tidak bisa membaca versi; coba: /usr/sbin/dropbear -V)"
fi

echo
echo "Selesai. Backup biner lama: ${BACKUP_BIN}"
if [[ "${BUILD_STATIC}" -eq 1 ]]; then
  echo "Catatan: Build static berhasil."
else
  echo "Catatan: Menggunakan build dinamis (static gagal di lingkungan ini)."
fi

# Buat skrip rollback untuk kemudahan
ROLLBACK="/usr/local/sbin/rollback_dropbear2018.sh"
cat > "${ROLLBACK}" <<'RB'
#!/usr/bin/env bash
set -euo pipefail

BIN_SYS="/usr/sbin/dropbear"
BACKUP_DIR="/usr/local/backup-dropbear"

if [[ "${EUID}" -ne 0 ]]; then
  echo "[!] Jalankan sebagai root." >&2
  exit 1
fi

echo "==> Mencari backup terbaru di ${BACKUP_DIR}"
LATEST="$(ls -1t ${BACKUP_DIR}/dropbear.*.bak 2>/dev/null | head -n1 || true)"
if [[ -z "${LATEST}" ]]; then
  echo "[!] Tidak menemukan backup. Batal."
  exit 1
fi

systemctl stop dropbear || true
echo "==> Mengembalikan biner: ${LATEST} -> ${BIN_SYS}"
install -m 0755 "${LATEST}" "${BIN_SYS}"

echo "==> Melepaskan hold paket"
apt-mark unhold dropbear || true

echo "==> Menjalankan servis"
systemctl start dropbear || true
systemctl status dropbear --no-pager || true

echo "Rollback selesai."
RB
chmod +x "${ROLLBACK}"
echo "Skrip rollback dibuat: ${ROLLBACK}"
