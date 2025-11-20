#!/bin/bash

set -e

SERVICE_FILE="/etc/systemd/system/ws.service"
WS_FILE="/usr/bin/ws.py"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

BACKUP_SERVICE_FILE="${SERVICE_FILE}.bak.${TIMESTAMP}"
BACKUP_WS_FILE="${WS_FILE}.bak.${TIMESTAMP}"

ROLLBACK_MODE=0

# === Function: list backups ===
list_backups() {
    echo "📋 Available backups:"
    echo ""
    echo "Service file backups:"
    ls -1th "${SERVICE_FILE}.bak."* 2>/dev/null | head -5 | nl || echo "   No backups found"
    echo ""
    echo "ws.py backups:"
    ls -1th "${WS_FILE}.bak."* 2>/dev/null | head -5 | nl || echo "   No backups found"
    echo ""
}

# === Function: find latest backup ===
find_latest_backup() {
    local backup_type=$1
    local latest=""
    
    if [ "$backup_type" == "service" ]; then
        latest=$(ls -1t "${SERVICE_FILE}.bak."* 2>/dev/null | head -1)
    elif [ "$backup_type" == "ws" ]; then
        latest=$(ls -1t "${WS_FILE}.bak."* 2>/dev/null | head -1)
    fi
    
    echo "$latest"
}

# === Function: rollback ===
rollback() {
    echo "🔁 Starting rollback process..."
    echo ""
    
    # If specific timestamp provided
    if [ -n "$1" ]; then
        BACKUP_SERVICE_FILE="${SERVICE_FILE}.bak.${1}"
        BACKUP_WS_FILE="${WS_FILE}.bak.${1}"
        echo "📌 Using specified backup timestamp: $1"
    else
        # Find latest backups
        BACKUP_SERVICE_FILE=$(find_latest_backup "service")
        BACKUP_WS_FILE=$(find_latest_backup "ws")
        echo "📌 Using latest backups:"
    fi
    
    echo ""
    
    # Restore service file
    if [ -f "$BACKUP_SERVICE_FILE" ]; then
        cp "$BACKUP_SERVICE_FILE" "$SERVICE_FILE"
        echo "✅ Restored $SERVICE_FILE"
        echo "   From: $BACKUP_SERVICE_FILE"
    else
        echo "⚠️  No backup found for $SERVICE_FILE"
        if [ -n "$1" ]; then
            echo "   Looking for: ${SERVICE_FILE}.bak.${1}"
        fi
    fi
    
    # Restore ws.py file
    if [ -f "$BACKUP_WS_FILE" ]; then
        cp "$BACKUP_WS_FILE" "$WS_FILE"
        chmod +x "$WS_FILE"
        echo "✅ Restored $WS_FILE"
        echo "   From: $BACKUP_WS_FILE"
    else
        echo "⚠️  No backup found for $WS_FILE"
        if [ -n "$1" ]; then
            echo "   Looking for: ${WS_FILE}.bak.${1}"
        fi
    fi
    
    # Disable and remove auto-restart timer if exists
    RESTART_TIMER_FILE="/etc/systemd/system/ws-restart.timer"
    RESTART_SERVICE_FILE="/etc/systemd/system/ws-restart.service"
    
    if systemctl is-enabled ws-restart.timer &>/dev/null; then
        echo "🔄 Disabling auto-restart timer..."
        systemctl stop ws-restart.timer 2>/dev/null || true
        systemctl disable ws-restart.timer 2>/dev/null || true
        echo "✅ Auto-restart timer disabled"
    fi
    
    if [ -f "$RESTART_TIMER_FILE" ]; then
        rm -f "$RESTART_TIMER_FILE"
        echo "✅ Removed $RESTART_TIMER_FILE"
    fi
    
    if [ -f "$RESTART_SERVICE_FILE" ]; then
        rm -f "$RESTART_SERVICE_FILE"
        echo "✅ Removed $RESTART_SERVICE_FILE"
    fi
    
    echo ""
    echo "♻️  Reloading systemd and restarting ws..."
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl restart ws
    
    # Verify service status
    sleep 2
    if systemctl is-active --quiet ws; then
        echo "✅ ws.service is running"
    else
        echo "⚠️  ws.service status: $(systemctl is-active ws || echo 'inactive')"
    fi
    
    echo ""
    echo "🔙 Rollback complete."
    exit 0
}

# === Check rollback flags ===
if [[ "$1" == "--rollback" ]]; then
    if [[ "$2" == "--list" ]] || [[ "$2" == "-l" ]]; then
        list_backups
        exit 0
    fi
    rollback "$2"
fi

echo "📦 Starting update for ws.service and ws.py..."

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

# === 3. Replace ws.py with new version ===
echo "[3/6] Replacing ws.py with new version..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NEW_WS_FILE="${SCRIPT_DIR}/ws.py"

if [ ! -f "$NEW_WS_FILE" ]; then
    echo "❌ Error: $NEW_WS_FILE not found!"
    echo "   Please ensure ws.py is in the same directory as this script."
    exit 1
fi

cp "$NEW_WS_FILE" "$WS_FILE"
chmod +x "$WS_FILE"
echo "✅ ws.py replaced with new version"

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

# === 6. Verifikasi file ws.py ===
echo "[6/7] Verifying ws.py file:"
if [ -f "$WS_FILE" ]; then
    echo "✅ ws.py file exists"
    grep -A3 "def removeConn" "$WS_FILE" || echo "⚠️  Could not find removeConn method"
else
    echo "❌ Error: ws.py file not found!"
fi

# === 7. Verifikasi batas file descriptor ===
echo "[7/7] Checking file descriptor limits:"
WS_PID=$(systemctl show -p MainPID ws | cut -d= -f2)
if [ -n "$WS_PID" ] && [ -e "/proc/$WS_PID/limits" ]; then
    cat /proc/"$WS_PID"/limits | grep "Max open files"
else
    echo "⚠️  Could not determine ws service PID or /proc entry missing."
fi

echo "✅ Update complete. ws.service is running with new ws.py and file descriptor limit."
echo ""
echo "🟢 Rollback options:"
echo "   List backups:    sudo $0 --rollback --list"
echo "   Rollback latest: sudo $0 --rollback"
echo "   Rollback specific: sudo $0 --rollback YYYYMMDD_HHMMSS"
