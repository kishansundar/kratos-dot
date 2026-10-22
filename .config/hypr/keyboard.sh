#!/bin/sh
# The keyboard's light (the Razer BlackWidow X Chroma) for screens.sh: dark while the screens are off, white at 15 %
# (26 of FF) while they are on, as openrgb-lights-off.service (~/nixos/modules/openrgb-lights-off.sh) sets it at boot.
# That service stops the OpenRGB server once done, so this runs OpenRGB itself, looking for the Razer alone (0.3 s; every
# device takes about 10 s): its settings, made in the runtime folder, are the server's detector list
# (/var/lib/OpenRGB/OpenRGB.json) with every detector but the Razer's switched off.
#   keyboard.sh on | off      returns at once; OpenRGB runs in the background
dir=${XDG_RUNTIME_DIR:-/tmp}/keyboard-openrgb

case ${1:-} in
on) colour=262626 ;;
off) colour=000000 ;;
*) echo "usage: keyboard.sh on | off" >&2; exit 2 ;;
esac

mkdir -p "$dir/home"
echo "$colour" > "$dir/want"  # now, so that requests keep their order
(
    flock 9
    # When on and off overlap, the later request wins; hypridle also sends "on" after idle spells with the screens on,
    # so an unchanged colour is skipped.
    colour=$(cat "$dir/want")
    [ "$colour" = "$(cat "$dir/now" 2>/dev/null)" ] && exit 0
    [ -f "$dir/OpenRGB.json" ] || python3 -I -c '
import json, sys
detectors = json.load(open("/var/lib/OpenRGB/OpenRGB.json"))["Detectors"]["detectors"]
detectors = {name: name == "Razer Blackwidow X Chroma" for name in detectors}
json.dump({"Detectors": {"detectors": detectors}}, open(sys.argv[1] + "/OpenRGB.json", "w"), indent=4)' "$dir" || exit 1
    # OpenRGB writes a log under $HOME before it reads --config, and another in the --config folder; neither is kept.
    cd / && HOME=$dir/home openrgb --config "$dir" --noautoconnect -d 0 -m Direct -c "$colour" >/dev/null 2>&1 &&
        echo "$colour" > "$dir/now"
    rm -rf "$dir/logs" "$dir/home/.config/OpenRGB/logs"
) 9> "$dir/lock" &
