The dashboard sibling of Quickshell Swiss: one 1152-wide panel **centred on the screen** (both axes, floating, not attached to the bar, not full screen) that shows this NixOS desktop (i7-8700K, GTX 1070) live — vitals, processes, storage — and holds four controls. It inherits everything from Quickshell Swiss — Geist and Geist Mono, Swiss Glyphs, the light and dark palettes, the 8px grid, the ruler, the ink marks. Every value lives in `tokens.json`; `Theme.qml` mirrors it.

Version 2 was redesigned from scratch. The dashboard is an **instrument sheet**: every vital is one row on a shared ruler, read top to bottom like a spec sheet, with processes, storage and controls beneath on the same grid.

## Principles

1. **One row per vital, one ruler for all.** cpu, threads, gpu, memory, vram, temperatures and network each get a row: label · value · ruler · 10-minute sparkline · metadata. The same columns line up all the way down, so any two vitals compare at a glance.
2. **One grid.** The 1104px content is four `dashCol` (258) columns with `dashGutter` (24). The vitals' four cells (label + value · ruler · sparkline · metadata) are those four columns, and the lower band uses them too — Processes across two, Storage and Controls one each — so every vertical edge in the panel lines up.
3. **One heading style.** Every group — Compute, Memory, Heat, Network, Processes, Storage, Controls — is a `caps` label on a 1px ink rule with its scale or count at the right. No cards, no tile backgrounds, no filled blocks.
4. **One row rhythm per band.** Vitals rows are `vitalRowH` 40; every lower-band row is `listRow` 32, and the three lower lists have 8 rows each, so their rows line up and they end on one line.
5. **Ink only.** Fills, handles, sparklines, the thread bars and marks are ink. The only colour is `error` for something critical (and the two-tone NixOS mark). No `accent`.
6. **No hero.** Every vital has the same weight; what's high shows itself by its fill and its triangle, not by type size.
7. **Never colour alone.** Warn = ink triangle on the value tick + a word; critical = `error` value and fill + the word.
8. **Measure only while visible.** Sampling starts when the panel opens and stops when it closes; history stays in memory.
9. **Words over icons.** Controls are named, so they carry no glyphs; on = filled circle and the name in 600, off = ring and muted.

## Colour

Inherited from Quickshell Swiss: `bg`, `surface`, `surfaceAlt`, `line`, `tick`, `text`, `textMuted`, `textFaint`, `accent`, `onAccent`, `ok`, `warn`, `error` (same values and contrast table).

Added for data. **Version 2 uses none of these on screen: the sheet is ink, with `error` for critical.** They stay defined for any future multi-series chart:

| Token | Light | Dark | Job |
|---|---|---|---|
| `series1` | #2a78d6 | #3987e5 | categorical slot 1 (blue) |
| `series2` | #e87ba4 | #d55181 | slot 2 (magenta) |
| `series3` | #008300 | #008300 | slot 3 (green) |
| `series4` | #6250d6 | #9085e9 | slot 4 (violet) |
| `seq1`…`seq7` | #cde2fb → #0d366b | reversed | sequential magnitude, one hue |
| `inkWash`, `series1Wash` | ~6–12% alpha | | flat area washes |

- The categorical order **blue, magenta, green, violet** was chosen by enumerating orders of the reference hues (red and orange excluded — red is the Swiss accent) and validating each with the dataviz validator on these surfaces (white / `bg` light, `surface` / `bg` dark). Adjacent pairs: worst colour-blind ΔE 13.0 (target ≥ 8), worst normal-vision ΔE 26.5 / 27.5 (floor ≥ 15), both modes. The first three also pass all-pairs in both modes, so scatter-type charts stop at three series.
- Contrast on the light surface: series1 4.42, series2 **2.69**, series3 4.95, series4 5.77; dark: 4.97, 4.59, 3.66, 5.79. Because series2 is under 3:1 in light, any chart using it keeps its legend and direct labels visible and offers the table view.
- Assign by entity, not rank: cpu = series1, gpu = series2 everywhere; down = series1, up = series3. Hiding a series never repaints the others.
- Text never wears a series colour — a key (swatch line) beside the text carries identity.
- The sequential ramp is reserved; per-thread load is drawn as ink bar heights, not colour.
- Status is never a series colour: warn / critical use the Swiss marks, `error` and words.

