#!/bin/sh
# The screens off and on for hypridle.
#   screens.sh off    every output off
#   screens.sh on     every output on
case ${1:-} in
off) wlopm --off '*' ;;
on) wlopm --on '*' ;;
*) echo "usage: screens.sh off | on" >&2; exit 2 ;;
esac
