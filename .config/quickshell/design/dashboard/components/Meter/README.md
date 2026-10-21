# Meter

Storage rows: each filesystem is two `listRow` (32) rows — mount (`body`) with "19.9 of 434 GiB" in `mono` `textMuted` and the % (`label` 600) at the right; then a full-width ruler meter (1px `tick` baseline, 3px ink fill, 2px × 16px value tick, warn tick at `diskWarn` 85).

**Consumer provides:** label, used / total, filesystem or device, warn and crit thresholds (`diskWarn` 85, `diskCrit` 95; `memWarn` 85).

- The warn threshold is drawn as an 8px `textMuted` tick on the ruler, so the distance to it is visible before it is crossed.
- Over warn: an ink triangle on the value tick and a word in the metadata ("near full"). Over crit: fill and value tick in `error`, the error glyph and the word ("full"). Never colour alone.
- Rows `s4` apart. Mount points and devices in their own case; numbers tabular.
