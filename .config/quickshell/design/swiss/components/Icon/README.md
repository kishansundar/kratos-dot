# Icon

SIcon: one glyph from Swiss Glyphs, the system's own icon font, always 16px and placed on whole pixels.

**Consumer provides:** a glyph name from `Glyphs.qml` (e.g. `Glyphs.wifi3`) and a colour token. No size: there is one.

- 50 glyphs at U+E000–U+E031: volume (mute, 0–2), mic / mic-off, Wi-Fi 0–4 / off, lan / off, Bluetooth / connected / off, bell / off (DND), theme, play / pause / next / prev, close, check, error, warning, chevrons ×4, lock, calendar, more, search, headphones, display, music, plus, minus, awake / awake-off (idle inhibitor), agent (coding-agent sessions), nixos, nixos-a, nixos-b, night (night light), power (power menu), brightness (monitor brightness).
- Brightness: one fixed sun, never a level glyph; the level lives in the tooltip and OSD. Kept distinct from `theme` (a box) so the two never read alike in the status row.
- Stay-awake: `awake` (solid cup) while the idle inhibitor holds, `awake-off` (outline cup) when released — solid = on, outline = off, as with the Wi-Fi bars.
- NixOS mark: `nixos` in one colour, or two-tone by stacking `nixos-a` (`accent`) under `nixos-b` (`text`) in the same 16px box. Geometry is the official snowflake from NixOS/nixos-artwork (CC-BY 4.0), fitted to the grid — credit it in the shell's README.
- No other product logos are drawn into the set. Third-party marks (an app's own icon in the tray) come from that app's icon file.
- Pick the level glyph from state (`wifi-0`…`wifi-4`, `volume-0`…`volume-2`); never tint one glyph to show a level.
- Colour: `text` default, `textMuted` inactive, `accent` active only, `onAccent` on accent fills; `warn` / `error` only for a real state.
- An icon appears only if it replaces or disambiguates a word.
- New glyph: draw it on the 16px grid with 2px features, append it at the next codepoint, regenerate the font, `Glyphs.qml` and the SVGs together.
