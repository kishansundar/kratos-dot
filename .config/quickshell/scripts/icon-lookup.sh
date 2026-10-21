#!/bin/sh
# icon-lookup.sh THEME NAME...: the file of each icon NAME in icon theme THEME, one line each (empty when there is
# none), found as the freedesktop icon spec does it: THEME, then the themes it inherits, then hicolor; in each, the
# 48 px drawing first (the dock's size), then a scalable one, then the nearest larger. For the dock's trash: the shell
# sets no icon theme of its own (app icons are the apps' own, from hicolor), so it asks for GTK's here.
theme=$1; shift

dirs="${XDG_DATA_HOME:-$HOME/.local/share}/icons $HOME/.icons"
for d in $(printf %s "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' '); do dirs="$dirs $d/icons"; done

# THEME and what it inherits, breadth first, each once; hicolor last.
chain=""; queue=$theme
while [ -n "$queue" ]; do
    t=${queue%%,*}
    case $queue in *,*) queue=${queue#*,} ;; *) queue="" ;; esac
    case " $chain hicolor " in *" $t "*) continue ;; esac
    chain="$chain $t"
    for d in $dirs; do
        [ -f "$d/$t/index.theme" ] || continue
        inherits=$(sed -n 's/^Inherits *= *//p' "$d/$t/index.theme" | head -n 1 | tr -d ' ')
        [ -n "$inherits" ] && queue="${queue:+$queue,}$inherits"
        break
    done
done
chain="$chain hicolor"

for name in "$@"; do
    found=""
    for t in $chain; do
        for d in $dirs; do
            [ -d "$d/$t" ] || continue
            for sub in '48x48/*' '*/48' 'scalable/*' '*/scalable' '64x64/*' '*/64' '96x96/*' '*/96' '128x128/*' '256x256/*'; do
                for f in "$d/$t"/$sub/"$name".svg "$d/$t"/$sub/"$name".png; do
                    [ -f "$f" ] && { found=$f; break 4; }
                done
            done
        done
    done
    echo "$found"
done
