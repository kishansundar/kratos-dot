# NotificationsPanel

The notification centre: history grouped by app, do not disturb, clear all. Opened from the bar (clicking the clock area's bell, or `qs ipc call notifs toggle`), hung from the bar rule at the right, `notifWidth`.

**Consumer provides:** the shell's notification server history (app name, summary, body, time, urgency, actions, image), the DND flag (shared with the dashboard and control centre), dismiss / invoke / clear actions.

**Layout**
1. Header — "Notifications" + ruler; at the right the **dnd** circle switch and **clear all** (text button).
2. DND on: a line under the header — `bell-off`, "Do not disturb · until 15:00", and how many were held, in `mono`.
3. **Groups** — newest group first, one per app: the app name as a `caps` eyebrow and the count in `mono`. At most `notifGroupMax` (3) items per group, then "+N more".
4. **Item** — summary (`body` 600), time (`mono` `textFaint`) at the right, body (`body` `textMuted`, `notifBodyLines` = 2 lines then ellipsis; click expands), actions as text buttons, a dismiss × at the top right. Items are separated by 1px `line` rules — no cards.
5. Critical urgency: a 2px `accent` bar on the left edge **and** the error glyph before the summary; critical items sort first.
6. Empty: "No notifications." in `body` `textMuted` — nothing else.

- Clicking an item invokes its default action and dismisses it. Middle-click dismisses.
- Times: "14:02" today, "yesterday 21:10", then a date. Images only if provided, square-cropped at 32px, left of the text.
- The history survives a shell restart (persisted by the server); clear all asks nothing but can be undone for 5 s with an "undo" text button in the header.
