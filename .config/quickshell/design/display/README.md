Monitor brightness for the Quickshell Swiss desktop shell, as its own system: the bar's brightness glyph, the Display panel it opens, and the brightness OSD for the keys. Brightness is set over **DDC/CI**, so it changes the monitor's own backlight, the same setting as its buttons, not a software dimming filter. On this desktop that is the ROG PG279Q on DP-2, answering on `/dev/i2c-7`, brightness 0–100 and contrast 0–150. It uses Quickshell Swiss's tokens unchanged (Geist, Swiss Glyphs, light and dark, the 8px grid, the ruler, the ink marks) and adds only DDC timing and brightness steps.

## Principles

1. **Beside volume.** The brightness glyph sits immediately left of the volume glyph in the bar's status group. Both set an output level and both work the same way: scroll steps it, hover shows it, click opens its panel.
2. **The slider tells the truth.** A DDC write takes about a tenth of a second and can fail. Ink shows a value the monitor has confirmed by read-back. A value still being sent is shown in `textMuted`, with a faint tick at the last confirmed value, until the read-back agrees.
3. **Send once, on release.** Dragging sends nothing; release sends one write. Key presses and scroll notches inside `ddcSettle` (300 ms) merge into one write. The bus never gets a queue of writes.
4. **No red unless it failed.** Brightness has no primary action, so the panel has no `accent`. The OSD keeps Swiss's accent fill so it matches the volume OSD. `error` appears only for a failed write.
5. **Read, don't poll.** Values are read when the panel opens, after each write, and on resume. Nothing reads the bus on a timer.

## Layout

The panel is `popupWidth` 384, `s5` padding, `surface`, 1px `line` border, flush under the bar rule, its right edge aligned to the brightness glyph's right edge.

| Part | Spacing | Shown when |
|---|---|---|
| Header: h2 "Display" + ruler; monitor model · connector in mono | `s5` below | always |
| Brightness: eyebrow (status at right), ruler slider, presets 25 / 50 / 75 / 100 | — | monitor answers DDC/CI |
| Contrast: eyebrow, ruler slider, `92/150` | `s4` above | monitor offers VCP 0x12 |
| Night light row | 1px rule, `s5` above | always (same state as the dashboard control) |
| Footer: "DDC/CI · i2c-7" mono `textFaint` | `s4` above | always |

With two DDC monitors, each gets its own block, titled with its model and connector, `s6` apart. No "link all" control: one change, one monitor.

## Type

`h2` heading; `caps` eyebrows; `label` values, tabular, no space before % (`47%`); contrast as `92` plus `/150` in `textFaint`; `mono` for the model, connector, bus and states ("setting…").

## Colour

Swiss's tokens, nothing added: `text` for confirmed fills and handles; `textMuted` for a pending fill and value; `textFaint` for the confirmed-value tick while pending; `tick` for scales; `error` only for a failed write; `accent` only as the OSD fill. Both themes.

## Behaviour

- Bar glyph: scroll ±`brightnessStep` (5); hover tooltip "brightness 47%"; click opens the panel; middle-click does nothing.
- Keys: XF86MonBrightnessUp / Down step ±5, merged within `ddcSettle`, then one write; the OSD shows under the bar beside where volume's appears and stays `osdHold` (1.2 s).
- Panel: drag or click the ruler (sends on release), presets send at once, ↑ / ↓ step 5, Esc closes.
- Write then read back. Agreeing value: ink. No agreement within `ddcTimeout` (2 s): the slider returns to the last confirmed value and the row says "PG279Q didn't answer · retry".
- No DDC/CI on a monitor: the panel says so in one sentence and keeps the night light row. The bar glyph stays, opening that panel.

## Implementation notes for the agent

- Package: add `ddcutil` to the NixOS packages; it only applies after the rebuild (`nrs`). The user's account already has I²C access; no group change.
- Commands: read `ddcutil --bus 7 getvcp 10 --brief` (and `12` for contrast); write `ddcutil --bus 7 setvcp 10 <n>`. Use `--bus`, not `--display`: it skips detection, so writes are faster. Find the bus once with `ddcutil detect` at startup and cache it; never hard-code 7 in QML.
- Run ddcutil through one `Process` at a time; a write that arrives while one is running replaces the pending one (latest wins).
- Read the max from `getvcp` rather than assuming 100.
- Bind changes: replace the `brightnessctl` binds in `bind.conf` with calls into the shell (an IPC call so the OSD and the slider stay in sync), not direct ddcutil calls from the compositor.
- The dashboard is built in another session. If it gets a brightness control, it reads this system and uses the same service, so there is one writer to the bus.

## Relationship to the other systems

- **Quickshell Swiss** — the bar, its glyphs (`brightness` U+E031, a sun, is the module glyph) and the volume OSD this OSD mirrors.
- **Quickshell Panels** — every other popup. The Display panel follows the same Popup shell rules.
- **Quickshell Swiss Dashboard** — may show brightness; if it does, it uses this system's service and states.
