# Tray

The system tray as a drawer inside the bar: collapsed it is one chevron (plus any pinned items); clicking the chevron slides the tray icons out to its left, in the bar itself. No panel.

**Consumer provides:** `SystemTray.items` (`Quickshell.Services.SystemTray`) — icon, title / tooltip, status (Passive / Active / NeedsAttention), menu; a pinned list (item ids) from `State`.

**Drawer**
- Toggle: a `hitTarget` button with `chevron-left` when closed ("show tray"), `chevron-right` when open ("hide tray"); `aria-expanded` follows.
- Open: items appear between the pinned items and the window title, each a `hitTarget` (32 × 32) cell with the app's 16px icon as given (symbolic icons in `text`). The drawer slides open over `drawerOpen` (180 ms, `easeOut`); instant under `reduceMotion`. Its extent is marked by a 2px ink line on the bar's bottom rule — the ruler again.
- It stays open until the chevron is clicked again or Esc is pressed while it has focus — it never closes on its own and never covers anything.
- Order: the order the items registered in, stable between opens. Passive items are hidden unless pinned.
- The bar's title on the left gives up the width (it elides further); the right group never wraps.

**Pinned items**
- Items the user pins stay visible left of the chevron even when closed (right-click → "pin" / "unpin" in the item's menu footer). Default: none pinned.

**Attention**
- An item with `NeedsAttention` while the drawer is closed puts an ink triangle (`markTriangle`) on the chevron, and the tooltip says which app ("syncthing needs attention"). Opening the drawer clears nothing; the item's own icon shows its state.

**Item clicks**
- Left: activate (the item's primary action). Middle: secondary activate. Right: its menu — a dropdown hung from the bar rule under the item, styled as a Popup from Quickshell Panels (the one place a tray item opens anything). Scroll: passed to the item.

**Don't:** recolour app icons, badge them, or open the tray as a floating panel.
