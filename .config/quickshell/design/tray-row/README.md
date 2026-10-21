The tray row of the Quickshell Swiss bar, as its own system: the three things at the left of the status glyphs that didn't match the rest of the bar — the **tray chevron**, the **Claude** tray item and **keep-awake**. It fixes only those three and changes nothing else in the bar. It uses Quickshell Swiss's tokens unchanged (Geist, Swiss Glyphs, light and dark, the 8px grid, the ruler, the ink marks).

## What was wrong

- **Keep-awake** came from an app's own tray icon, so it rendered at its own size and weight (a small mark, not a 16px glyph).
- **Claude**'s tray icon is a thin-stroked, coloured app icon drawn on its own grid; next to 2px Swiss Glyphs it looks lighter and off-centre.
- **The chevron** must be the Swiss Glyph `chevron-left`, at 16px in `text`, so it carries the same stroke as Wi-Fi, Bluetooth and the rest.

## The row

Bar order, right group: `[drawer ←] chevron · Claude · keep-awake | Wi-Fi · Bluetooth · brightness · volume · bell · theme · power`.

- Every cell is `hitTarget` × `barHeight` (32 × 32), the icon 16px, centred on whole pixels, hover `surfaceAlt`.
- Claude and keep-awake sit **right** of the chevron and never move. The drawer of other tray apps slides out **left** of the chevron; its extent is a 2px ink line on the bar rule.
- A bar-rule tick marks where the row ends and the status glyphs begin; the gap is `rowGap` (16).

## Keep-awake

A shell module, not a tray app: it drives Quickshell's idle inhibitor itself.

- Glyphs: `stay-awake` (U+E032, open eye) while the screen is kept awake, `stay-awake-off` (U+E033, closed eye) when it may sleep. Both new in Swiss Glyphs 1.5, drawn on the 16px grid with 2px strokes.
- Click toggles. Tooltip says the state and the action: "keep awake: off · click to stop the screen sleeping" / "keep awake: on · screen won't sleep".
- Ink only; state is the glyph's shape, never colour. If a keep-awake tray app is still running, quit it: one inhibitor, one icon.
- The old cup glyphs (`awake`, `awake-off`) stay in the font for anything that already uses them.

## Claude

The Claude desktop app's own tray item (`SystemTray`), shown with the app's own icon. The shell does not draw or replace the logo; it only renders it the way the bar renders everything:

- **Tinted to `text`**: the icon is used as a mask and filled with `text` (Qt: `MultiEffect` with `colorization: 1` and `colorizationColor: Theme.text`, or a `ColorOverlay`), so it is black in light, off-white in dark, like the glyphs.
- **16px, whole pixels**: request the icon at 16 (or 32 for HiDPI) and place it on integer coordinates; never let it scale to fractional sizes.
- Pinned by default, right of the chevron. Left-click: the item's activate (its window). Right-click: the app's own menu, hung from the bar rule in Popup styling, with "unpin" in the footer. Tooltip: the item's own title.
- NeedsAttention: an ink triangle on its cell, as on the chevron.

The same tint applies to every tray app icon in the drawer, so the whole row reads as one set. Coloured icons lose their colour by design; their shape is what identifies them.

## Tokens

Swiss's, plus `rowGap` (16) and `tipDelay` (500 ms). No colours added.

## Relationship to the other systems

This system only covers the three items. Where it differs from Quickshell Swiss's Tray card (pinned items sit right of the chevron, app icons are tinted), this system wins for the tray row. Everything else stays as Swiss, Panels and Display specify.
