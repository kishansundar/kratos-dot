# Volume

The player's own volume, not the system's: the `volume` glyph, a ruler meter, and the value in `label`, tabular, with no space before the sign (`62%`).

**Consumer provides:** player volume (0–1), whether the player supports setting it, and a setter.

- Drag or click the ruler; scroll or ↑ / ↓ steps `volumeStep` (5 %). Glyph follows the level: `volume-mute` at 0, `volume-0` under 34 %, `volume-1` under 67 %, `volume-2` above.
- Hidden when the player doesn't support volume. If a player claims support but the value never changes after a set, hide it for that player for the session. System volume stays in the Sound panel.
