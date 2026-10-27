#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

issues=0

# CPU usage over a 1-second sample, read from /proc/stat
cpu_usage() {
  read -r _ u1 n1 s1 i1 w1 q1 sq1 _ < /proc/stat
  sleep 1
  read -r _ u2 n2 s2 i2 w2 q2 sq2 _ < /proc/stat
  local total=$(( (u2+n2+s2+i2+w2+q2+sq2) - (u1+n1+s1+i1+w1+q1+sq1) ))
  local idle=$(( (i2+w2) - (i1+w1) ))
  [ "$total" -eq 0 ] && { echo 0; return; }
  echo $(( 100 * (total - idle) / total ))
}

# Memory used = total minus available
mem_usage() { free | awk '/^Mem:/ {printf "%d", ($2-$7)*100/$2}'; }

# Disk usage of the root filesystem
disk_usage() { df -P "$1" | awk 'NR==2 {gsub("%","",$5); print $5}'; }

check() {   # check <name> <value> <threshold>
  local name="$1" value="$2" limit="$3"
  if [ "$value" -ge "$limit" ]; then
    log WARN "$name at ${value}% (threshold ${limit}%)"
    issues=$((issues + 1))
  else
    log OK "$name at ${value}% (threshold ${limit}%)"
  fi
}

log INFO "===== Health check on $(hostname) ====="
check "CPU"    "$(cpu_usage)"  "$CPU_THRESHOLD"
check "Memory" "$(mem_usage)"  "$MEM_THRESHOLD"
for p in $DISK_PATHS; do
  check "Disk $p" "$(disk_usage "$p")" "$DISK_THRESHOLD"
done

# Load average compared with the number of CPU cores
load=$(cut -d' ' -f1 /proc/loadavg)
cores=$(nproc)
log INFO "Load average (1 min): $load on $cores cores"

# Services: a process with this exact name must be running
for svc in $SERVICES; do
  if pgrep -x "$svc" > /dev/null; then
    log OK "Service $svc is running"
  else
    log WARN "Service $svc is NOT running"
    issues=$((issues + 1))
  fi
done

if [ "$issues" -gt 0 ]; then
  log WARN "Health check finished with $issues issue(s)"
  exit 1
fi
log INFO "Health check finished: all checks passed"