## Typography

Inherited: `h2` 20 (host name, lower-band titles), `body` 14, `label` 12, `caps` 11 (group eyebrows), `mono` 13 (metadata). Vital values: Geist 600 at 20/24, tabular, unit in `label` `textMuted`.

- Every live value is **tabular**: they change every second and must not jitter.
- Units: GiB / MiB, MB/s, °C, %, GHz. Numbers: one decimal under 10, none above where precision adds nothing.

## Layout

- **Centred floating panel.** `dashWidth` 1152 (3 × `popupWidth`), centred horizontally and vertically on the focused monitor; `surface`, 1px `line` border on all four sides, radius 0. The bar and desktop stay visible around it. Height fits the content (≈ 1050 px); on a short monitor it keeps `s7` from the screen edges and scrolls inside.
- Inside: `dashMargin` 24; content 1104 = 4 × `dashCol` 258 + 3 × `dashGutter` 24.
- **Header:** NixOS mark + host name (`h2`) left; mono metadata right.
- **Vitals sheet:** each row's four cells are the four columns — label (left) and value (right-aligned to the column edge) · ruler · sparkline · metadata. Rows `vitalRowH` 40 on 1px `line` rules that run unbroken (cells carry the gutter as left padding). Groups `s4` apart: Compute (cpu, threads, gpu), Memory (memory, vram), Heat (cpu package, gpu), Network (down, up).
- **Lower band,** `sectionGap` 32 below: Processes (columns 1–2: app, pid, cpu, mem; top 8 by cpu) · Storage (column 3: two rows per filesystem) · Controls (column 4: two rows per control). Each starts with its heading, then a 32px column-header row in `label` `textMuted` (app / pid / cpu / mem, mount · used / %, feature / state), then 8 rows of 32px.

## Rulers and sparklines

- Percent rows: 0–100 % ruler, 4px ticks every 10 %, 8px at 0 / 50 / 100 %, 3px ink fill, 2px × 16px value tick; warn thresholds as 8px `textMuted` ticks.
- Heat rows: the ruler spans 20–100 °C with ticks at 80 (warn) and 90 (critical), stated in the group heading.
- Network rows: full scale is the 10-minute peak, stated in the group heading.
- Threads row: 12 ink bars on a `tick` baseline in the ruler column, height = load (0–16px) — the tag ruler's idea; hover gives "thread 9 · 91 %"; no sparkline.
- Sparklines: 1px `textFaint` line over `historyWindow` (10 min), current value as an ink dot, filling the sparkline column. `t` switches the sheet to a table of current, min, max and mean.

## Thresholds

`threshold` tokens hold the defaults: cpu / gpu 80 °C warn, 90 °C critical; memory / vram 85 %; disks 85 % warn, 95 % critical. Warn → ink triangle + word. Critical → `error` value, error glyph + word. Confirm the temperature limits for your hardware.

## Refresh

`refreshFast` 1 s (cpu, gpu, network, cores, temperatures), `refreshSlow` 5 s (disks, processes), `historyWindow` 10 min. Nothing is sampled while the overlay is hidden; `nvidia-smi` is polled only while visible.

## Controls

The fourth lower column: Tailscale (Tailscale DNS **off** by default; an option turns it on), night light (2500–6500 K mini ruler, optional sunset → sunrise), caffeine (30m / 1h / 2h / off) and do not disturb (same, plus held count). Each is two 32px rows: the switch row (mark · name · state word) and its option row beneath. On = filled ink circle, name 600, word in `text`; off = ring, muted. No glyphs (the names say it), never a filled block, never `accent`. State is read back from the system; failures snap back with "failed". See Controls.

## Iconography

Almost none: the NixOS mark in the header and `error` beside a critical value. Controls and rows are named in words. The marks (circle, ring, triangle) are CSS / QML shapes, not glyphs.
