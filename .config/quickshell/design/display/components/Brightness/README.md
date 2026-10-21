# Brightness

A ruler slider for one monitor's brightness: the `brightness` glyph, the ruler (4px ticks every 10 %, 8px at 0 / 50 / 100 %), a 3px fill and the 2 × 16 handle, then the value in `label`; presets beneath.

**Consumer provides:** confirmed value, max, target value (while sending), and a set action.

- **Confirmed**: ink fill and handle, value in `text`.
- **Dragging**: fill and handle follow the pointer in `textMuted`; a 1px × `pendingTick` `textFaint` tick stays at the confirmed value. Nothing is sent until release.
- **Sending**: same look as dragging, until the read-back matches; then ink.
- Hit area `hitTarget` tall; click jumps; ↑ / ↓ step `brightnessStep`.
- Presets `brightnessPresets` (25 / 50 / 75 / 100) as `label` text buttons; the one matching the target gets the 2px ink underline. They send at once (no release needed).
