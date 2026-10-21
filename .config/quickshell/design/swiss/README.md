A desktop shell for the mango Wayland compositor, built in Quickshell (QML, Qt 6), in the International Typographic Style. Light and dark are equal citizens: same structure, spacing, type and accent role, different mood. Every value lives in `Theme.qml` (and `theme/palette.json`), which mirror the tokens here one-to-one — no colour, size, spacing, radius or duration appears anywhere else.

Panels — every popup opened from the bar (network, Bluetooth, sound, notifications, date and time, power, control-centre tiles) — are specified in the separate **Quickshell Panels** system. The media player panel lives in **Quickshell Now Playing**, the system overlay in **Quickshell Swiss Dashboard**.

## Principles

1. **Grid first.** Snap every edge to the 8px unit (`s2`). Use `s1` (4px) only for optical alignment of icons and text.
2. **Typography carries hierarchy** — size and weight, not colour, shadows or boxes. At most 3 sizes and 2 weights in one view.
3. **Flush-left, ragged-right.** Centre text only for a single number in a square cell (tag numbers, calendar days).
4. **Asymmetric balance.** Nothing in the bar is centred; the clock sits at the right edge.
5. **One accent.** Neutrals plus Swiss red (`accent`). `accent` marks exactly one thing per view — the active state or the single primary action. `ok` / `warn` / `error` appear only for a genuinely semantic state.
6. **Hairlines, not boxes.** Separate with whitespace first, a 1px `line` rule second, a filled surface third. No drop shadows, blur, gradients or glass.
7. **Square.** `radius` is 0 everywhere.
8. **Numbers are data.** Tabular figures (`tnum`) on every changing number: clock, percentages, volume, week numbers.
9. **Content over chrome.** An icon appears only if it replaces or disambiguates a word.
10. **The ruler is the signature.** The 8px grid is made visible as rulers: a `tick` baseline with ticks at `rulerPitch`. Headings carry a short ruler, sliders and meters are rulers, tags are ticks, the bar's bottom rule marks where each module starts. Values are shown as ink on a ruler, not as coloured bars.
11. **Three marks, one colour.** Borrowed from the Bauhaus, in ink only: a **filled circle** = on / selected (a **ring** = off), a **triangle** = attention, the red **square** fill = the one active thing. Shape carries the state; colour never has to.

## Voice and copy

- Short nouns and states, not sentences: "Wi-Fi", "Off", "Home-5G", "64 %".
- Section eyebrows are one word, set in `caps` (UPPERCASE): AUDIO, NETWORK, OUTPUT, DEVICE.
- The theme toggle names the mode as a word: LIGHT / DARK.
- Dates `ddd d MMM` (Wed 14 Oct); time 24-hour `HH:mm`; percentages `NN %` with a space.
- No emoji anywhere.

## Colour

| Token | Role |
|---|---|
| `bg` | Bar and panel ground |
| `surface` | Popups, cards, toasts, OSD |
| `surfaceAlt` | Hover fill, inactive fill |
| `line` | 1px rules, borders, pressed fill — decorative only |
| `tick` | Ruler baselines and ticks — meaningful, ≥ 3:1, never text |
| `text` / `textMuted` / `textFaint` | Primary / secondary / tertiary text |
| `accent` + `onAccent` | The one active thing, and text on it |
| `ok` / `warn` / `error` | Semantic state only, always with an icon or word |

- Set primary text in `text`, secondary in `textMuted`, timestamps and disabled in `textFaint` — all three pass 4.5:1 on `bg`, `surface` and `surfaceAlt` in both themes.
- On an `accent` fill use `onAccent`. It is white in light and near-black in dark; white on the dark accent is only 3.46:1.
- In light, `ok` and `warn` text sit on `bg` or `surface` only — on `surfaceAlt` they fall to 4.27 and 4.33. Use them there as icons (≥ 3:1) or not at all.
- `error` aliases `accent`. Pair it with an icon or word so it is never confused with an active state.
- Never let `line` carry meaning (1.4–1.6:1); it only separates.

- `tick` carries scale and state, so it meets the 3:1 non-text floor on every ground (light 3.46 / 3.82 / 3.05, dark 3.79 / 3.53 / 3.10). Never set text in it.

Measured contrast (WCAG 2.1), on `bg` / `surface` / `surfaceAlt`:

