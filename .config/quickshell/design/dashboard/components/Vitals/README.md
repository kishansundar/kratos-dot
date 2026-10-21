# Vitals

The instrument sheet: one 40px row per vital whose four cells are the panel's four columns — label (`body`, left) and value (Geist 600 20/24, tabular, right-aligned to the column edge, unit in `label` `textMuted`) · ruler · 10-minute sparkline · metadata (`mono` `textMuted`) — grouped under the caps-on-ink-rule heading with the scale at the right.

**Consumer provides:** per row the current value, its scale (0–100 %, 20–100 °C, or the 10-minute peak for network), thresholds, 120 samples of history, and the metadata string.

- Rows sit on 1px `line` rules that run the full width; columns line up across every group.
- Warn: ink triangle on the value tick, the metadata becomes `text` and leads with a word ("▲ hot · fan 62 %").
- Critical: value, fill and value tick in `error`, the word "critical" in the metadata.
- Threads row: 12 ink bars on a baseline in the ruler column, height = load; no sparkline; metadata names the busiest thread.
