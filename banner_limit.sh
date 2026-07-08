#!/bin/bash
# Dropbear Banner Size Customizer
# Rebuilds dropbear from source with custom MAX_BANNER_SIZE
# Usage: ./banner_limit.sh [new_limit_bytes]
# Default: 5000

NEW_LIMIT="${1:-5000}"
DROPBEAR_VER="2018.76"
DROPBEAR_URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VER}.tar.bz2"
BUILD_DIR="/tmp/dropbear-build-$$"

if [[ "$NEW_LIMIT" -lt 1000 || "$NEW_LIMIT" -gt 65535 ]]; then
    echo "Limit must be between 1000-65535"
    exit 1
fi

# Cek root
[[ $EUID -ne 0 ]] && { echo "Must be root"; exit 1; }

# Restore dropbear kalo broken dari patch sebelumnya
if command -v apt-get &>/dev/null; then
    apt-get install --reinstall -y dropbear 2>/dev/null || true
elif command -v yum &>/dev/null; then
    yum reinstall -y dropbear 2>/dev/null || true
fi

# Cek build tools
for cmd in gcc make wget bzip2; do
    if ! command -v $cmd &>/dev/null; then
        echo "Installing $cmd..."
        if command -v apt-get &>/dev/null; then
            apt-get install -y $cmd
        elif command -v yum &>/dev/null; then
            yum install -y $cmd
        fi
    fi
done

echo "Downloading dropbear ${DROPBEAR_VER}..."
cd /tmp
wget -q "$DROPBEAR_URL" -O "dropbear-${DROPBEAR_VER}.tar.bz2"
tar xf "dropbear-${DROPBEAR_VER}.tar.bz2"
cd "dropbear-${DROPBEAR_VER}"

# Patch MAX_BANNER_SIZE — di sysoptions.h (modern) atau debug.h (lawas)
echo "Patching MAX_BANNER_SIZE -> $NEW_LIMIT ..."
sed -i "s/#define MAX_BANNER_SIZE [0-9]*/#define MAX_BANNER_SIZE $NEW_LIMIT/" sysoptions.h 2>/dev/null || true
sed -i "s/#define MAX_BANNER_SIZE [0-9]*/#define MAX_BANNER_SIZE $NEW_LIMIT/" debug.h 2>/dev/null || true

# Build
echo "Compiling..."
./configure --quiet --disable-lastlog --disable-utmpx --disable-wtmp --disable-wtmpx --disable-loginfunc --disable-pututline --disable-pututxline
make -j$(nproc) dropbear
make install-dropbear 2>/dev/null || {
    # Fallback: copy manual
    cp dropbear /usr/sbin/dropbear
    chmod 755 /usr/sbin/dropbear
}

# Bersih
cd /tmp
rm -rf "dropbear-${DROPBEAR_VER}" "dropbear-${DROPBEAR_VER}.tar.bz2" "$BUILD_DIR"

# Restart
systemctl restart dropbear 2>/dev/null || service dropbear restart 2>/dev/null
echo "Dropbear restarted"

# Verifikasi
echo ""
echo "Banner files:"
for f in /etc/fightertunnel.txt /etc/zidstoretunnel.txt /etc/banner.txt /etc/issue.net; do
    if [[ -f "$f" ]]; then
        sz=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null)
        ok="OK"; [[ "$sz" -gt "$NEW_LIMIT" ]] && ok="EXCEEDS"
        echo "  $ok $f: $sz bytes"
    fi
done
echo "Done. New limit: $NEW_LIMIT bytes"
