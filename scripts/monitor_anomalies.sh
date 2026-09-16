#!/usr/bin/env bash
set -eo pipefail

# Threshold configurations (customizable)
LOAD_PER_CORE_THRESHOLD=2.0   # Load avg / cores > 2.0 (e.g. > 24 on 12-core)
DISK_WARN_THRESHOLD=85        # Disk usage %
CHECK_OPENCLAW=true           # Alert if OpenClaw is down
CHECK_TWINGATE=true           # Alert if Twingate disconnects

STATE_FILE="/tmp/macmini_anomaly_state"
TELEGRAM_SCRIPT="/Users/sakki/.warp/scripts/send_telegram.sh"

ANOMALIES=()

# 1. Check CPU Load Average
CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 12)
LOAD_1MIN=$(uptime | awk -F'load averages?: ' '{print $2}' | awk '{print $1}' | tr -d ',')
# Float comparison via awk
LOAD_HIGH=$(awk -v l="$LOAD_1MIN" -v c="$CORES" -v t="$LOAD_PER_CORE_THRESHOLD" 'BEGIN { if ((l / c) >= t) print 1; else print 0 }')

if [ "$LOAD_HIGH" -eq 1 ]; then
    ANOMALIES+=("🔥 *High CPU Load*: ${LOAD_1MIN} across ${CORES} cores (limit: $(( CORES * 2 )))")
fi

# 2. Check Disk Space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -ge "$DISK_WARN_THRESHOLD" ]; then
    DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
    ANOMALIES+=("💾 *Low Disk Space*: Root volume is at ${DISK_USAGE}% capacity (${DISK_AVAIL} remaining)")
fi

# 3. Check OpenClaw Gateway Daemon
if [ "$CHECK_OPENCLAW" = "true" ]; then
    if ! pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
        ANOMALIES+=("🦞 *OpenClaw Gateway Down*: Process is not running on port 18789")
    fi
fi

# 4. Check Twingate Remote Connector
if [ "$CHECK_TWINGATE" = "true" ]; then
    if ! pgrep -f -i "twingate" >/dev/null 2>&1; then
        ANOMALIES+=("🛡️ *Twingate Disconnected*: Connector daemon is offline")
    fi
fi

# -----------------------------------------------------------------------------
# Alerting with State Debounce (Avoid spamming Telegram repeatedly)
# -----------------------------------------------------------------------------
if [ ${#ANOMALIES[@]} -gt 0 ]; then
    # Generate anomaly signature
    CURRENT_SIG=$(printf "%s\n" "${ANOMALIES[@]}" | md5)
    LAST_SIG=""
    [ -f "$STATE_FILE" ] && LAST_SIG=$(cat "$STATE_FILE")

    # Only send message if state is new or changed
    if [ "$CURRENT_SIG" != "$LAST_SIG" ]; then
        echo "$CURRENT_SIG" > "$STATE_FILE"

        MSG="⚠️ *Mac mini System Anomaly Detected!*%0A%0A"
        for a in "${ANOMALIES[@]}"; do
            MSG+="${a}%0A"
        done
        MSG+="%0A*Host:* $(hostname) | *Time:* $(date '+%H:%M:%S %Z')"

        if [ -f "$TELEGRAM_SCRIPT" ]; then
            "$TELEGRAM_SCRIPT" "$MSG" "" || true
        fi
        echo "[ALERT] Anomaly reported to Telegram: ${#ANOMALIES[@]} issue(s)"
    else
        echo "[INFO] Anomaly ongoing, alert debounced."
    fi
else
    # System healthy: clear state file so future issues re-alert
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        # Optional recovery notice
        if [ -f "$TELEGRAM_SCRIPT" ]; then
            "$TELEGRAM_SCRIPT" "✅ *Mac mini Systems Recovered:* All services and resource thresholds are back to normal." "" || true
        fi
        echo "[OK] Systems recovered, state cleared."
    else
        echo "[OK] Systems within normal thresholds. No alerts dispatched."
    fi
fi
