#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

DRY_RUN="${DRY_RUN:-0}"
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

# In dry-run mode, print the command instead of running it
run() {
  if [ "$DRY_RUN" = "1" ]; then
    log DRY "would run: $*"
  else
    "$@"
  fi
}

dir_bytes() { du -sb "$1" | cut -f1; }

deleted=0
compressed=0
freed=0

[ "$DRY_RUN" = "1" ] && log INFO "DRY-RUN mode: nothing will be changed"
log INFO "===== Log cleanup started (retention ${LOG_RETENTION_DAYS}d, compress after ${COMPRESS_AFTER_DAYS}d) ====="

for dir in $CLEANUP_DIRS; do
  # Safety: never touch system directories
  case "$dir" in
    ""|"/"|"/etc"|"/usr"|"/bin"|"/sbin"|"/lib"|"/home"|"/root"|"/var"|"/boot")
      log ERROR "Refusing to clean unsafe directory: '$dir'"
      exit 2 ;;
  esac
  if [ ! -d "$dir" ]; then
    log WARN "Directory not found, skipping: $dir"
    continue
  fi

  before=$(dir_bytes "$dir")
  log INFO "Cleaning $dir"

  # 1. Delete logs and archives older than the retention period
  while IFS= read -r -d '' f; do
    run rm -f -- "$f"
    deleted=$((deleted + 1))
  done < <(find "$dir" -maxdepth 1 -type f \( -name '*.log' -o -name '*.gz' \) -mtime +"$LOG_RETENTION_DAYS" -print0)

  # 2. Compress remaining .log files older than the compress threshold
  while IFS= read -r -d '' f; do
    run gzip -f -- "$f"
    compressed=$((compressed + 1))
  done < <(find "$dir" -maxdepth 1 -type f -name '*.log' -mtime +"$COMPRESS_AFTER_DAYS" -print0)

  after=$(dir_bytes "$dir")
  freed=$((freed + before - after))
done

log INFO "Cleanup finished: $deleted deleted, $compressed compressed, $(numfmt --to=iec "$freed") freed"
