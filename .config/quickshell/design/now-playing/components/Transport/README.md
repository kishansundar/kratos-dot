# Transport

Previous, play / pause, next, then the mode toggles at the right.

**Consumer provides:** playback state, can go previous / next, can play / pause, shuffle and loop state with their support flags, and the actions.

- **Play / pause**: a `playButton` (48) square in `accent`, glyph in `onAccent` (`pause` while playing, `play` while paused). No border, no hover change, no pressed colour; it stays the same red.
- **Focus ring**: `marker` (2px) `text` outline, offset `marker` outside the square, so it shows against the red and the surface. Draw it only for keyboard focus: in QML, show it when `activeFocus` and the focus came from a key (Tab, or any key press since the panel opened), not when the panel opened from a click.
- Previous / next: `hitTarget` buttons, 16px glyphs, hover `surfaceAlt`, disabled in `textFaint` when the player can't.
- **Shuffle** and **repeat**: text toggles with the on/off circle; repeat cycles off → "repeat" → "repeat one". Each is hidden when the player doesn't support it, which is the usual case for browsers.
