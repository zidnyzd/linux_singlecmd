#!/bin/bash

set -e

SERVICE_FILE="/etc/systemd/system/ws.service"
WS_FILE="/usr/bin/ws.py"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

BACKUP_SERVICE_FILE="${SERVICE_FILE}.bak.${TIMESTAMP}"
BACKUP_WS_FILE="${WS_FILE}.bak.${TIMESTAMP}"

ROLLBACK_MODE=0

# === Function: rollback ===
rollback() {
    echo "🔁 Rolling back..."

    if [ -f "$BACKUP_SERVICE_FILE" ]; then
        cp "$BACKUP_SERVICE_FILE" "$SERVICE_FILE"
        echo "✅ Restored $SERVICE_FILE"
    else
        echo "⚠️  No backup found for $SERVICE_FILE"
    fi

    if [ -f "$BACKUP_WS_FILE" ]; then
        cp "$BACKUP_WS_FILE" "$WS_FILE"
        echo "✅ Restored $WS_FILE"
    else
        echo "⚠️  No backup found for $WS_FILE"
    fi

    echo "♻️ Reloading systemd and restarting ws..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl restart ws

    echo "🔙 Rollback complete."
    exit 0
}

# === Check rollback flag ===
if [[ "$1" == "--rollback" ]]; then
    rollback
fi

echo "📦 Starting full patch for ws.service and ws.py..."

# === 1. Backup original files ===
echo "[1/6] Backing up original files..."
cp "$SERVICE_FILE" "$BACKUP_SERVICE_FILE"
cp "$WS_FILE" "$BACKUP_WS_FILE"
echo "🗃️  Backups saved:"
echo "    $BACKUP_SERVICE_FILE"
echo "    $BACKUP_WS_FILE"

# === 2. Patch systemd service (LimitNOFILE) ===
echo "[2/6] Ensuring LimitNOFILE=65535 is set..."
if ! grep -q "LimitNOFILE" "$SERVICE_FILE"; then
    sed -i '/^\[Service\]/a LimitNOFILE=65535' "$SERVICE_FILE"
    echo "✅ LimitNOFILE added"
else
    echo "ℹ️  LimitNOFILE already exists"
fi

# === 3. Patch ws.py removeConn ===
echo "[3/6] Patching removeConn safely in $WS_FILE..."
sed -i '/def removeConn(self, conn):/,/self.threadsLock.release()/c\
    def removeConn(self, conn):\
        try:\
            self.threadsLock.acquire()\
            if conn in self.threads:\
                self.threads.remove(conn)\
        finally:\
            self.threadsLock.release()' "$WS_FILE"
echo "✅ removeConn patched"

# === 4. Reload systemd and restart service ===
echo "[4/6] Restarting ws.service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart ws

# === 5. Verifikasi patch ===
echo "[5/6] Verifying patch applied:"
grep -A3 "def removeConn" "$WS_FILE"

# === 6. Verifikasi batas file descriptor ===
echo "[6/6] Checking file descriptor limits:"
WS_PID=$(systemctl show -p MainPID ws | cut -d= -f2)
if [ -n "$WS_PID" ] && [ -e "/proc/$WS_PID/limits" ]; then
    cat /proc/"$WS_PID"/limits | grep "Max open files"
else
    echo "⚠️  Could not determine ws service PID or /proc entry missing."
fi

echo "✅ Patch complete. ws.service is running with safe removeConn and file descriptor limit."
echo "🟢 To rollback: sudo $0 --rollback"
