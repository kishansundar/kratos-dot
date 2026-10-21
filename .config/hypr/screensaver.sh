#!/bin/sh
# The screensaver: the matrix rain (cmatrix) full screen, started by hypridle after a while without input and stopped by
# the first input (hypridle.conf). Always in Dark Mode's colours, whatever the desktop's mode (a resting screen stays
# dark): the rain in grey, each falling head in chalk, on the dark ground, from ~/.config/swiss-desktop/tokens/dark.env.
# mango's rule for app_id "screensaver" (~/.config/mango/rule.conf) makes it full screen and solid.
#   screensaver.sh start | stop
pidfile=${XDG_RUNTIME_DIR:-/tmp}/swiss-screensaver.pid
tokens=$HOME/.config/swiss-desktop/tokens/dark.env
tok() { sed -n "s/^$1=//p" "$tokens"; }

case $1 in
start)
    # One at a time.
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then exit 0; fi
    kitty --class screensaver \
        -o background_opacity=1 -o window_padding_width=0 -o mouse_hide_wait=0.5 -o font_size=14 \
        -o background="#$(tok background)" -o foreground="#$(tok text)" \
        -o color7="#$(tok text2)" -o color15="#$(tok text)" \
        cmatrix -s -b -u 6 -C white &
    echo $! > "$pidfile"
    ;;
stop)
    [ -f "$pidfile" ] && kill "$(cat "$pidfile")" 2>/dev/null
    rm -f "$pidfile"
    ;;
*)
    echo "usage: screensaver.sh start | stop" >&2
    exit 2
    ;;
esac
