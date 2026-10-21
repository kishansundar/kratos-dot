# Tile

A square quick-toggle tile in the control centre, spanning 2 of the 6 panel columns, icon top-left and a two-line label bottom-left.

**Consumer provides:** icon name, label word, a state word ("On", "Off", the network name, "LIGHT"/"DARK"), `checked`, `onClicked`.

- Off: 1px `line` border, `text` label, state word in `textMuted`.
- On: `text` fill, `bg` label and a filled `bg` circle top-right — inverted, **not** accent. Off: 1px `line` border, 2px ink ring top-right. The circle repeats on/off in shape, so the state never depends on fill alone.
- The theme tile always shows the mode as a word (LIGHT / DARK), not just an icon.
- No power-profile tile on this desktop host.
