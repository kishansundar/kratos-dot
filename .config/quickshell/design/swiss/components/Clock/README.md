# Clock

The ruled clock: weekday in `label` `textMuted`, hours and minutes in `count` (tabular) split by a 2px × 16px `text` tick, then the date in `label` `textMuted`.

**Consumer provides:** the current time (24-hour) and date. A click opens the **DateTimePanel** in Quickshell Panels (live time, month calendar, world clocks).

- Format: `dddd` · `HH` | `mm` · `d MMMM` (Thursday 02 | 03 15 October). Gaps are `s2`.
- The separator tick is `text`, not `accent`: the focused tag tick is the bar's one red.
- Tabular figures always, so the clock never shifts width.
- Sits at the right end of the bar, flush with `barPadX`.
