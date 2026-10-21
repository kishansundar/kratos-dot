#!/bin/sh
# Checks WCAG 2.1 contrast for every token pairing the desktop actually draws, in both modes.
# 4.5 = normal text, 3.0 = large/bold text, borders, focus rings and other non-text marks.
# A fourth field limits a pairing to one mode. The terminal's text-on-colour pairs differ by mode: in Light Mode white
# (ansi7) is a light ground, so white text on colours 1-6 and on bright black must read; in Dark Mode the colours are
# light, so black text (ansi0) on them must read, and white is a light grey that must read as text on graphite.
# Exit status 1 if any pairing falls short.
root=$(cd "$(dirname "$0")/.." && pwd)
status=0
for mode in light dark; do
    awk -v mode="$mode" '
        function lin(c) { c /= 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
        function hx(s, i) { return index("0123456789ABCDEF", toupper(substr(s, i, 1))) - 1 }
        function lum(h) { return 0.2126 * lin(hx(h,1)*16 + hx(h,2)) + 0.7152 * lin(hx(h,3)*16 + hx(h,4)) + 0.0722 * lin(hx(h,5)*16 + hx(h,6)) }
        function ratio(a, b,   x, y) { x = lum(a); y = lum(b); return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05) }
        FNR == NR { if ($0 ~ /^[a-z0-9_]+=/) { split($0, kv, "="); t[kv[1]] = kv[2] } next }
        /^[a-z]/ {
            if ($4 != "" && $4 != mode) next
            r = ratio(t[$1], t[$2]); ok = r >= $3
            printf "%-5s %-4s %-14s on %-12s %5.2f (min %s)\n", mode, ok ? "ok" : "FAIL", $1, $2, r, $3
            if (!ok) bad = 1
        }
        END { exit bad }
    ' "$root/tokens/$mode.env" - <<'PAIRS' || status=1
text background 4.5
text surface 4.5
text surface2 4.5
text elevated 4.5
text selection 4.5
text2 background 4.5
text2 surface 4.5
text2 surface2 4.5
muted background 4.5
muted surface 4.5
muted surface2 4.5
text2 elevated 4.5
muted elevated 4.5
accent background 4.5
accent surface 4.5
accent_fg accent_fill 4.5
accent_fill background 3.0
accent_fill surface 3.0
text2 background 3.0
border_strong background 3.0
border_strong surface 3.0
success background 4.5
warning background 4.5
warning surface 4.5
error background 4.5
info background 4.5
ansi1 background 4.5
ansi2 background 4.5
ansi3 background 4.5
ansi4 background 4.5
ansi5 background 4.5
ansi6 background 4.5
ansi7 background 4.5 dark
ansi8 background 4.5
ansi9 background 4.5
ansi10 background 4.5
ansi11 background 4.5
ansi12 background 4.5
ansi13 background 4.5
ansi14 background 4.5
ansi15 background 4.5
ansi7 ansi1 4.5 light
ansi7 ansi2 4.5 light
ansi7 ansi3 4.5 light
ansi7 ansi4 4.5 light
ansi7 ansi5 4.5 light
ansi7 ansi6 4.5 light
ansi7 ansi8 4.5 light
ansi0 ansi1 4.5 dark
ansi0 ansi2 4.5 dark
ansi0 ansi3 4.5 dark
ansi0 ansi4 4.5 dark
ansi0 ansi5 4.5 dark
ansi0 ansi6 4.5 dark
PAIRS
done
exit $status
