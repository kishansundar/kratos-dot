#!/bin/sh
# The bar's 24-hour ruler in 49 columns (two per hour): the day so far in the one red, the hours to come in grey (8),
# a tick every hour, long ticks at 00 / 06 / 12 / 18 / 24, and the red index mark at now.
set -- $(date '+%H %M')
now=$(( (${1#0} * 60 + ${2#0} + 15) / 30 ))
red='\033[38;2;233;63;32m' grey='\033[90m'
line="$red" i=0
while [ $i -le 48 ]; do
  if [ $i -eq 0 ]; then c='├'; elif [ $i -eq 48 ]; then c='┤'
  elif [ $((i % 12)) -eq 0 ]; then c='┼'; elif [ $((i % 2)) -eq 0 ]; then c='┴'; else c='─'; fi
  [ $i -eq $now ] && c='╂'
  [ $i -eq $((now + 1)) ] && line="$line$grey"
  line="$line$c" i=$((i + 1))
done
printf "$line\033[0m\n"
