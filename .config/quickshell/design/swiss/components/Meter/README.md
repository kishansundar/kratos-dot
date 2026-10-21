# Meter

SMeter: a read-only ruler — 1px `tick` baseline across the full width with an 8px origin tick, a 3px `text` fill, and a 2px × 16px `text` value tick at the value.

**Consumer provides:** a label, a value (0–1) shown as tabular `NN %`, and optional `mono` `textMuted` metadata beneath (reset time, source).

- Layout: label (`body`) left and value (`label` 600) right on one line, the meter under them, metadata under the meter.
- No scale ticks: a meter reads a value, it is not adjusted. (The Slider carries the scale.)
- Over the consumer's threshold an ink triangle (`markTriangle`) stands on the value tick **and** the metadata leads with "near limit". The fill stays ink — no colour change.
- Used for plan limits, disk, memory, download progress, the OSD.
