#!/usr/bin/env bash
# Shared helpers: loads settings and provides a timestamped log function
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/settings.conf"
mkdir -p "$LOG_DIR"

log() {
  local level="$1"; shift
  echo "$(date '+%F %T') [$level] $*" | tee -a "$LOG_DIR/automation.log"
}
