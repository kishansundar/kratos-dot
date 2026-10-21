# Slider

SSlider: a ruler with a scale — 1px `tick` baseline, 8px ticks at 0 / 50 / 100%, 4px ticks every 10% — a 3px `text` fill from the origin, and a 2px × 16px `text` value tick that is the handle. Value as a tabular number in `label` to the right.

**Consumer provides:** `value` (0–1), `onMoved`, `enabled`, and the eyebrow label above.

- Fill and handle are `text`, not `accent`: the slider is ink on a ruler. On hover or drag the value tick turns `accent` — the view's one active thing at that moment.
- Hit area: the full `hitTarget` height and track width.
- Scroll on the bar's audio glyph steps ±5%; drag is continuous; arrow keys step 1%, Page Up/Down 10%.
- Disabled (muted device): fill and handle `textFaint`, value `textFaint`.
- Value never jitters: tabular figures.
