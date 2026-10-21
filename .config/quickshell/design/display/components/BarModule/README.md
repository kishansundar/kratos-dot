# BarModule

The brightness glyph in the bar's status group, immediately left of the volume glyph.

**Consumer provides:** confirmed brightness, whether any monitor answers DDC/CI.

- `hitTarget` wide, `barHeight` tall, the `brightness` glyph (U+E031, a sun) in `text`; hover `surfaceAlt`.
- Hover: tooltip "brightness 47%" in mono `label`, under the glyph. Two monitors: the focused output's value.
- Scroll: ±`brightnessStep` on the focused output, merged within `ddcSettle`, shows the OSD.
- Click: opens the Display panel. A bar-rule tick marks the module's start, like every module.
- The glyph doesn't change with the level: the value is in the tooltip and the OSD, not encoded in the icon.
