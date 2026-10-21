The Now Playing panel for the Quickshell Swiss desktop shell, as its own system: the popup that opens from the bar's Now Playing module and holds everything about the current track. Version 2 is built around what MPRIS players actually report: music players send square art, length and position; browsers send wide video thumbnails and often no timing at all. The panel adapts to both instead of assuming a music player. It uses Quickshell Swiss's tokens unchanged (Geist, Swiss Glyphs, light and dark, the 8px grid, the ruler, the ink marks) and adds only its own geometry and interaction defaults.

## Principles

1. **Hung from the bar.** It opens under the Now Playing module, right-aligned, flush with the bar rule; never centred, never floating.
2. **One action is red.** Play / pause is the only `accent`: a solid square with an `onAccent` glyph, no border. Everything else is ink.
3. **The art decides the layout.** Square art sits beside the words; wide art (video) runs the full width above them and is fitted, never cropped; no art means words only, no placeholder box.
4. **Say only what the player told you.** A time row appears in one of four forms (seekable, read-only, live, untimed), chosen from what the player reports. A video is never labelled "live" because its browser sends no length.
5. **Show only what the player can do.** Unsupported controls are hidden (shuffle, repeat and volume on most browsers); temporarily unavailable ones are disabled in `textFaint`.
6. **Focus is for keyboards.** Focus starts on play / pause, but its ring shows only after a key press, in ink, outside the red square.

## Layout

`popupWidth` 384, `s5` padding (336 content), `surface`, 1px `line` border, radius 0.

| Part | Spacing | Shown when |
|---|---|---|
| Header: h2 + ruler; player id (mono), `+N`, raise chevron | `s5` below | always |
| Track: album, video or bare layout | — | always |
| Time row: seek ruler, live line or untimed line | visible `s5` above | always (form varies) |
| Transport: previous, 48 play square, next, modes | `s4` above | always; modes only if supported |
| Volume | `s4` above | player sets volume |
| Players | `s6` above | more than one player |

The seek ruler's hit area is `hitTarget` (32) tall with the ruler at its bottom, so its top margin is `s2`: 8 + the 16px above the ticks gives the visible `s5`. Measure the gap you see, not the box.

## Choosing the layout (Track)

Aspect = art width / height, read from the loaded image.

- `artSquareMin` (0.8) ≤ aspect ≤ `artSquareMax` (1.25): **album**. 128 square, centre crop is fine here (a few pixels at most).
- aspect > 1.25: **video**. Full-width frame at `artWideRatio` (16 : 9, 336 × 189); the image is fitted (`PreserveAspectFit`), leftover space `surfaceAlt`. Title gets `titleLinesWide` (2) lines.
- aspect < 0.8 (posters): album layout, fitted, sides `surfaceAlt`.
- No art URL, or it fails to load: **bare**. No frame at all; title, artist and source run full width.

## Choosing the time row (Seek)

| Player reports | Row |
|---|---|
| length > 0, position, can seek | **seekable** ruler: fill, handle, elapsed and −remaining |
| length > 0, position, can't seek | **read-only** ruler: fill, no handle, times |
| position advancing for `liveProbe` (3 s), no length | **live**: ink circle, "live", time listened at the right |
| no usable position | **untimed**: one `mono` `textFaint` line, "zen doesn't report position" |

Until `liveProbe` has passed, a track with no length shows the untimed line, never "live".

## Type

`h2` heading; `body` 600 title (album 3 lines, otherwise 2); `body` `textMuted` artist; `mono` `textFaint` source line (album · year, or the site's host for browser media; at most 2 lines); `mono` `textMuted` times; `label` modes and volume value (`62%`, no space). Tabular figures for all times and percentages.

## Colour

Quickshell Swiss's tokens, nothing added: `surface`, `line`, `text` for fills, handles and the focus ring, `tick` for scales, `accent` + `onAccent` only for play / pause, `textMuted` / `textFaint` for secondary text, `surfaceAlt` for hover, letterboxing and fit gaps. Both themes. No colours sampled from the art, no blur.

## Behaviour

- Keys: Space play / pause, ← / → seek `seekStep` (5 s, seekable only), ↑ / ↓ volume `volumeStep` (5 %), N / P next / previous, Esc close.
- Position refreshes every `positionTick` (1 s), only while open and only when position is reported.
- The player id raises the player's window when it can (MPRIS Raise); otherwise it is plain text.
- Player gone: heading kept, "Nothing playing" in `textMuted`.

## Implementation notes for the agent

- Use the MprisPlayer capability properties that Quickshell documents (length / position / volume support, `canSeek`, `canRaise`, `canGoPrevious` / `canGoNext`, shuffle and loop support). Check the names in the docs for the installed Quickshell version; do not invent them.
- Before building, record what each real player sends: `playerctl -l`, then `playerctl -p <name> metadata` and `playerctl -p <name> position`, for Zen with a YouTube tab and for one music player. Save the output in the repo; the layout and time-row choice is tested against it.
- Read art size from the loaded `Image` (`sourceSize` / `implicitWidth`, `implicitHeight`) after `status === Image.Ready`, then pick the layout. Show the bare layout while loading; don't jump twice.

## Relationship to Quickshell Swiss

The bar module (NowPlaying), the tray and everything else stay in Quickshell Swiss; every other popup is in Quickshell Panels. This system holds only the media panel. Its stylesheet is Swiss's, so all of them match.
