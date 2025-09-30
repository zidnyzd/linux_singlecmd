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

# === 4. Setup auto-restart every 6 hours via systemd timer ===
echo "[4/7] Setting up auto-restart timer (every 6 hours)..."
RESTART_SERVICE_FILE="/etc/systemd/system/ws-restart.service"
RESTART_TIMER_FILE="/etc/systemd/system/ws-restart.timer"

# Create oneshot service to restart ws
cat > "$RESTART_SERVICE_FILE" << 'EOF'
[Unit]
Description=Restart ws service

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart ws
EOF

# Create timer to trigger every 6 hours
cat > "$RESTART_TIMER_FILE" << 'EOF'
[Unit]
Description=Restart ws.service every 6 hours

[Timer]
OnUnitActiveSec=6h
AccuracySec=1min
Persistent=true
Unit=ws-restart.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now ws-restart.timer
echo "✅ Auto-restart timer enabled: ws-restart.timer"

# === 5. Reload systemd and restart service ===
echo "[5/7] Restarting ws.service..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl restart ws

# === 6. Verifikasi patch ===
echo "[6/7] Verifying patch applied:"
grep -A3 "def removeConn" "$WS_FILE"

# === 7. Verifikasi batas file descriptor ===
echo "[7/7] Checking file descriptor limits:"
WS_PID=$(systemctl show -p MainPID ws | cut -d= -f2)
if [ -n "$WS_PID" ] && [ -e "/proc/$WS_PID/limits" ]; then
    cat /proc/"$WS_PID"/limits | grep "Max open files"
else
    echo "⚠️  Could not determine ws service PID or /proc entry missing."
fi

echo "✅ Patch complete. ws.service is running with safe removeConn and file descriptor limit."
echo "🟢 To rollback: sudo $0 --rollback"
