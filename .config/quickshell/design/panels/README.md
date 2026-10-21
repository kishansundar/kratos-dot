Every panel of the Quickshell Swiss shell, in one system: network (wired, Tailscale, Wi-Fi), Bluetooth, sound, notifications, date and time, the power menu, and the control-centre tiles — all built on one Popup shell. Each opens from its glyph in the bar and hangs from the bar rule under it. They use Quickshell Swiss's tokens unchanged — Geist, Swiss Glyphs, light and dark, the 8px grid, the ruler, the ink marks — and add only panel geometry, timeouts and interaction defaults.

## Principles

1. **Hung from the bar.** Every panel opens under its own bar glyph, flush with the bar rule, aligned to it. One panel at a time; opening another closes the first.
2. **State is a circle.** Filled circle = selected / connected / on, ring = not. Switches are a word with that circle, never a sliding pill.
3. **One red per panel, and usually none.** `accent` appears only for the panel's single primary action when one exists — **connect**, **pair**, **shut down** — today in the calendar, and the power countdown. Everything else is ink.
4. **Lists, not cards.** Rows separated by space and 1px rules; sections by an eyebrow with its ruler.
5. **Read the truth back.** A switch or row shows "…" while a command runs and shows the real resulting state, or "failed" / a specific message with the error glyph. Never optimistic.
6. **Dangerous things count down.** Log out, reboot and shut down run after a visible, cancellable 5 s countdown.
7. **Hand off what doesn't fit.** Enterprise Wi-Fi, VPN setup, codecs, advanced audio go to the system's settings apps via a footer link.

## Panels

| Panel | Opens from | Contents |
|---|---|---|
| WifiPanel ("Network") | network glyph | wired link, Tailscale (status, IP, DNS option, exit node, peers), connected Wi-Fi + details, networks in range, password form, radio switch |
| BluetoothPanel | Bluetooth glyph | connected (with battery), paired, nearby while searching, pairing code, adapter switch |
| VolumePanel | audio glyph | output level + devices, input level + devices, per-app volume |
| NotificationsPanel | bell / IPC | DND, history grouped by app, clear all |
| DateTimePanel | the clock | live time and date, month calendar (browse, week numbers), world clocks, sync state |
| PowerMenu | `power` glyph (bar's far right) | lock, suspend, log out, reboot, shut down + countdown |
| Tile | control centre | square quick toggles (on = inverted ink + filled circle) |

All are SPopups (see Popup), `popupWidth` (384) except the power menu (`powerWidth`, 240).

## Type and colour

`h2` panel titles with the heading ruler; `caps` eyebrows; `body` rows; `mono` for addresses, speeds, battery, times, backends; `display` only for a pairing code and the date panel's time. Colours are Quickshell Swiss's: `surface` panel, `line` rules and borders, ink everything, `accent` per principle 3, `error` with its glyph for failures.

## Behaviour

- Esc closes; Tab follows reading order; arrow keys move within lists; Enter acts.
- Scanning (Wi-Fi, Bluetooth) runs only while the panel is open, for `scanTimeout` (30 s).
- Connect / pair attempts time out after `connectTimeout` (20 s) with a message.
- Volume sliders stop at 100 % and step 5 %.
- Notification history persists across restarts; clear all can be undone for 5 s.

## Icons

Swiss Glyphs: `wifi-0…4`, `lan`, `lock`, `bluetooth`, `headphones`, `volume-*`, `mic` / `mic-off`, `bell-off`, `close`, `error`, and `power` (added for the power menu's bar entry).

## Relationship to the other systems

- **Quickshell Swiss** — the bar and its in-bar modules (tags, clock, Now Playing strip, tray drawer, status glyphs); every panel here opens from one of them. Tokens and the stylesheet are Swiss's.
- **Quickshell Now Playing** — the media player panel (opened from the bar's Now Playing title); kept separate.
- **Quickshell Swiss Dashboard** — the full-screen system overlay; kept separate.
