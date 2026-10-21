#!/bin/sh
# Idle cost of the desktop: CPU time and memory of mango and quickshell over a window (default 60 s).
#   tests/measure.sh [seconds]
# Reads /proc only; run it with the desktop idle for comparable numbers.
secs=${1:-60}
hz=$(getconf CLK_TCK)
ticks() { awk '{print $14 + $15}' "/proc/$1/stat"; }
# Only the processes of the seat0 (graphical) login session, not test instances started elsewhere.
session=$(loginctl list-sessions --no-legend | awk '$4 == "seat0" { print $1; exit }')
scope=$(loginctl show-session "$session" -p Scope --value)
pids=$(for p in $(pgrep -u "$(id -u)" -x mango; pgrep -u "$(id -u)" -f '/bin/quickshell$'); do
    grep -q "$scope" "/proc/$p/cgroup" 2>/dev/null && echo "$p"
done)
for p in $pids; do eval "t0_$p=$(ticks "$p")"; done
sleep "$secs"
printf '%-12s %8s %10s\n' process "cpu %" "rss MiB"
for p in $pids; do
    eval "t0=\$t0_$p"
    t1=$(ticks "$p")
    rss=$(awk '/VmRSS/ {print $2}' "/proc/$p/status")
    awk -v n="$(cat /proc/$p/comm)" -v d=$((t1 - t0)) -v hz="$hz" -v s="$secs" -v r="$rss" \
        'BEGIN { printf "%-12s %8.2f %10.1f\n", n, 100 * d / hz / s, r / 1024 }'
done
