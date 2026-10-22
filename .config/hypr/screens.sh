#!/bin/sh
# The screens off and on for hypridle, the keyboard's light with them (keyboard.sh).
#   screens.sh off    every output off, the keyboard dark
#   screens.sh on     every output on, the keyboard white
case ${1:-} in
off) wlopm --off '*'; ~/.config/hypr/keyboard.sh off ;;
on) wlopm --on '*'; ~/.config/hypr/keyboard.sh on ;;
*) echo "usage: screens.sh off | on" >&2; exit 2 ;;
esac
