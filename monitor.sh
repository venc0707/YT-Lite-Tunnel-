#!/bin/bash
set -euo pipefail

# ==========================================================
# КОНФИГ
# ==========================================================

LOCATION="Russia"
TRAFFIC_LIMIT_TB=3
LIMIT_THRESHOLD_PERCENT=99
VPN_SERVICE="xray"
NET_IFACE="eth0"
REPO_DIR="/opt/vpn-metrics"
JSON_FILE="$REPO_DIR/metrics.json"
ALERTS_FILE="$REPO_DIR/alerts.log"
GIT_BRANCH="main"

# ==========================================================
# 1. Нагрузка CPU
# ==========================================================

LOAD_PERCENT=$(mpstat 1 1 | awk '/Average/ {printf "%.0f", 100 - $NF}')

# ==========================================================
# 2. Трафик за месяц через vnstat
# ==========================================================

VNSTAT_JSON=$(vnstat -i "$NET_IFACE" --json m)

TRAFFIC_USED_BYTES=$(echo "$VNSTAT_JSON" | python3 -c '
import json, sys, datetime
data = json.load(sys.stdin)
iface = data["interfaces"][0]
months = iface["traffic"]["month"]
now = datetime.datetime.now()
used = 0
for m in months:
    if m["date"]["year"] == now.year and m["date"]["month"] == now.month:
        used = m["rx"] + m["tx"]
        break
print(used)
')

TRAFFIC_USED_TB=$(python3 -c "print(round($TRAFFIC_USED_BYTES / 1024**4, 3))")
TRAFFIC_LIMIT_BYTES=$(python3 -c "print($TRAFFIC_LIMIT_TB * 1024**4)")
TRAFFIC_REMAINING_TB=$(python3 -c "print(round(($TRAFFIC_LIMIT_BYTES - $TRAFFIC_USED_BYTES) / 1024**4, 3))")
TRAFFIC_PERCENT_USED=$(python3 -c "print(round(100 * $TRAFFIC_USED_BYTES / $TRAFFIC_LIMIT_BYTES, 1))")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ==========================================================
# 3. Проверка лимита -> остановка VPN
# ==========================================================

LIMIT_EXCEEDED="false"
ACTION_TAKEN="none"

IS_OVER_LIMIT=$(python3 -c "print('yes' if $TRAFFIC_PERCENT_USED >= $LIMIT_THRESHOLD_PERCENT else 'no')")

if [ "$IS_OVER_LIMIT" = "yes" ]; then
    LIMIT_EXCEEDED="true"
    if systemctl is-active --quiet "$VPN_SERVICE"; then
        systemctl stop "$VPN_SERVICE"
        ACTION_TAKEN="vpn_stopped"
        echo "[$TIMESTAMP] LIMIT EXCEEDED (${TRAFFIC_PERCENT_USED}%) — VPN service '$VPN_SERVICE' stopped" >> "$ALERTS_FILE"
    else
        ACTION_TAKEN="already_stopped"
    fi
fi

# ==========================================================
# 4. Статус VPN
# ==========================================================

if systemctl is-active --quiet "$VPN_SERVICE"; then
    STATUS="online"
else
    STATUS="offline"
fi

# ==========================================================
# 5. Пишем JSON
# ==========================================================

cat > "$JSON_FILE" <<EOF
{
  "status": "$STATUS",
  "location": "$LOCATION",
  "load_percent": $LOAD_PERCENT,
  "traffic": {
    "used_tb": $TRAFFIC_USED_TB,
    "limit_tb": $TRAFFIC_LIMIT_TB,
    "remaining_tb": $TRAFFIC_REMAINING_TB,
    "percent_used": $TRAFFIC_PERCENT_USED
  },
  "limit_exceeded": $LIMIT_EXCEEDED,
  "action_taken": "$ACTION_TAKEN",
  "updated_at": "$TIMESTAMP"
}
EOF

# ==========================================================
# 6. Пуш в git
# ==========================================================

cd "$REPO_DIR"
git pull --no-rebase origin "$GIT_BRANCH" --quiet || echo "[$TIMESTAMP] WARNING: git pull failed" >> "$ALERTS_FILE"

if [ -n "$(git status --porcelain metrics.json alerts.log 2>/dev/null)" ]; then
    git add metrics.json alerts.log 2>/dev/null || git add metrics.json
    COMMIT_MSG="metrics: $TIMESTAMP"
    if [ "$ACTION_TAKEN" = "vpn_stopped" ]; then
        COMMIT_MSG="ALERT: traffic limit exceeded, VPN stopped — $TIMESTAMP"
    fi
    git commit -m "$COMMIT_MSG" --quiet
    git push origin "$GIT_BRANCH" --quiet
    echo "[$TIMESTAMP] metrics updated and pushed ($ACTION_TAKEN)"
else
    echo "[$TIMESTAMP] no changes, skip push"
fi
