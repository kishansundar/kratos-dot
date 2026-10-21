# Menu

Right-click on a cell: a Popup-style menu rising from the dock's top edge, left-aligned to the cell, `surface`, 1px `line` border on three sides.

**Consumer provides:** the app's windows (title and tag), its desktop actions, pinned state.

- Order: caps heading "ZEN · 2 WINDOWS" · one row per window ("tag 1 · title"; click focuses it) · rule · the desktop entry's own actions ("New window", "New private window") · rule · "Pin" / "Unpin" · "Quit" (asks only if the app does).
- Esc or a click outside closes it. Rows are `hitTarget` tall.
