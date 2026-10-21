# Osd

The brightness OSD for the keys: Swiss's volume OSD with the `brightness` glyph. `osdWidth` × `osdHeight`, `surface`, 1px `line` border, right-aligned under the bar, in the same place as the volume OSD (one OSD at a time; a new one replaces the old).

**Consumer provides:** confirmed value, target value, state (idle / sending / failed), max.

- Label "Brightness" with the glyph, value at the right, tabular, no space before %.
- Fill: `accent` when confirmed (matching the volume OSD); `textMuted` with a faint tick at the confirmed value while keys are merging or the write is sending.
- At the max or at `brightnessFloor`: "· max" or "· min" in `textMuted` beside the label; the key press does nothing else.
- Failed: "· no answer" in `error`, value back to the confirmed one.
- Stays `osdHold` (1.2 s) after the last change or the read-back, whichever is later; fades over `durSlow`.
