#!/usr/bin/env bash
# Shared helpers: loads settings and provides a timestamped log function
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/settings.conf"
mkdir -p "$LOG_DIR"

log() {
  local level="$1"; shift
  echo "$(date '+%F %T') [$level] $*" | tee -a "$LOG_DIR/automation.log"
}

# Dry-run helper: prints the command instead of running it when DRY_RUN=1
DRY_RUN="${DRY_RUN:-0}"
run() {
  if [ "$DRY_RUN" = "1" ]; then
    log DRY "would run: $*"
  else
    "$@"
  fi
}
