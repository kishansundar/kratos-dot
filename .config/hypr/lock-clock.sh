#!/bin/sh
# The lock screen's clock (hyprlock.conf): HH ▎ MM, the bar's ruled clock (~/.config/quickshell/bar/Clock.qml) at
# 128 px. Figures in Geist Bold; between them a red stroke exactly as tall as the figures (Geist Mono's quarter block,
# lifted onto the baseline); the same space on either side of it, measured ink to ink; the hours' first figure flush
# on the page margin. Pango places text by advance, not by ink, so the spaces are sized here from Geist Bold's own side
# bearings (fontTools, Geist 1.7.0): a Geist Bold space is 0.228 em, so one set at size W / 0.228 is W wide.
#   lock-clock.sh RED [HHMM]    RED: hex without "#"; HHMM: for tests (default: now)
# LOCK_DRM=<dir> reads the screens' state from a stand-in for /sys/class/drm (for a test rig).
red=${1:?usage: lock-clock.sh RED [HHMM]}     # hyprlock passes $accent_hex (swiss-build: the one red)
# While every connected screen is off (screens.sh), nobody sees the clock: print nothing and skip the work. Built-ins
# only, so the check costs no process (hyprlock runs this every second, all the time the screen is locked). A screen
# that reports no state counts as on.
dark=
for o in "${LOCK_DRM:-/sys/class/drm}"/card*-*; do
    read -r s 2>/dev/null < "$o/status" && [ "$s" = connected ] || continue
    read -r d 2>/dev/null < "$o/dpms" && [ "$d" = Off ] && dark=1 || { dark=; break; }
done
[ -n "$dark" ] && exit 0
t=${2:-$(date +%H%M)}
exec awk -v t="$t" -v red="$red" 'BEGIN {
    px = 128          # figure size: 96 pt
    gap = 48          # ink to ink on either side of the stroke (the bar: 8 px at 22 px figures)
    lead = 8          # the label starts this far left of the margin; the first figure takes its bearing out of it
    # Geist Bold figures 0-9, in 1/1000 em: left and right side bearings.
    split("44 38 58 44 24 56 44 20 34 34", lsb, " ")
    split("44 105 57 44 44 56 34 0 34 44", rsb, " ")
    # The stroke: Geist Mono Bold U+258E (0.15 em wide, from -0.34 to 0.96 em) set so its height is the cap height
    # (0.71 em of the figures) and lifted by its depth, so it stands on the baseline: 70 px, 10.5 x 91 px.
    sp = px * 0.71 / 1.30
    srise = sp * 0.34
    srsb = sp * 0.45
    h1 = substr(t, 1, 1); h2 = substr(t, 2, 1); m1 = substr(t, 3, 1); m2 = substr(t, 4, 1)
    printf "%s", space(lead - lsb[h1 + 1] * px / 1000)
    printf "<span weight=\"bold\">%s%s</span>", h1, h2
    w = gap - rsb[h2 + 1] * px / 1000
    printf "%s%s", space(px * 0.228), space(w - px * 0.228)
    printf "<span font_family=\"Geist Mono\" weight=\"bold\" size=\"%d\" rise=\"%d\" foreground=\"#%s\">\342\226\216</span>", pu(sp), int(srise * 1024 + 0.5), red
    printf "%s", space(gap - srsb - lsb[m1 + 1] * px / 1000)
    printf "<span weight=\"bold\">%s%s</span>\n", m1, m2
}
# Pango units: 1/1024 pt, at 96 dpi (0.75 pt a pixel), for sizes; a rise is in 1/1024 px.
function pu(x) { return int(x * 0.75 * 1024 + 0.5) }
# A space W px wide (nothing when W < 0.5 px).
function space(w) { return w < 0.5 ? "" : sprintf("<span weight=\"bold\" size=\"%d\"> </span>", pu(w / 0.228)) }'
