#!/bin/sh
# Screenshots (mango's binds call this by path):
#   screenshot.sh region   drag a box, or click a window (its content, inside the border) or the bare desktop (the
#                          whole screen); Esc cancels and nothing happens
#   screenshot.sh window   the focused window's content (the screen when no window has the focus)
#   screenshot.sh screen   the focused monitor
# Each shot is copied to the clipboard (PNG), saved as ~/Pictures/Screenshots/<date time>.png and shown in a
# notification with its size (the picture is its image: the toast is text only, the notifications panel shows it).
#
# The selection is drawn the Swiss way: the screen under a veil of the mode's ground; the window under the pointer
# (or the whole screen, over the bare desktop) comes out of it clear, ruled in the one red at 1 px with its size beside
# it in Geist Mono, and so does a box being dragged (slurp's own drawing, coloured from the mode's palette.json, so
# it follows light / dark). slurp fills the boxes it is given with -B instead of the veil (-b covers only what lies
# outside them), so -B is the veil too: every window under one veil, as the rest (tried in the rig).
#
# A test rig points this elsewhere: SWISS_SHOT_DIR (where shots are saved), SWISS_DESKTOP_DIR (the palettes),
# XDG_STATE_HOME (the mode), SWISS_MANGO_CONF (where border_px is read). mmsg, grim and slurp follow the
# environment's WAYLAND_DISPLAY / MANGO_INSTANCE_SIGNATURE, the notification its DBUS_SESSION_BUS_ADDRESS.
set -u
what=${1:-region}
desktop=${SWISS_DESKTOP_DIR:-$HOME/.config/swiss-desktop}
mode=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/swiss/mode" 2>/dev/null || echo dark)
case $mode in light|dark) ;; *) mode=dark ;; esac
dir=${SWISS_SHOT_DIR:-$HOME/Pictures/Screenshots}

# One read of mango and the palette. Prints shell assignments: the focused monitor (name and box), the focused
# window's content box, the slurp colours, and in `boxes` one line per window visible on that monitor, its content
# box (mango's x / y / width / height include the border) labelled with its app id; floating windows first, as they
# lie on top, and the monitor itself last, so a click on the bare desktop takes the whole screen.
eval "$(python3 -I - "$(mmsg get all-monitors)" "$(mmsg get all-clients)" "$desktop/build/$mode/palette.json" \
        "${SWISS_MANGO_CONF:-$HOME/.config/mango/config.conf}" <<'EOF'
import json, re, shlex, sys
monitors, clients, palette, conf = sys.argv[1:5]
def q(k, v): print(f"{k}={shlex.quote(str(v))}")
try: border = int(re.search(r"^\s*border_px\s*=\s*(\d+)", open(conf).read(), re.M).group(1))
except Exception: border = 1
try: p = json.load(open(palette))
except Exception: p = {}
hexa = lambda c, a: (c.lstrip("#")[:6] + a).lower()
q("veil", "#" + hexa(p.get("background", "#0d0d0d"), "73"))     # the ground at 45 %
q("rule", "#" + hexa(p.get("accentFill", "#e93f20"), "ff"))     # the one red
try: mons = json.loads(monitors)["monitors"]
except Exception: mons = []
mon = next((m for m in mons if m.get("active")), mons[0] if mons else None)
if mon is None: sys.exit(0)
q("mon", mon["name"])
q("mongeo", f'{mon["x"]},{mon["y"]} {mon["width"]}x{mon["height"]}')
try: cs = json.loads(clients)["clients"]
except Exception: cs = []
def inner(c):
    b = 0 if c.get("is_fullscreen") else border      # a fullscreen window has no border
    w, h = c["width"] - 2 * b, c["height"] - 2 * b
    return f'{c["x"] + b},{c["y"] + b} {w}x{h}' if w > 0 and h > 0 else None
shown = [c for c in cs if c.get("monitor") == mon["name"] and c.get("is_visible") and not c.get("is_minimized")]
shown.sort(key=lambda c: not (c.get("is_floating") or c.get("is_fullscreen")))
lines = [f'{g} {c.get("appid") or "window"}' for c in shown if (g := inner(c))]
lines.append(f'{mon["x"]},{mon["y"]} {mon["width"]}x{mon["height"]} screen')
q("boxes", "\n".join(lines))
focus = next((c for c in cs if c.get("is_focused") and c.get("is_visible")), None)
q("wingeo", inner(focus) if focus else "")
EOF
)" || exit 1
[ -n "${mon:-}" ] || exit 1

case $what in
    region)
        geo=$(printf '%s\n' "$boxes" | slurp -d -F "Geist Mono" -w 1 -c "$rule" -b "$veil" -s "#00000000" -B "$veil" 2> /dev/null) \
            || exit 0 ;;
    window)
        geo=$wingeo
        [ -n "$geo" ] || geo=$mongeo ;;
    screen)
        geo=$mongeo ;;
    *)
        echo "usage: screenshot.sh region|window|screen" >&2; exit 2 ;;
esac

mkdir -p "$dir"
base="$dir/$(date '+%Y-%m-%d %H.%M.%S')"
file="$base.png"
n=2
while [ -e "$file" ]; do file="$base $n.png"; n=$((n + 1)); done
grim -g "$geo" "$file" || exit 1
wl-copy -t image/png < "$file"

size=${geo#* }
case $dir in "$HOME"/*) where="~/${dir#"$HOME"/}" ;; *) where=$dir ;; esac
# `--` ends busctl's options, so the expiry -1 (the server's default) is not read as one.
busctl --user -- call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications \
    Notify 'susssasa{sv}i' "Screenshot" 0 "" "Screenshot" "${size%x*} × ${size#*x} · copied · in $where" \
    0 1 image-path s "$file" -1 > /dev/null 2>&1
exit 0
