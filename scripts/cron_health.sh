#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

COOLDOWN_MIN=${ALERT_COOLDOWN_MIN:-60}
STATE="$LOG_DIR/.last_health_alert"

if out=$("$SCRIPT_DIR/health_check.sh" 2>&1); then
  rm -f "$STATE"            # recovered: the next problem alerts immediately
  exit 0
fi

# Unhealthy. Alert unless we already alerted within the cooldown window.
if [ -f "$STATE" ] && [ -z "$(find "$STATE" -mmin +"$COOLDOWN_MIN")" ]; then
  log INFO "Health problem persists; alert suppressed (cooldown ${COOLDOWN_MIN}m)"
  exit 1
fi
touch "$STATE"
notify CRITICAL "Health check failed" "$(echo "$out" | grep -E '\[(WARN|ERROR)\]')"
exit 1
