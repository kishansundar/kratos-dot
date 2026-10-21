# ClaudeItem

The Claude app's own tray item, its own icon tinted to `text` at 16px so it sits in the row like a glyph.

**Consumer provides:** the `SystemTrayItem` (icon, title, status, menu).

- Render: the item's icon as a mask filled with `Theme.text` (`MultiEffect` colorization 1, or `ColorOverlay`), 16px (32 on HiDPI), integer position. The shell never redraws or substitutes the logo.
- Pinned by default, right of the chevron.
- Left-click: activate. Right-click: the app's menu from the bar rule, Popup styling, "unpin" in the footer. Tooltip: the item's title.
- NeedsAttention: ink triangle on the cell.
- Previews show a neutral placeholder where the app's icon goes.
