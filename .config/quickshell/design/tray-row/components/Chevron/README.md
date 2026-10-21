# Chevron

The tray toggle: Swiss Glyph `chevron-left` (closed, "show tray") or `chevron-right` (open, "hide tray") at 16px in `text`.

**Consumer provides:** drawer open state, whether a hidden item needs attention, that item's name.

- Hover `surfaceAlt`; `aria-expanded` follows the state.
- A hidden item with NeedsAttention: ink triangle (`markTriangle`) top-right of the cell; tooltip "syncthing needs attention".
- Never a font character like "<" or a theme icon: always the glyph, so the stroke matches the bar.
