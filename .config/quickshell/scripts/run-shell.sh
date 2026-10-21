#!/bin/sh
# Starts the shell and starts it again if it crashes (mango's autostart.sh runs this). A deliberate stop (exit 0,
# or SIGTERM / SIGINT: `kill`, Ctrl+C) ends the loop; a crash (any other exit) restarts it after a second. Five
# crashes within a minute stop the loop rather than spin: the bar then stays away until the next login or until
# this is run again.
log=${XDG_STATE_HOME:-$HOME/.local/state}/swiss/shell-crashes.log
mkdir -p "$(dirname "$log")"
crashes=""
while :; do
    # The session's QT_QPA_PLATFORMTHEME=gtk3 (~/nixos/modules/theme.nix) stays, so the apps the launcher and the dock
    # start inherit it; but under it Quickshell finds no icons at all (iconPath comes back empty) unless its icon theme
    # is pinned: hicolor, what it used without the variable. Checked 16 October 2026 in the nested harness: bar, dock
    # and launcher pixel for pixel the same with and without the variable.
    QS_ICON_THEME=hicolor quickshell "$@"
    code=$?
    case $code in 0|130|143) exit 0 ;; esac
    now=$(date +%s)
    echo "$(date -Iseconds) quickshell exited with $code; restarting" >> "$log"
    crashes=$(for t in $crashes $now; do [ $((now - t)) -lt 60 ] && echo "$t"; done)
    [ "$(echo "$crashes" | wc -w)" -ge 5 ] && { echo "$(date -Iseconds) five crashes in a minute; giving up" >> "$log"; exit 1; }
    sleep 1
done
