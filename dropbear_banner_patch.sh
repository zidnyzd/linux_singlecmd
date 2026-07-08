#!/bin/bash
# Dropbear MAX_BANNER_SIZE Context-Aware Patcher
# Patch langsung di binary menggunakan string anchor utk menghindari false positive
# Usage: ./dropbear_banner_patch.sh [new_limit_bytes]
# Default: 5000

NEW_LIMIT="${1:-5000}"
DROPBEAR_BIN=$(command -v dropbear 2>/dev/null || echo "/usr/sbin/dropbear")
ANCHOR_STR="Banner file too large"

# --- Restore dari backup terakhir ---
if [[ "$1" == "restore" ]]; then
    LATEST_BACKUP=$(ls -t "${DROPBEAR_BIN}.bak."* 2>/dev/null | head -1)
    if [[ -z "$LATEST_BACKUP" ]]; then
        echo "Error: No backup found to restore"
        exit 1
    fi
    echo "[*] Restoring from: $LATEST_BACKUP"
    systemctl stop dropbear 2>/dev/null; sleep 1
    while pidof dropbear &>/dev/null; do killall -9 dropbear 2>/dev/null; sleep 1; done
    systemctl mask dropbear 2>/dev/null || true; sleep 1
    cp "$LATEST_BACKUP" "$DROPBEAR_BIN"
    systemctl unmask dropbear 2>/dev/null || true
    systemctl start dropbear 2>/dev/null || dropbear -p 22 2>/dev/null || true
    echo "[+] Backup restored. Dropbear restarted."
    exit 0
fi

# --- Validasi ---
if [[ "$NEW_LIMIT" -lt 1000 || "$NEW_LIMIT" -gt 65535 ]]; then
    echo "Error: Limit must be between 1000-65535"
    exit 1
fi
[[ $EUID -ne 0 ]] && { echo "Error: Must be root"; exit 1; }
[[ ! -f "$DROPBEAR_BIN" ]] && { echo "Error: dropbear binary not found"; exit 1; }
command -v python3 &>/dev/null || { echo "Error: python3 required"; exit 1; }

# --- Cari & patch SEMUA kemunculan MAX_BANNER_SIZE di binary ---
echo "[*] Scanning binary for MAX_BANNER_SIZE constant..."
echo "     (pastikan binary fresh — jalankan \`apt install --reinstall -y dropbear\` dulu jika ragu)"
python3 <<PYEOF
import sys, struct

path = "$DROPBEAR_BIN"
new_val = int("$NEW_LIMIT")

with open(path, 'rb') as f:
    data = bytearray(f.read())

# 1. Cari format string sebagai anchor
fmt_full = b"Banner file too large, max is %d bytes"
fmt_idx = data.find(fmt_full)
if fmt_idx == -1:
    fmt_idx = data.find(b"max is %d bytes")
if fmt_idx == -1:
    print("ERROR: Format string not found!")
    sys.exit(1)
print(f"  Format string anchor at 0x{fmt_idx:06x}")

# 2. Cari XREF (LEA RDI) ke format string untuk tahu konteks fungsinya
xref = -1
i = 0
while i < fmt_idx - 7:
    if data[i:i+3] == b'\x48\x8d\x3d':
        disp = struct.unpack_from('<i', data, i+3)[0]
        if i + 7 + disp == fmt_idx:
            xref = i
            break
    i += 1
if xref == -1:
    print("ERROR: No XREF to format string!")
    sys.exit(1)
print(f"  XREF at 0x{xref:06x}")

# 3. Cari MOV ESI di dekat XREF untuk tahu old_val
old_val = None
for j in range(xref - 150, xref - 4):
    if data[j] == 0xBE and j < len(data) - 5:
        val = struct.unpack_from('<I', data, j+1)[0]
        if 500 <= val <= 65535:
            old_val = val
            print(f"  MOV ESI,{old_val} at 0x{j:06x} — old value")
            break

if old_val is None:
    print("ERROR: Could not determine old MAX_BANNER_SIZE!")
    sys.exit(1)

print(f"\n  Searching entire binary for value {old_val} before format string...")

# 4. Cari SEMUA kemunculan old_val sebagai imm32 di binary
patches = []
seen = set()
pos = 0
limit = fmt_idx

