#!/usr/bin/env bash
# No "set -e" here on purpose: one failing job must not stop the others
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

args=()
if [ "${1:-}" = "--dry-run" ]; then args=(--dry-run); export DRY_RUN=1; fi

REPORT_DIR_OUT="${REPORT_DIR_OUT:-$BASE_DIR/reports}"
mkdir -p "$REPORT_DIR_OUT"
stamp="$(date +%F_%H%M%S)"
export RUN_LOG="$(mktemp)"
trap 'rm -f "$RUN_LOG"' EXIT

log INFO "########## Automation run $stamp started ##########"
failed=()
for job in health_check log_cleanup server_maintenance; do
  if "$SCRIPT_DIR/$job.sh" "${args[@]}"; then
    log INFO "Job $job: success"
  else
    code=$?
    log ERROR "Job $job failed with exit code $code"
    failed+=("$job")
  fi
done

warns=$(grep -c '\[WARN\]' "$RUN_LOG" || true)
errors=$(grep -c '\[ERROR\]' "$RUN_LOG" || true)

report="$REPORT_DIR_OUT/report-$stamp.txt"
{
  echo "Automation report: $(hostname): $stamp"
  echo "Failed jobs : ${failed[*]:-none}"
  echo "Warnings    : $warns"
  echo "Errors      : $errors"
  echo
  echo "---- Problems found ----"
  grep -E '\[(WARN|ERROR)\]' "$RUN_LOG" || echo "none"
  echo
  echo "---- Full run log ----"
  cat "$RUN_LOG"
} > "$report"
log INFO "Report written: $report"

# Alert only on failed jobs or errors (warnings stay in the report)
if [ "${#failed[@]}" -gt 0 ] || [ "$errors" -gt 0 ]; then
  notify CRITICAL "Automation run found problems (failed: ${failed[*]:-none}, errors: $errors)" \
    "$(grep -E '\[(WARN|ERROR)\]' "$RUN_LOG")"
  exit 1
fi

# Keep 30 days of reports
if [ "$DRY_RUN" != "1" ]; then
  find "$REPORT_DIR_OUT" -name 'report-*.txt' -mtime +30 -delete
fi
log INFO "Run finished: all jobs healthy ($warns warning(s) in report)"
