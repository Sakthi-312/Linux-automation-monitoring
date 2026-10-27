#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi
if [ "$DRY_RUN" = "1" ]; then log INFO "DRY-RUN mode: nothing will be changed"; fi

log INFO "===== Server maintenance on $(hostname) ====="

# ---- 1. Pending package updates (report only) ----
log INFO "--- 1. Pending package updates ---"
if command -v apt > /dev/null 2>&1; then
  pending=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable' || true)
  security=$(apt list --upgradable 2>/dev/null | grep -ci 'security' || true)
  if [ "$pending" -gt 0 ]; then
    log WARN "$pending package(s) can be upgraded ($security security). Run: sudo apt update && sudo apt upgrade"
  else
    log OK "System is up to date (as of the last 'apt update')"
  fi
else
  log INFO "apt not found, skipping update check"
fi

# ---- 2. Temp file cleanup (only your own old files) ----
log INFO "--- 2. Temp file cleanup (older than ${TMP_RETENTION_DAYS}d) ---"
removed=0
for dir in $TMP_DIRS; do
  case "$dir" in
    ""|"/"|"/etc"|"/usr"|"/bin"|"/sbin"|"/lib"|"/home"|"/root"|"/var"|"/boot")
      log ERROR "Refusing to clean unsafe directory: '$dir'"
      exit 2 ;;
  esac
  [ -d "$dir" ] || { log WARN "Directory not found: $dir"; continue; }
  while IFS= read -r -d '' f; do
    run rm -f -- "$f"
    removed=$((removed + 1))
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -user "$(id -un)" -mtime +"$TMP_RETENTION_DAYS" -print0)
done
log INFO "Temp cleanup: $removed file(s) removed"

# ---- 3. Disk usage report ----
log INFO "--- 3. Disk usage ---"
df -h / | awk 'NR==2 {print "Root filesystem: " $3 " used of " $2 " (" $5 ")"}' | while read -r line; do log INFO "$line"; done
log INFO "Largest folders in $REPORT_DIR:"
report=$( { du -xh --max-depth=1 "$REPORT_DIR" 2>/dev/null || true; } | sort -rh | sed -n '1,6p')
while IFS= read -r line; do log INFO "   $line"; done <<< "$report"

# ---- 4. Config backup ----
log INFO "--- 4. Config backup ---"
files=()
for f in $BACKUP_SOURCES; do
  if [ -r "$f" ]; then files+=("$f"); else log WARN "Skipping (missing or unreadable): $f"; fi
done
if [ "${#files[@]}" -gt 0 ]; then
  run mkdir -p "$BACKUP_DIR"
  archive="$BACKUP_DIR/config-$(date +%F_%H%M%S).tar.gz"
  run tar -czf "$archive" "${files[@]}" 2>/dev/null
  if [ "$DRY_RUN" = "1" ]; then log INFO "Backup would be created: $archive (${#files[@]} files)"; else log INFO "Backup created: $archive (${#files[@]} files)"; fi
  # keep only the newest N backups
  while IFS= read -r old; do
    run rm -f -- "$old"
    log INFO "Removed old backup: $old"
  done < <( { ls -1t "$BACKUP_DIR"/config-*.tar.gz 2>/dev/null || true; } | tail -n +"$((BACKUP_KEEP + 1))")
else
  log WARN "No readable files to back up"
fi

log INFO "Maintenance finished"
