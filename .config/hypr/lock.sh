#!/bin/sh
# The lock screen for this Wayland display only: one lock file per display, $XDG_RUNTIME_DIR/hyprlock-<display>.lock,
# held by flock for as long as hyprlock runs. A test rig's hyprlock (another display) no longer counts as "locked" here,
# as it did with `pidof hyprlock`. The variables live in this script and not in hypridle.conf: hypridle's config
# language substitutes environment variables itself, and a variable whose name is a prefix of another (W, for
# WAYLAND_DISPLAY) broke the path there (found 15 October 2026).
#   lock.sh start    start hyprlock unless this display already has one (hypridle's lock_cmd, mango's autostart.sh);
#                    if hyprlock fails or crashes, it runs again, three runs at most (an open desktop is the failure
#                    that matters, after an autologin boot above all)
#   lock.sh locked   succeed while this display's hyprlock runs (hypridle's "screen off while locked" step)
lockfile=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hyprlock-${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is not set}.lock
case ${1:-} in
# lock-media.sh forgets the last lock's player as this one starts and as it ends: the lock shows a player only once it
# has seen it play (a tab paused before the screen locked stays off it)
start) exec flock -n "$lockfile" sh -c 'm=$HOME/.config/hypr/lock-media.sh; "$m" reset
    for run in 1 2 3; do hyprlock && break; echo "lock.sh: hyprlock exited $? (run $run of 3)" >&2; sleep 1; done
    "$m" reset' ;;
locked) ! flock -n "$lockfile" true ;;
*) echo "usage: lock.sh start | locked" >&2; exit 2 ;;
esac
