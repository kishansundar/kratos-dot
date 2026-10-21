# DisplayPanel

The popup from the bar's brightness glyph: brightness, contrast and night light for each DDC/CI monitor. It hangs flush from the bar rule, right edge aligned to the brightness glyph's right edge, `popupWidth` (384) on `surface`, 1px `line` border, `s5` padding. Esc, a click outside or another click on the glyph closes it.

**Consumer provides:** a Brightness service: per monitor, its model, connector, I²C bus, brightness and max (VCP 0x10), contrast and max (VCP 0x12, optional), whether it answers DDC/CI, and a write state per monitor (idle / sending / failed); plus the night-light state shared with the dashboard.

- Header: h2 "Display", heading ruler; at the right `PG279Q · DP-2` in mono (two monitors: "2 monitors").
- Brightness block: `caps` eyebrow, its state at the right in mono ("setting…" while sending); the Brightness slider; presets.
- Contrast block: same slider, value as `92/150`. Hidden if the monitor doesn't offer it.
- Night light: a full-width toggle row above a 1px rule; circle on/off, "off · 4500 K" at the right in mono.
- Footer: "DDC/CI · i2c-7" in mono `textFaint`, for when something misbehaves.
- No accent in the panel. Opening: opacity + 8px slide over `durMed`; instant under reduceMotion.
- On open: read every value once. Nothing polls while open or closed.
