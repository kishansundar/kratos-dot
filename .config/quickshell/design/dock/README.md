The dock for the Quickshell Swiss desktop shell, as its own system. It shows **only while the focused workspace (mango tag) has no windows**, and hides the moment one opens. It uses Quickshell Swiss's tokens unchanged (Geist, Swiss Glyphs, light and dark, the 8px grid, the ruler, the ink marks) and adds only dock geometry and the show / hide rules. Apps keep their o## Principles

1. **Only on an empty desktop.** No windows on the focused tag → the dock shows. Any window → it's gone. It never covers a window, so it reserves no space (no exclusive zone).
2. **Hangs from the bottom edge.** Panels hang from the bar's rule at the top; the dock hangs from the screen's bottom edge, centred: `surface`, 1px `line` border on three sides, none at the bottom, radius 0.
3. **Apps look like themselves.** Each app shows its own icon from its desktop entry, full colour, at `dockIcon` 48px — never tinted, recoloured, badged or redrawn. The shell around them stays ink, so the icons are the only colour.
   *In this shell (16 October 2026): an app in the owner's Swiss app icons (`design/app-icons`) is its pictogram
   painted in `text`, and so is the trash; other apps keep their own icons in full colour. See the shell's CLAUDE.md.*
4. **Quiet chrome.** No labels under icons: the name appears on hover, in a small label box `dockLift` above the dock. Groups are split by a 1px `line` rule, not by space alone.
5. **State is a mark.** Running = a 2px × 16px ink bar under the icon (the bar's occupied-tag mark). Needs attention = an ink triangle in its place. Not running = nothing. No coloured dots, no glow, no bounce.
6. **One brand mark, Swiss two-tone.** The first cell is the NixOS snowflake at 48px with **one red arm**: `nixos-rest` (five arms) in `text` with `nixos-accent` (the top-left arm) in `accent` on top — the system's one-accent rule applied to the mark. Same mark at 24px on the bar. It opens the launcher, exactly like the mark on the bar. Geometry is the official nixos-artwork snowflake (CC-BY 4.0); only the colour split is ours.

## Layout

| Part | Size |
|---|---|
| Cell | `dockCellW` 64 × `dockCellH` 80: icon `s3` from the top, running bar `s2` below the icon |
| Icon | `dockIcon` 48 (request 48 from the icon theme, 96 on HiDPI); the NixOS mark also 48, one red arm |
| Groups | launcher · pinned apps · running apps that aren't pinned; `dockGroupGap` 16 apart with a 1px `line` rule centred in the gap, inset `s5` top and bottom |
| Dock | `dockPadX` 8 inside left and right; centred on the output; flush with the bottom edge |
| Hover name | `label` name in `text` + mono `textMuted` detail ("tags 1, 4 · 2 windows"), `surface` box with a 1px `line` border, left edge on the cell's left edge, `dockLift` 8 above the dock |

115 px²).

## Behaviour

- **Show:** the focused tag on this output has had zero windows for `dockShowDelay` (400 ms) → slide up `dockCellH` + fade in over `dockSlide` (180 ms, easeOut). The delay stops it flashing when you close one window and open another.
- **Hide:** a window maps on the focused tag, or you switch to a tag with windows → hidden instantly, no animation.
- Counts every mapped window on the tag: tiled, floating and fullscreen. Layer surfaces (bar, notifications, OSD, launcher) don't count. Each output has its own dock.
- **Click:** not running → launch; running → switch to its workspace and focus its most recent window (the dock then hides, because that tag has windows). Several windows on several tags → the menu opens instead.
- **Hover:** `surfaceAlt` cell and the name label after 150 ms. **Middle-click:** new window. **Right-click:** the menu (see Menu). **Drag** a pinned cell to reorder; drag it out of the dock to unpin.
- **Keyboard:** when the dock is shown, Super+1…9 is still the compositor's; the dock takes focus only from a click or `qs ipc call dock focus` — then ←/→ move, Enter opens, Esc leaves.
- **NixOS cell:** opens the launcher (Quickshell Launcher), exactly as the NixOS mark on the bar does.

## Implementation notes for the agent

- **Window counts per tag come from mango, not from guessing.** Find what mango's IPC reports (its `mmsg` client and the dwl-ipc style protocol it implements) — per-output tag state with a client count is what's needed. Verify the exact fields on this machine before coding; don't invent an API.
- App list and running state: Quickshell's toplevel tracking (wlr-foreign-toplevel) gives app ids and titles; join with mango's tag info to know which tag each window is on. Check the property names in the installed Quickshell's docs.
- Desktop entries and icons: Quickshell's DesktopEntries (same index as the launcher); load each icon through the icon theme at 48px (96 on HiDPI). Pinned list in the shell's `State`.
- The dock is a layer-shell surface on the bottom edge with **exclusive zone 0**; it must not resize windows.
- Test: open and close a window on an empty tag quickly — the dock must not flash; switch between an empty and a busy tag — it follows within one frame on hide.

## Credits

NixOS snowflake geometry: nixos-artwork, CC-BY 4.0 (https://github.com/NixOS/nixos-artwork/tree/master/logo), traced from the official SVG with all transforms resolved. The one-red-arm colouring is this system's.

## Relationship to the other systems

Quickshell Swiss (bar, glyphs, tokens) · Quickshell Launcher (the NixOS cell opens it). The dock changes neither. Unlike the tray row, dock icons are not tinted: they're large and they're the point.
