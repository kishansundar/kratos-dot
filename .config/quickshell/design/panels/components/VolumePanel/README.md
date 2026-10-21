# VolumePanel

The sound popup from the bar's audio glyph: output level and device, input level and device, and per-app volume. (System volume lives here; a player's own volume lives in the Now Playing panel.)

**Consumer provides:** PipeWire state via `Quickshell.Services.Pipewire` (bind a `PwObjectTracker` for every node read): default sink and source with volume and mute, available sinks and sources, playback streams (application name, media name, volume, mute).

**Layout**
1. Header — "Sound" + ruler; the server and sample rate in `mono` at the right.
2. **Output** — a mute button with the level glyph (`volume-mute`, `volume-0…2`), a ruler slider (scale every 10 %, ink fill, value tick), `NN %`. Below, the output devices as rows: filled circle = default; Bluetooth devices carry the `bluetooth` glyph. Click a row to make it default.
3. **Input** — the same with the mic glyph (`mic` / `mic-off`). Muted: fill and value in `textFaint`, plus the word "muted" beneath — never colour alone.
4. **Apps** — one entry per playing stream: app name (`body`), `NN %`, a ruler without scale, and the media name in `mono` `textMuted`. Hidden when nothing plays. The eyebrow counts them.
5. Footer — "sound settings" (pavucontrol) and the rate.

- Sliders stop at `volumeMax` (100 %); arrow keys and scroll step `volumeStep` (5 %). Over-amplification is left to sound settings.
- The bar OSD shows output changes made here too.
