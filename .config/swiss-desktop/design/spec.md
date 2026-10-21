# Measure: the design of this desktop

The shell is drawn as a precision instrument. Two motifs carry everything:

- **The ruler**: a hairline with ticks. The bar's lower edge is a 24-hour ruler across the screen; every popover
  heading starts with a short ruler; sliders are rulers.
- **The index mark**: a short vertical red stroke. It means *now / here* and nothing else: the current time of day
  on the ruler, the current workspace, the clock's separator, the selected row, a slider's position, the control
  whose popover is open, and that popover's origin (the mark runs from the control through the ruler into the card).

Two layers of type: **Geist** for content (what you read), **Geist Mono** for annotations (what you measure: indices,
ids, week numbers, counts, key hints), always smaller and quieter (IBM Plex Sans and JetBrains Mono until 16 October
2026; the roles, sizes and where each surface sets them: README, "Type").

## The bar (36 px, one baseline 25 px from the top)

```
1 /5  ı ▪ ı ı ı   kitty  Swiss design…          W42  21 ┃ 06  Wednesday          ▫ ▫ │  ᛒ ≋ 🔈 0 🔔 │ NixDesk
├─────┼─────┼─────┼─────┼─────┼─────┼──── 24-hour ruler ────┼─────┼─────┼────▌────┼─────┼─────┼─────┤
```

| Part | Design |
|---|---|
| Folio | the current workspace as a 21 px semibold numeral (the clock's hours rhyme with it), "/5" as an annotation, then one tick per workspace standing on the baseline: 14 px = has windows, 5 px = empty, 18 px red = current, amber = urgent |
| Context | the focused app id as an annotation, then its title in secondary sans; only as wide as the space before the clock allows |
| Clock | hours semibold, minutes regular, the red stroke between them sitting exactly on the screen's centre line (positioned by the stroke, not by the group); left flank week over year (mono), right flank day over date (sans), both on two baselines |
| Right | three groups, quietest first, separated by 14 px hairlines: apps (tray, grey until hovered), system (night light and Bluetooth only while on, Wi-Fi, volume + value, bell + red count), machine (the hostname, which opens the session menu) |
| Ruler | full-width hairline; a tick per hour (3 px), longer at 00 / 06 / 12 / 18 (7 px); the red now-mark (11 px) moves once a minute |

Everything on the right has a fixed width, so values never push the layout around.

## Surfaces

Popovers hang from the ruler (no gap), square, with a hairline edge and 16 px padding, and carry the red origin mark
on their top edge. Headings: title in Geist DemiBold 20 (h2), an annotation on the right, then the ruler start (five ticks).
Selected rows: the selection tint and the red index along the left edge. Key hints close each popover, as annotations.
The launcher numbers its rows 1-9 (Alt+number opens that row). Notifications start with an annotation
(`helium · 21:05`; `critical ·` in red plus the red edge for critical ones). The volume pop-up shows the value as a
large numeral beside a ruler. The lock screen repeats the bar's ruled clock at 128 px (Geist Bold; the hours' first figure on a 48 px margin; the
red stroke as tall as the figures, 48 px either side ink to ink, placed by `~/.config/hypr/lock-clock.sh` from the
font's side bearings), with the ruler start under the date and a 384 x 48 password field on the 8 px grid.

## Colour

| Token | Dark: graphite and chalk | Light: paper and ink | Role |
|---|---|---|---|
| background | 131312 | F3F1EC | bar, desktop |
| surface | 1B1B1A | FBFAF7 | popovers (a lighter sheet in both modes, not an inversion) |
| surface2 | 262624 | E9E6DF | selected row |
| text | ECEAE4 | 161514 | content |
| text2 | A8A59E | 595650 | secondary content |
| muted | 939089 | 67645E | annotations |
| border (rule) | 2F2E2B | D6D2CA | hairlines, the ruler |
| border_strong | 6E6C66 | 807C75 | ticks that must be seen, outlines |
| accent_fill (index) | DA291C | DA291C | the index mark, in both modes |
| accent (red text) | F05A4A | C6231A | "critical", errors |
| warning | E0A43A | 8A5700 | urgent workspace, offline |

All pairs pass WCAG AA (`tests/contrast.sh`, 82 pairs). Switches are ink, not red: a setting is not "now".
State is never colour alone: tick height, numerals, words ("connected", "mute", "critical"), "!" before errors.

## Geometry and motion

Spacing 4 / 8 / 12 / 16 / 24 / 32. Margin 16 px (the ruler's ends). Radius 0 everywhere. Lines 1 px, marks 2 px.
Rows 34 px. Motion: 90 ms fades and the ticks' height change; nothing loops. No blur, no shadows, no transparency
(GTX 1070 on the legacy driver).
