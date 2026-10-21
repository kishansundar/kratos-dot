# DateTimePanel

The date and time popup, opened by clicking the bar's clock: the live time large, the full date, a month calendar to browse, world clocks, and the clock's sync state. `popupWidth`, hung from the bar rule right-aligned under the clock.

**Consumer provides:** the current time (local zone), the zone name and offset, the list of world-clock zones (from `State`; default UTC plus up to four more the user picks), and the sync state (`timedatectl show -p NTPSynchronized -p TimeUSec`, or the last sync from `timesyncd`).

**Layout**
1. **Header** — "Date and time" (`h2` + ruler); the local zone and its UTC offset in `mono` at the right ("Asia/Kolkata · UTC+05:30").
2. **Now** — `HH:mm` in `display` (48, tabular) with the seconds beside it in `h2` `textFaint`; the date written out in `body` ("Thursday, 15 October 2026"); then `mono` facts: ISO week and day of year. Seconds tick once a second while open.
3. **Calendar** — month and year (`body` 600) flush left over the grid, ‹ › (`chevron-left` / `chevron-right`, `hitTarget`) at the right; when browsing away from the current month a "today" text button appears beside them. An 8-column grid of `hitTarget` cells: ISO week number (`textFaint`), Monday → Sunday, weekend `textMuted`, days outside the month `textFaint`.
   - **Today**: `accent` fill, `onAccent` number — the panel's one red.
   - **Selected day** (clicked while browsing): a 2px ink outline, never colour.
   - Keyboard: ← → ↑ ↓ move by day / week, Page Up / Down by month, Home returns to today, Enter selects.
4. **World clocks** — a `caps` eyebrow with the count, then one row per zone on a 1px rule: city (`body`), offset from local time (`mono` `textMuted`, "−5:30"), its time (`label` 600, tabular). A zone where it is night (22:00–06:59) shows its time in `textFaint` with "(night)" — a word, not a colour. Right-click a row to remove it; "add clock" lives in date & time settings.
5. **Footer** — "date & time settings" (opens the system tool) and the sync state in `mono` `textFaint` ("ntp · synced 4 min ago"). Not synchronised: an ink triangle and "not synced" instead.

- The calendar is a date picker for reading only: no events (no calendar source is wired in). If one is added later, a day with events gets a 2px ink tick under its number — never a dot of colour.
- Week starts Monday; ISO week numbers; 24-hour time everywhere.
- Opens on today every time; browsing state is not kept.