| Text token | Light | Dark |
|---|---|---|
| `text` | 17.14 / 18.88 / 15.08 | 17.32 / 16.12 / 14.18 |
| `textMuted` | 6.81 / 7.50 / 5.99 | 8.13 / 7.57 / 6.66 |
| `textFaint` | 5.25 / 5.78 / 4.62 | 5.89 / 5.49 / 4.83 |
| `accent` | 5.24 / 5.77 / 4.61 | 5.61 / 5.22 / 4.59 |
| `ok` | 4.85 / 5.35 / **4.27** | 8.19 / 7.62 / 6.70 |
| `warn` | 4.92 / 5.43 / **4.33** | 8.55 / 7.96 / 7.00 |
| `onAccent` on `accent` | 5.77 | 5.61 |

Recompute with a script and update this table whenever a colour changes. Targets: 4.5:1 for text, 3:1 for meaningful non-text (focus ring, slider fill, tag markers).

## Typography

- **Geist** (variable, 100–900) for all UI text. **Geist Mono** for code, IPs, interface names, paths, the layout symbol, arrows and box-drawing characters. **Swiss Glyphs** — this system's own icon font — for icons. Fallback chain `"Noto Sans", "Noto Sans Tamil"` so Tamil window titles and notifications render — Geist covers Latin, Cyrillic and Greek only.
- Install `geist-font` and `noto-fonts` from nixpkgs; install `SwissGlyphs.ttf` from the repo with a small `runCommand` derivation into `share/fonts/truetype`. Reference the exact family names `fc-list` reports.
- Geist has no optical-size axis: the `display` style relies on its −2% tracking, not a display cut.
- Geist lacks ■ □ ⌘ and thin / figure spaces: never build markers from characters — draw them as `marker` bars. Use Geist's own `·` – — × … ° for separators.
- Use the styles, never a raw size: `display` (48/48, 700) for big numbers, `count` (22/24, 700, tabular) for the bar's ruler numerals — the focused tag and the clock, `h1` (32/40, 700) panel titles, `h2` (20/24, 600) section headings, `body` (14/20, 400) default, `label` (12/16, 500) bar text, `caps` (11/16, 600, +8%, uppercase) eyebrows, `mono` (13/20) for metadata and machine text.
- Metadata speaks in Geist Mono, lower-case, `textMuted`: "2 active sessions", "resets in 2h 57m · Thu 05:00", "plan limits", the app id before a window title. Labels and headings stay in Geist.
- In QML: an `SText` component with a `variant` property reading `Theme.font.<style>`; `font.features: { "tnum": 1 }` on changing numbers (Qt ≥ 6.6, else Geist Mono for those numbers — its figures are fixed-width by default).
- All bar text shares one baseline. Respect each monitor's scale factor; never hard-code DPI.

## Layout

- Spacing steps `s0`–`s8` (0, 4, 8, 12, 16, 24, 32, 48, 64) are the only spacing values.
- Bar: `barHeight` 32, `barPadX` 16, `moduleGap` 16 between modules, `groupGap` 24 between groups, a single `rule` on its bottom edge.
- Panels: `popupWidth` 384, 6-column grid with an `s2` gutter and `s5` outer margin; popups hang flush from the bar rule, aligned to the column of the module that opened them.
- Every clickable is at least `hitTarget` (32 × 32). Icons are 16px everywhere (`iconBar` = `iconPanel`): the glyphs are drawn on a 16px pixel grid.
- State marks are `marker` (2px): tag ticks, value ticks, the active row and critical toast (left bar).

## Bar media and tray

- **Now Playing**: `Title — Artist` in a slot no wider than `npTextMax` (192px ≈ 31 characters); shorter titles sit still, longer ones scroll at `marqueeSpeed` (32 px/s) after `marqueeHold` (1.5 s), looping with a `marqueeGap` (48px) gap — two loops per track change, then rest elided; hover replays and pauses; never under `reduceMotion`. Transport (previous / play-pause / next) is fixed at the module's right edge. Progress is a 2px ink line on the bar rule. Clicking the title opens the Now Playing panel, specified in Quickshell Now Playing. See NowPlaying.
- **Tray**: a drawer in the bar, not a panel. A chevron opens it; icons slide out to its left inside the bar, the drawer's extent marked on the bar rule; an ink triangle on the chevron when a hidden item needs attention; items can be pinned. Only an item's own right-click menu drops down. See Tray.

## The ruler

