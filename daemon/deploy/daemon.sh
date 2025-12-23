#!/system/bin/sh
# Magisk service script for OhMyPhone daemon
# Place in /data/adb/service.d/ohmyphone.sh

LOG_FILE="/data/local/tmp/ohmyphone.log"
DAEMON_DIR="/data/local/tmp/ohmyphone"
DAEMON_BIN="${DAEMON_DIR}/ohmyphone-daemon"
CONFIG_FILE="${DAEMON_DIR}/config.toml"

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# Log startup
echo "[$(date)] Starting OhMyPhone daemon..." >> "$LOG_FILE"

# Check if daemon binary exists
if [ ! -f "$DAEMON_BIN" ]; then
    echo "[$(date)] ERROR: Daemon binary not found at $DAEMON_BIN" >> "$LOG_FILE"
    exit 1
fi

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$(date)] ERROR: Config file not found at $CONFIG_FILE" >> "$LOG_FILE"
    exit 1
fi

# Make daemon executable
chmod 755 "$DAEMON_BIN"

# Change to daemon directory
cd "$DAEMON_DIR" || exit 1

# Start daemon
"$DAEMON_BIN" >> "$LOG_FILE" 2>&1 &

echo "[$(date)] Daemon started with PID $!" >> "$LOG_FILE"
