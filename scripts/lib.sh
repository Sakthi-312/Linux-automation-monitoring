#!/usr/bin/env bash
# Shared helpers: settings, logging, dry-run wrapper, alerting
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/settings.conf"
# Optional private settings (e.g. SLACK_WEBHOOK_URL). This file is git-ignored.
if [ -f "$BASE_DIR/config/.env" ]; then source "$BASE_DIR/config/.env"; fi
mkdir -p "$LOG_DIR"

log() {
  local level="$1"; shift
  local line
  line="$(date '+%F %T') [$level] $*"
  echo "$line" | tee -a "$LOG_DIR/automation.log"
  # When run_all.sh sets RUN_LOG, also keep a copy for the report
  if [ -n "${RUN_LOG:-}" ]; then echo "$line" >> "$RUN_LOG"; fi
}

DRY_RUN="${DRY_RUN:-0}"
run() {
  if [ "$DRY_RUN" = "1" ]; then
    log DRY "would run: $*"
  else
    "$@"
  fi
}

# notify <severity> <subject> <details>
notify() {
  local severity="$1" subject="$2" details="${3:-}"
  log ALERT "[$severity] $subject"
  if [ "$DRY_RUN" = "1" ]; then
    log DRY "would send alert: $subject"
    return 0
  fi
  echo "$(date '+%F %T') [$severity] $(hostname): $subject" >> "$LOG_DIR/alerts.log"
  if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    local payload
    payload=$(python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1]}))' \
      "*[$severity] $(hostname): $subject*"$'\n'"${details:0:1500}")
    curl -fsS -X POST -H 'Content-type: application/json' --data "$payload" \
      "$SLACK_WEBHOOK_URL" > /dev/null || log WARN "Webhook notification failed"
  fi
}