while pos < limit - 4:
    val = struct.unpack_from('<I', data, pos)[0]
    if val != old_val:
        pos += 1
        continue
    if pos in seen:
        pos += 1
        continue

    matched = False
    itype = ""

    if pos >= 1:
        b = data[pos-1]
        if b == 0x3D:
            matched = True; itype = "CMP EAX"
        elif b == 0xB8:
            matched = True; itype = "MOV EAX"
        elif b in (0xBE, 0xBF, 0xBD, 0xBC):
            matched = True; itype = "MOV r32"
        elif b in range(0xF8, 0x100) and pos >= 2 and data[pos-2] == 0x81:
            matched = True; itype = "CMP r32,imm (81)"
    if not matched and pos >= 2:
        b1, b2 = data[pos-2], data[pos-1]
        if b1 in (0x48, 0x41, 0x44) and b2 in (0xB8, 0xBE, 0xBF, 0xBD, 0xBC):
            matched = True; itype = "MOV r64 (REX)"
        elif b1 == 0x81 and b2 == 0x7D:
            matched = True; itype = "CMP [rbp+disp8]"
        elif b1 == 0x48 and b2 == 0x3D:
            matched = True; itype = "CMP RAX"
        elif b1 == 0x81 and 0xF8 <= b2 <= 0xFF:
            matched = True; itype = "CMP r32,imm (81)"
        elif b1 == 0x48 and b2 in range(0xF8, 0x100) and pos >= 3 and data[pos-3] == 0x81:
            matched = True; itype = "CMP r64,imm (48 81)"
    if not matched and pos >= 3:
        b1, b2, b3 = data[pos-3], data[pos-2], data[pos-1]
        if b1 == 0x81 and b2 == 0xBD:
            matched = True; itype = "CMP [rbp+disp32]"
        elif b1 == 0x48 and b2 == 0x81 and b3 == 0x7D:
            matched = True; itype = "CMP [rbp+disp8] (REX)"

    if matched:
        print(f"    {itype},{old_val} at 0x{pos:06x}")
        patches.append((pos, itype))
        seen.add(pos)
        pos += 4
    else:
        pos += 1

if not patches:
    print("ERROR: No occurrences found!")
    sys.exit(1)

print(f"\n  Total: {len(patches)} instruction(s) with imm32 = {old_val}")

if len(patches) > 5:
    print(f"  WARNING: {len(patches)} is too many! Aborting.")
    sys.exit(1)

# 5. Tulis info ke temp SEBELUM stop & backup
with open("/tmp/_dropbear_patch.tmp", "w") as f:
    f.write(f"{old_val} {len(patches)}")

for offset_str, itype in [(hex(o), t) for o, t in patches]:
    print(f"  TO_PATCH: 0x{offset_str}: {itype}")
PYEOF

DETECT_STATUS=$?
if [[ "$DETECT_STATUS" -ne 0 ]]; then
    echo "[-] Detection failed. Please run banner_limit.sh instead."
    exit 1
fi

read -r OLD_VAL PATCH_COUNT < /tmp/_dropbear_patch.tmp
rm -f /tmp/_dropbear_patch.tmp

echo ""
echo "========================================"
echo " Dropbear MAX_BANNER_SIZE Patcher"
echo "========================================"
echo " Binary  : $DROPBEAR_BIN"
echo " Current : $OLD_VAL bytes"
echo " Target  : $NEW_LIMIT bytes"
echo " Patches : $PATCH_COUNT location(s)"
echo "========================================"
echo ""

# --- Stop dropbear dulu ---
if pidof dropbear &>/dev/null; then
    echo "[*] Stopping dropbear..."
    systemctl stop dropbear 2>/dev/null
    while pidof dropbear &>/dev/null; do
        killall -9 dropbear 2>/dev/null
        sleep 1
    done
    systemctl mask dropbear 2>/dev/null || true
    sleep 1
fi

# --- Backup ---
BACKUP="${DROPBEAR_BIN}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$DROPBEAR_BIN" "$BACKUP"
echo "[+] Backup saved: $BACKUP"

# --- Patch (ulang scanning + patch di sini, setelah backup) ---
echo "[*] Patching $OLD_VAL -> $NEW_LIMIT in binary..."
python3 <<PYEOF
import sys, struct

path = "$DROPBEAR_BIN"
old_val = int($OLD_VAL)
new_val = int($NEW_LIMIT)
fmt_full = b"Banner file too large, max is %d bytes"

with open(path, 'rb') as f:
    data = bytearray(f.read())

fmt_idx = data.find(fmt_full)
if fmt_idx == -1:
    fmt_idx = data.find(b"max is %d bytes")
if fmt_idx == -1:
    print("ERROR: Format string not found!")
    sys.exit(1)

