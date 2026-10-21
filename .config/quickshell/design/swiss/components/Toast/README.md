# Toast

A notification toast: `popupWidth` wide, `surface` with a 1px `line` border, stacked top-right under the bar with `s2` gaps, at most 3 visible.

**Consumer provides:** a notification from the Quickshell notification server — app name, summary, body, time, urgency, actions, optional image.

- App name in `caps` `textMuted`; time `label` `textFaint` tabular, right; summary `body` weight 600; body `body` `textMuted`.
- Critical: 2px (`marker`) `accent` left bar plus an error icon — never colour alone. Persists until dismissed.
- Normal/low: time out after 5 s. Do-Not-Disturb suppresses them (history still records).
- Actions as text Buttons. Images only when provided, square-cropped.
- Before shipping, confirm no other daemon (mako, dunst, swaync) owns `org.freedesktop.Notifications`.
