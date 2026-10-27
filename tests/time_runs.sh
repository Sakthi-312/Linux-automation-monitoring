#!/usr/bin/env bash
# Times N runs of run_all.sh and prints each run plus the median
N=${1:-5}
times=()
for i in $(seq "$N"); do
  s=$(date +%s.%N)
  "$(dirname "$0")/../scripts/run_all.sh" > /dev/null 2>&1
  e=$(date +%s.%N)
  t=$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.2f", e-s}')
  echo "run $i: ${t}s"
  times+=("$t")
done
printf '%s\n' "${times[@]}" | sort -n | awk '{a[NR]=$1} END {printf "median: %.1f s\n", a[int((NR+1)/2)]}'
