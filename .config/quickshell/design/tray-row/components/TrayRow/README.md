# TrayRow

The chevron, Claude and keep-awake as one row of 16px icons at the left of the status glyphs.

**Consumer provides:** `SystemTray.items`, the pinned ids (Claude by default), the idle-inhibitor state.

- Order: `[drawer] chevron · Claude · keep-awake`, then a bar-rule tick and the status glyphs.
- Cells: `hitTarget` × `barHeight`, icons 16px in `text`, whole-pixel positions, hover `surfaceAlt`.
- Drawer opens left of the chevron over `drawerOpen`; extent marked on the bar rule; Claude and keep-awake never shift.
