# Measurements

Date: 2026-10-27
Machine: Ubuntu on WSL2, 12 cores

## Scripted routine (scripts/run_all.sh, includes health check, log cleanup, maintenance, report)
Five runs: 8.20s, 4.15s, 4.03s, 4.03s, 4.09s
Median: 4.1s (first run is slower because the disk cache is cold)

## Manual routine (typed by hand, same tasks)
Run 1: __ min __ s
Run 2: __ min __ s
Run 3: __ min __ s
Median: __

## Result
Reduction: (manual median - scripted median) / manual median x 100 = __%
