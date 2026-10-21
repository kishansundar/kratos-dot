#!/bin/sh
# Every check that can run without touching the live desktop. Run after changing a token, template or config.
#   1. swiss-build: all templates build and name only known tokens
#   2. contrast:    every pairing meets WCAG 2.1 AA in both modes
#   3. mango:       the config and the colour file it sources parse
#   4. links:       every file the apps read through build/ exists
root=$(cd "$(dirname "$0")/.." && pwd)
status=0
step() { printf '== %s\n' "$1"; }

# swiss-build without its two live effects: no mango reload (it wakes a screen hypridle turned off) and no copy into
# ~/nixos (that is for a real build).
step "build";    SWISS_NIXOS_MODULES=/nonexistent MANGO_INSTANCE_SIGNATURE= "$root/bin/swiss-build" || status=1
step "contrast"; "$root/tests/contrast.sh" | grep -v ' ok ' ; "$root/tests/contrast.sh" >/dev/null && echo "all pairs pass" || status=1
step "mango";    out=$(mango -p -c "$HOME/.config/mango/config.conf" 2>&1); [ -z "$out" ] && echo "config ok" || { echo "$out"; status=1; }
step "links"     # every app's link into build/ resolves (found, not listed: a new consumer is checked too)
links=$(find "$HOME/.config" -maxdepth 4 -lname '*swiss-desktop/build/*' 2>/dev/null)
broken=$(printf '%s\n' "$links" | while read -r f; do [ -n "$f" ] && [ ! -e "$f" ] && echo "$f"; done)
[ -e "$root/build/current/hyprlock-colors.conf" ] || broken="$broken $root/build/current/hyprlock-colors.conf"
[ -z "$broken" ] && echo "$(printf '%s\n' "$links" | grep -c .) links ok" || { echo "MISSING $broken"; status=1; }
exit $status