- **Heading ruler** (Ruler): `rulerShort` (32px) under a panel title or eyebrow, `s1` below the text — origin tick `tickMajor` (8px), minor ticks `tickMinor` (4px) every `rulerPitch` (8px), 1px `tick` baseline. It replaces full-width rules above sections.
- **Slider**: full-width ruler with a scale (8px ticks at 0 / 50 / 100%, 4px every 10%), a 3px `text` fill centred on the baseline, a 2px × 16px `text` value tick as handle.
- **Meter**: the same without the scale; label and value above, `mono` metadata below; an ink triangle on the value tick over a threshold, with "near limit".
- **Tags**: focused number in `count`, `/N` muted, one 2px tick per tag every `tagPitch` (12px): empty 4px `tick`, occupied 12px `text`, focused 16px `accent`, urgent 12px `text` with an ink triangle cap.
- **Clock**: weekday · `HH` | `mm` · date; the separator is a 2px × 16px `text` tick.
- **Bar rule**: each module's start is marked by a 4px `tick` on the bottom rule, 8px at the origin.
- Tick heights are only 4 / 8 / 16 (`tickMinor` / `tickMajor` / `tickValue`); positions are whole pixels.
- Fill and value ticks are ink (`text`). `accent` appears on a ruler only for the focused tag, or on a slider's value tick while it is hovered or dragged.

## Marks

| Mark | Token | Means | Used for |
|---|---|---|---|
| ● filled circle, ink | `markCircle`, `radiusCircle` | on / selected | selected device or network; toggle on (in `bg` on the inverted tile) |
| ○ ring, 2px ink | `markCircle` | off / not selected | unselected rows, toggle off |
| ▲ triangle, ink | `markTriangle` | attention | urgent tag cap, near-limit meter flag, weak signal |
| ■ red fill | `accent` | the one active thing | focused tag tick, today, primary action, focus ring |

- Circles and triangles are always ink (`text`, or `bg` on an inverted fill) — never `accent`, `ok` or `warn`. In dark mode they follow `text` (≥14:1 on every ground).
- Every triangle comes with a word nearby ("near limit", "weak", "urgent" in the tag tooltip).
- `radiusCircle` exists only for this mark; nothing else is rounded.

## States and interaction

- Hover: `surfaceAlt` fill. Pressed: `line` fill. Keyboard focus: 2px `accent` outline, inset. Disabled: `textFaint`, no hover.
- Pointing-hand cursor on everything clickable. Popups trap focus; Esc closes; Tab follows reading order.
- Never colour alone: urgent tags carry a triangle, selection a circle, network state a glyph, critical notifications a bar and an icon.
- Elide long text with an ellipsis and offer the full text as a tooltip.

## Motion

- `durFast` 120ms for hover, colour and theme switch; `durMed` 180ms for popups (opacity plus an 8px vertical slide); `durSlow` 240ms for the OSD fade.
- Enter with `easeOut` (OutCubic), exit with `easeIn` (InCubic). No scale, bounce or spring.
- A tag change moves the accent fill instantly; only colour animates.
- `Theme.reduceMotion` sets every duration to 0. A theme switch never changes layout.

## Iconography

- One family: **Swiss Glyphs**, drawn for this system — 49 glyphs on a 16px grid, solid geometry, square ends, every edge on a whole pixel. Features are 2px (`marker`); 1px (`rule`) appears only as the outline of an inactive part (unlit Wi-Fi bars).
- Address glyphs by name through a generated `Glyphs.qml` map (`Glyphs.volume2` → U+E003) rendered by `SIcon`. Never type raw codepoints in components. Codepoints are append-only: a new glyph takes the next free one, an old one never moves.
- Always 16px. Any other size or a fractional position blurs the pixel-aligned edges; place icons on whole pixels.
- Colour `text` by default, `textMuted` inactive, `accent` only when active, `onAccent` on accent fills, `warn` / `error` only for a real state.
- Levels are shapes, not colours: volume 0–2 bars, Wi-Fi 0–4 filled bars, a 2px slash for every *off* state; solid = on, outline = off (`awake` / `awake-off`).
- The NixOS mark (`nixos`, or `nixos-a` + `nixos-b` stacked for two-tone `accent` / `text`) is the official snowflake from NixOS/nixos-artwork (CC-BY 4.0) fitted to the grid; it sits at the bar's origin. No other product logo is drawn into the set: an app's own mark comes from its icon file.
- No second icon family, no Nerd Font glyphs, no emoji. App icons appear only in the tray and the launcher.
- A missing font shows empty boxes, not words: check at startup that Swiss Glyphs is loaded and log a warning if not.

## Out of scope on this host

Desktop only (i7-8700K, GTX 1070): no battery, power-profile or backlight UI. Lock screen, power menu and wallpaper are not part of this system.
