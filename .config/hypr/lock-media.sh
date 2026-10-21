#!/bin/sh
# Now playing on the lock screen: the shell's player, the one the bar shows and the media keys drive (`qs ipc call bar
# nowPlaying`), shown only while something plays. Paused from the lock screen (its square or the Play/Pause key) it
# stays, so it can be resumed; a player already paused when the screen locked is not shown. hyprlock.conf's widgets:
#   lock-media.sh title    the title (every second: reads the shell's file and keeps the rest for the others)
#   lock-media.sh meta     the artist and the app, in the annotation's voice
#   lock-media.sh button   the play / pause square's picture (a blank one while nothing shows)
#   lock-media.sh toggle   play / pause (the square's click)
#   lock-media.sh reset    forget the last lock's player (lock.sh, as the screen locks and as it unlocks)
# LOCK_MEDIA_INFO=<file> reads the four lines from another file (for a test rig: no player is touched).
now=${XDG_CACHE_HOME:-$HOME/.cache}/swiss-desktop/now-playing
dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/lock-media
img=$HOME/.config/hypr/lock-media
mkdir -p "$dir"

put() { printf '%s\n' "$2" > "$dir/$1.new" && mv -f "$dir/$1.new" "$dir/$1"; }   # whole lines only, for the readers
# hyprlock labels read Pango markup; a line longer than the password field's width (384 px) is cut with an ellipsis
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
fit() { awk -v n="$1" '{ if (length($0) > n) print substr($0, 1, n - 1) "…"; else print }'; }

case ${1:-} in
title)
    # The shell rewrites its player's four lines in this file whenever they change (services/Media.qml nowPlaying),
    # so a read here costs no IPC client (~46 ms of CPU each, every second the screen is locked).
    status= app= title= artist=
    { read -r status; read -r app; read -r title; read -r artist; } 2>/dev/null < "${LOCK_MEDIA_INFO:-$now}"
    app=$(printf '%s\n' "$app" | tr 'A-Z' 'a-z' | sed 's/^mozilla //')
    if [ "$status" = playing ]; then
        : > "$dir/seen"
    elif [ "$status" = paused ] && [ -e "$dir/seen" ]; then
        :
    else
        rm -f "$dir/seen"; put meta ""; put button "$img/none.png"; exit 0
    fi
    mode=; read -r mode 2>/dev/null < "${XDG_STATE_HOME:-$HOME/.local/state}/swiss/mode"
    [ "$mode" = light ] || mode=dark
    # the square shows what a press does: pause while it plays, play while it is paused
    if [ "$status" = playing ]; then put button "$img/pause-$mode.png"; else put button "$img/play-$mode.png"; fi
    meta="${artist:+$artist  ·  }$app"
    [ "$status" = paused ] && meta="$meta  ·  paused"
    put meta "$(printf '%s\n' "$meta" | fit 52 | esc)"
    printf '%s\n' "$title" | fit 40 | esc
    ;;
meta) cat "$dir/meta" 2>/dev/null ;;
button) cat "$dir/button" 2>/dev/null || echo "$img/none.png" ;;
toggle)
    [ -e "$dir/seen" ] || exit 0                     # nothing shown: a click on the blank square does nothing
    if [ -n "${LOCK_MEDIA_INFO:-}" ]; then echo "toggle $(date +%T)" >> "$dir/toggled"
    else qs ipc call bar playPause; fi
    ;;
reset) rm -f "$dir/seen" "$dir/meta" "$dir/button" ;;
*) echo "usage: lock-media.sh title | meta | button | toggle | reset" >&2; exit 2 ;;
esac