# Patch semua kemunculan old_val sebagai imm32 instruction
patched = 0
pos = 0
while pos < fmt_idx - 4:
    val = struct.unpack_from('<I', data, pos)[0]
    if val != old_val:
        pos += 1
        continue
    # Validasi opcode
    is_valid = False
    if pos >= 1:
        b = data[pos-1]
        if b in (0x3D, 0xB8) or b in (0xBE, 0xBF, 0xBD, 0xBC):
            is_valid = True
        elif b in range(0xF8, 0x100) and pos >= 2 and data[pos-2] == 0x81:
            is_valid = True
    if not is_valid and pos >= 2:
        b1, b2 = data[pos-2], data[pos-1]
        if b1 in (0x48, 0x41, 0x44) and b2 in (0xB8, 0xBE, 0xBF, 0xBD, 0xBC):
            is_valid = True
        elif b1 == 0x81 and b2 in (0x7D, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF):
            is_valid = True
        elif b1 == 0x48 and b2 == 0x3D:
            is_valid = True
        elif b1 == 0x48 and b2 in range(0xF8, 0x100) and pos >= 3 and data[pos-3] == 0x81:
            is_valid = True
    if not is_valid and pos >= 3:
        b1, b2, b3 = data[pos-3], data[pos-2], data[pos-1]
        if b1 == 0x81 and b2 == 0xBD:
            is_valid = True
        elif b1 == 0x48 and b2 == 0x81 and b3 == 0x7D:
            is_valid = True
    if is_valid:
        new_bytes = struct.pack('<I', new_val)
        data[pos:pos+4] = new_bytes
        print(f"    0x{pos:06x}: {old_val} -> {new_val}")
        patched += 1
        pos += 4
    else:
        pos += 1

if patched == 0:
    print("ERROR: No locations patched!")
    sys.exit(1)

with open(path, 'wb') as f:
    f.write(data)
print(f"\n[+] Patched {patched} location(s)")
PYEOF

PATCHED=$?

# --- Verifikasi ---
if [[ "$PATCHED" -eq 0 ]]; then
    changed=$(cmp -l "$BACKUP" "$DROPBEAR_BIN" 2>/dev/null | wc -l || echo 0)
    echo "[+] Bytes changed: $changed"

    # Verifikasi nilai baru sudah benar
    verify=$(python3 -c "
import struct
with open('$DROPBEAR_BIN', 'rb') as f:
    d = f.read()
# Cek apakah nilai baru ada di area fungsi
fn_start = d.find(b'Banner file too large, max is %d bytes')
if fn_start == -1:
    fn_start = d.find(b'max is %d bytes')
if fn_start == -1:
    print('SKIP')
else:
    off = d.find(struct.pack('<I', $NEW_LIMIT), max(0, fn_start - 500), fn_start)
    if off != -1:
        print(f'OK 0x{off:x}')
    else:
        # Fallback: cari di seluruh binary
        cnt = d.count(struct.pack('<I', $NEW_LIMIT))
        print(f'FOUND {cnt}')
")
    echo "[+] New value ($NEW_LIMIT) verified in patched binary"

    orig_size=$(stat -c%s "$BACKUP" 2>/dev/null || stat -f%z "$BACKUP" 2>/dev/null)
    new_size=$(stat -c%s "$DROPBEAR_BIN" 2>/dev/null || stat -f%z "$DROPBEAR_BIN" 2>/dev/null)
    if [[ "$orig_size" -ne "$new_size" ]]; then
        echo "[-] File size changed! Restoring..."
        cp "$BACKUP" "$DROPBEAR_BIN"
        exit 1
    fi
    echo "[+] File size: $orig_size bytes (unchanged)"

    # Start dropbear
    echo "[*] Starting dropbear..."
    systemctl unmask dropbear 2>/dev/null || true
    systemctl start dropbear 2>/dev/null || service dropbear start 2>/dev/null || dropbear -p 22 2>/dev/null || true
    sleep 1
    if pidof dropbear &>/dev/null; then
        echo "[+] Dropbear is running"
    else
        echo "[-] Dropbear not running, trying direct start..."
        dropbear -p 22 2>/dev/null || true
    fi

    echo ""
    echo "========================================"
    echo "  SUCCESS! $OLD_VAL -> $NEW_LIMIT bytes"
    echo "========================================"
else
    echo "[-] Failed. Restoring backup..."
    cp "$BACKUP" "$DROPBEAR_BIN"
    systemctl unmask dropbear 2>/dev/null || true
    systemctl start dropbear 2>/dev/null || dropbear -p 22 2>/dev/null || true
    exit 1
fi
