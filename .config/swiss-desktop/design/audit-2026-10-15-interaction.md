# NixDesk interaction audit, and the Quickshell Swiss design package (15 October 2026)

Brief: the "complete interaction audit" (discover, inventory, interact, diagnose, fix, retest, verify, report),
extended during the day by the owner's requests and two design packages from Claude Design.

Shell commits on `master`: aab3843 (audit fixes), ea86769 (package integration), 7af2ecf, 5020662, 94a98e4,
ad8d526, 3c4f6ee, 64f8a55, 84024e7, 2130bbd. A second session committed ff47463 (the "design systems" package:
design/swiss, design/now-playing, design/dashboard) in between; my later commits are rebased on it.
Other repos: swiss-desktop 2f23f6d, 907733d (palette); mango 0e25a99, fbbf6f1; kitty.conf edited (backup
`kitty.conf.bak-20261015-1350`, not in git). Backups: tag `pre-audit3` in quickshell, swiss-desktop and mango.

## How it was tested

- **Environment:** Quickshell 0.3.2, mango 0.18.0, PipeWire 1.6.9, BlueZ 5.87, NixOS 26.11, Linux 6.18.55. One monitor:
  DP-2, 2560 x 1440 at 144 Hz, scale 1.
- **Audit rig** (`~/.cache/swiss-desktop-work/audit3`):
  - A headless mango running the real config, with exec_once removed and the colours taken from a copy of
    swiss-desktop.
  - A private session bus that auto-starts nothing.
  - A private PipeWire with two test outputs and a test microphone (`bin/defaults-policy.sh` stands in for
    WirePlumber's default choice).
  - Stand-ins that log instead of acting, for: loginctl, systemctl, `mmsg dispatch quit`, dconf, kitty, `qs ipc`
    and bluetoothctl. The bluetoothctl stand-in emulates BlueZ 5.87's agent prompts.
  - An instrumented copy of the shell in which every Wi-Fi or Bluetooth write logs `AUDIT …` instead of acting.
  - Real input from `vin`, a small Wayland client that keeps one virtual pointer and keyboard (clicks, drags, wheel,
    keys). wlrctl's per-call pointer drops the first click.
  - Three test tray items (StatusNotifierItem + dbusmenu, in Python), two silent mpv players and a test window.
- **System state was read from the system, not from the UI:** wpctl, mmsg, playerctl, busctl, nmcli, and the
  stand-ins' logs.
- **The live desktop** was checked after deployment with screenshots (grim) and IPC only.
- **Evidence labels:** rendered (seen in a screenshot), measured (pixels, wpctl / mmsg / playerctl values), logged
  (a stand-in or AUDIT line), code (read only), unverified.

## A. Interaction inventory and results

Status: PASS, FAIL→FIXED (see B), PARTIAL, BLOCKED, UNVERIFIED, N/A.

### The bar

| Element | Input | Intended | Result |
|---|---|---|---|
| NixOS mark | click, tooltip | dashboard toggles | PASS rendered |
| Tag ticks | click | view that tag | PASS measured (mmsg) |
| Tag ticks | middle click | add the tag to the view, or take it out | PASS measured (1 → 1,3 → 1) |
| Tag ticks | right click | move the focused window there | PASS measured (window to tag 2; mango follows it) |
| Tag ticks | hover | the tick rises to 16 px; tooltip names the tag | PASS rendered |
| Tag ruler | wheel | previous / next tag, clamped at the ends | PASS measured |
| Tag numeral | click | none (dead handler removed) | FIXED, D7 |
| Window title | hover | full title in a tooltip when cut | UNVERIFIED (code) |
| Clock | click, again, tooltip | calendar opens, closes, tooltip | PASS rendered |
| Now Playing: id | click | next player; "+N" when there are several | PASS rendered (switched to the paused player) |
| Now Playing: title | — | scrolls 2 loops, then rests elided | PASS rendered |
| Now Playing: title | hover | replays / pauses the scroll | PASS (code + one render) |
| Now Playing: title | click | media popover | PASS rendered |
| Now Playing: title | middle click | play / pause | UNVERIFIED |
| Now Playing: transport | play / pause | acts on the player | PASS measured (playerctl) |
| Now Playing: transport | previous / next | greyed when the player can't | rendered (disabled for one-file mpv) |
| Now Playing: progress | — | ink line on the bar rule | PASS rendered; stale position FIXED (D21) |
| Tray chevron | click | the drawer opens / closes | PASS rendered |
| Tray chevron | Super+Ctrl+T | toggles the drawer | PASS (IPC) |
| Tray drawer | Esc | closes it | PARTIAL: works once the bar has been clicked while the drawer is open; not right after the chevron opens it (mango grants a layer's on-demand focus on a click). Keyboard focus returns to the window. |
| Tray items | left / middle / wheel | activate / secondary / scroll | PASS logged |
| Tray items | right click | the app's own menu under the bar rule: checkbox shown as a circle, submenu with a way back, disabled entries faint, Pin / Unpin at the foot | PASS rendered + logged |
| Tray items | Esc / outside click / choosing an entry | closes the menu | PASS (focus fix: D15) |
| Tray attention | — | triangle on the chevron; tooltip names the app | PASS rendered |
| Tray pins | pin / unpin | persists across restarts | PASS (Prefs) |
| Tray, live | — | 1Password and RustDesk icons | PASS rendered |
| Claude mark | click, tooltip | popover; tooltip says "near limit" past 80 % | PASS rendered |
| Keep awake | click | toggles (tick short off / tall on) | PASS (toggle measured before the redesign; tick rendered off live) |
| Wi-Fi | click, tooltip | popover; bars by signal with 5 % hysteresis; struck through when off | PASS rendered |
| Bluetooth | click, tooltip | popover | PASS rendered |
| Volume | click | audio popover | PASS rendered |
| Volume | wheel | ±5 % | PASS measured (0.50 → 0.60 → 0.55) |
| Volume | middle click | mute / unmute | PASS measured |
| Volume | — | volume pop-up shown | PASS rendered |
| Volume | tooltip | follows the value | FIXED, D22 |
| Volume | external wpctl change | bar and pop-up follow | PASS rendered (35 %) |
| Bell | click | notification centre | PASS rendered |
| Bell | — | unread (square) / do not disturb (struck through) glyphs | PASS rendered live |
| Light / dark | click | the whole desktop switches (swiss-mode) | PASS logged + rendered (rig) |
| Power | click | session menu | PASS rendered |
| All bar controls | tooltips between neighbours | the next tooltip shows | FIXED, D6 |

### Popovers and overlays

| Surface | Checked | Result |
|---|---|---|
| Audio | Slider click / drag / wheel; mute glyph button; choosing a device; mic slider; arrow keys; Esc; outside click | PASS measured (wpctl). Device switch PASS measured (default changes). Arrow keys PASS before the redesign, not re-run after. |
| Wi-Fi | Switch | PASS logged (AUDIT). Not actually switched: that would change real connectivity. |
| Wi-Fi | New secured network | Password field, Show, at-least-8 rule, Join / Enter, Cancel, Esc: PASS rendered + logged. The real join is UNVERIFIED (no unknown named network in range; joining would change the network). |
| Wi-Fi | Ethernet row | Information only (D5): PASS |
| Bluetooth | Switch, scan switch | PASS logged |
| Bluetooth | Pairing requests (confirm, PIN, passkey, display, authorize, service, cancel) | Popover opens by itself; Pair / Cancel / Refuse answer yes / no; a code is sent on Enter. PASS logged (stand-in). A real device pairing is UNVERIFIED (no device in pairing mode). |
| Bluetooth | Real agent | Registered with BlueZ by the live shell: PASS (process check) |
| Calendar | Month and year keys, Home, arrows, Today, close by clicking the clock | PASS rendered |
| Claude Code | Limits, sessions, today; values not reported say so | PASS rendered |
| Claude Code | New session button | Logged (kitty stand-in), before the redesign |
| Media | Cover placeholder, seek ruler, transport glyphs, players list as radio rows, choosing a paused player | PASS rendered; D10 fixed |
| Notifications | Do not disturb (circle and word), Clear all, cards with actions, empty state | PASS rendered |
| Power menu | Keycaps; armed state ("Press again to …" plus a triangle); Esc disarms | PASS rendered + logged |
| Power menu | Lock / Log out / Restart / Power off | Second press logs `loginctl lock-session` / `mmsg dispatch quit` / `systemctl reboot` / `systemctl poweroff`. None executed. |
| Launcher | Only the field until typing; "ki" → kitty; matches in bold; no matches; Esc | PASS rendered |
| Clipboard | — | UNVERIFIED after the redesign (not opened live: a screenshot would show your clipboard history) |
| Dashboard | Four columns, figures, sliders, device circles, rows that open popovers, Tailscale (read-only), meters, calendar, tiles, Ctrl+T / N / D, ←→ | PASS rendered, dark and light |
| Toasts | Plain, with actions, critical (bar + error glyph), ≤ 3, pause on hover, clear | PASS rendered, rig and live. Two of seven live test toasts were not seen at 0.6-0.8 s (one during a shell reload); not reproduced since. |
| Volume pop-up | — | PASS rendered: 240 x 48 under the bar on the right, "Muted" in words |
| Wallpaper picker | — | PASS rendered live (tokens, eyebrow, count, cards). Setting a picture is UNVERIFIED after the redesign. |
| Polkit prompt | Cancel / Authenticate buttons added | Render UNVERIFIED: a second agent can't register beside the live one. Live agent registered: PASS (log). |
| Focus after any popover closes | — | PASS measured (typing reaches the window) |
| Popups, general | Only one at a time; the bar stays clickable; slide in from 8 px, out | PASS rendered |

## B. Failure register

| ID | Sev. | Defect (evidence) | Cause | Fix |
|---|---|---|---|---|
| D1 | high | No volume slider in a row could be clicked or dragged (wpctl stayed 0.50) | RowItem's MouseArea lay over its content and took every press | MouseArea under the content (aab3843); measured 0.19 / 0.86 |
| D2 | med | Click-to-mute on the value was dead and undiscoverable | as D1 | Fixed, then replaced by a glyph mute button |
| D3 | high | Dashboard Wi-Fi / Bluetooth switches opened the popovers instead of switching (no AUDIT line) | as D1 | Fixed (AUDIT logged); toggles later moved to tiles |
| D4 | low | Wi-Fi / tray / audio cards: 40 px on the right against 16 px on the left (also reported by you) | card sized from the panel's implicit width | sized from its width; measured 16 / 16 |
| D5 | low | Ethernet row highlighted on hover, with no action | — | `interactive: false` |
| D6 | med | Moving straight between bar controls showed no tooltip | the old control's leave cancelled the new one's tip | tip owner |
| D7 | low | Workspace numeral click did nothing | dead handler | removed |
| D8 | med | Power-menu letters read as "lerp" (you); "Enter again" after a click | — | keycaps, hint line, "Press again" |
| D9 | med | Bar icons 2-3 px low (you); later everything 2 px high | baseline arithmetic | baseline 24: content rows 8-23, centred as in the package reference; measured |
| D10 | low | Choosing a paused player while another played did nothing | the player choice preferred any playing player | a pinned choice |
| D11 | low | Tray popover with no apps was blank | — | superseded by the drawer (absent with no apps) |
| D12 | low | Hint lines cut off | too long for the 336 px column | single-spaced separators, shorter hints |
| D13 | low | CPU figure showed "–" for 2 s | needs two samples | second sample after 0.4 s |
| D14 | med | Polkit prompt could only be cancelled with Esc | — | Cancel / Authenticate buttons (render unverified) |
| D15 | high | Introduced, then fixed: Esc on a tray menu left mango's keyboard focus nowhere (the next keystroke was lost) | grab popup closed by the client | menu routed through the popup host; measured "x234" |
| D16 | med | Introduced, then fixed: the tray menu drew at the bottom of its window | a popup that grows while shown keeps its first size | same reroute |
| D17 | high | Introduced, then fixed: Bluetooth confirm prompts never reached the popover | SplitParser without a marker holds the last chunk; a prompt is the last thing bluetoothctl prints | `scripts/bt-agent.sh` ends prompts with a newline |
| D18 | low | Stale mango comments (a "displays panel (Super+P)" that does not exist, "the hostname", "the square") | — | corrected |
| D19 | high | The NixOS mark looked wrong (you) | the package's 16 px glyph blurs the six lambdas | vector mark again, ink 16 x 16 |
| D20 | med | Keep awake's hollow square read as a missing glyph (you) | — | a tick, short off / tall on (your choice) |
| D21 | low | Progress line stale after switching to a paused player | position not re-read | re-read on player change |
| D22 | low | A tooltip on show kept its old text (volume) | — | follows its text |
| D23 | low | The red clock stroke didn't line up with the ruler line under it (you) | 2 px stroke over a 1 px 12:00 tick | 12:00 tick 2 px wide, exactly under the stroke; measured 1279-1280 both |
| R1-R7 | — | Your requests: equal card padding; in-shell Wi-Fi passwords and Bluetooth pairing; launcher empty until typing; slightly more transparency; the design package; a very small tray chevron | — | done; see C and D |

Incidents during testing, all repaired:

- RustDesk's root service respawned its user processes with the rig's private bus. Its tray left your bar, and its
  portal access pointed at the rig. Fixed by stopping the rig's portals and restarting `rustdesk --server/--tray`;
  the rig's bus no longer auto-starts anything.
- For about a minute the rig's shell ran the real bluetoothctl as BlueZ's default agent, before the stand-in replaced
  it. No pairing happened.
- One `pkill`-style pattern killed my own command shell, not the desktop.

## C. Component test matrix (summary)

- **Click:**
  - Every bar control and every popover control: PASS.
  - Real Wi-Fi / Bluetooth / power actions: logged, not executed.
  - Bar title middle click (play / pause): UNVERIFIED.
- **Hover:** tints on every bar slot, row, button, tile and switch; tooltips. PASS.
- **Open / close:** each popover opens under its module (left or right side, centred under the clock), only one at a
  time; Esc, outside click and a second click close it. PASS.
- **Focus:**
  - Popovers take the keyboard and give it back. PASS measured.
  - The tray drawer's Esc needs a click on the bar first. PARTIAL.
  - Tab traversal: controls now accept focus and draw a 2 px red outline, but traversal was not tested. UNVERIFIED.
- **Keyboard:** popover arrow / letter keys PASS, except audio arrows (not re-run after the redesign). Mango binds
  (Super+D, Super+Esc, Super+Space and the Super+Ctrl popups) PASS through the rig's mango.
- **System sync:**
  - Volume, mute and device: measured both ways.
  - MPRIS: measured.
  - mmsg tags: measured.
  - Tailscale read-only state: rendered against `tailscale status`.
  - Wi-Fi state: rendered against nmcli.
- **Errors:** "No report yet" (Claude), "not reported", "No audio output", Tailscale states, the Wi-Fi password-error
  line: code. The polkit error row: code.

## D. Visual findings (design package integrated)

- **Package:** `~/.config/quickshell/design`, now `design/swiss` after the other session's move. In use:
  - Tokens and the palette (also fed to mango, kitty, GTK and the lock screen). Contrast: all 82 pairs pass.
  - Geist type styles, Swiss Glyphs at 16 px, 384 px popups with 24 px padding, eyebrows over short rulers, ruler
    sliders and meters.
  - Marks: circle = on / chosen, ring = off, triangle = attention.
  - Tiles, the tray drawer and Now Playing.
- **Your choices that override it:**
  - The 24-hour day ruler and the centred clock with its red stroke.
  - The keep-awake tick and Claude's own mark.
  - A little translucency: bar 75 %, unfocused windows 88 %, kitty 0.85.
  - The vector NixOS mark.
  - The very small chevron.
- **Glyphs added to the package's grid:** power, square, square-off, bell-unread, tick, chevron-left-small,
  chevron-right-small. The other session added "night".
- **Measured, live:**
  - Every glyph's 16 px box spans bar rows 8-23. Ink runs 12-16 px, as drawn; numerals span rows 7-23.
  - NixOS mark ink 16 x 16; Claude mark 14 x 14; tray icons 16 px.
  - The red stroke sits on the screen's centre: x 1279-1280.
  - The mark starts on the 16 px margin (the ruler's 00:00); the power glyph ends on 24:00.

## E. Regression

- After each fix, its original test was re-run.
- After the integration, every popover was toured in the rig in dark and light, and the bar was re-measured.
- Live after deployment: the bar, the tray drawer with your real apps, a toast with actions, the wallpaper picker,
  the clock stroke, and the log (no warnings).
- Functionality that existed this morning is still there. The tray moved from a popover to the drawer, as the
  package specifies.

## F. Remaining work

- **Unverified:**
  - A real Bluetooth pairing and a real Wi-Fi join.
  - The polkit prompt's render.
  - The clipboard after the redesign.
  - Tab traversal.
  - The middle click on the bar title.
  - A second monitor (the toasts, volume pop-up and polkit prompt use the first screen; popovers follow the bar
    that opened them).
  - Ten minutes of a warning-free log and idle CPU: not measured.
- **Partial:** Esc on the tray drawer right after opening it (see A).
- **Not built:** the second package's full-screen dashboard and Now Playing panel ("5b"). The other session is
  working on them in the same repository.
- **Not in scope on this desktop:** battery, backlight and power profile.

## G. Usage

- **Bar:**
  - Mark: dashboard (Super+D).
  - Tags: click views, middle click adds or removes from the view, right click moves the window, the wheel steps.
  - Clock: calendar (Super+Ctrl+C).
  - Now Playing: the id cycles players; the title opens the media popover (Super+Ctrl+M); middle click plays /
    pauses; ⏮ ⏸ ⏭.
  - Small chevron: the tray drawer (Super+Ctrl+T, Esc after a click). Right click an app for its menu and
    "Pin to the bar".
  - Claude: Super+Ctrl+K. Keep-awake tick: click, or Super+Alt+C.
  - Wi-Fi: Super+Ctrl+W. Bluetooth: Super+Ctrl+B.
  - Speaker: click for the popover, wheel ±5 %, middle click mutes (Super+Ctrl+A).
  - Bell: Ctrl+Alt+\; Ctrl+Alt+Backspace clears.
  - Theme glyph: light / dark (Super+Shift+T).
  - Power: Super+Esc. A letter or ↑↓ chooses; Log out, Restart and Power off need a second press.
- **Launcher (Super+Space):** type to see apps; Enter or Alt+1-9 opens one.
- **Clipboard:** Super+V. **Wallpaper picker:** Super+W.
- **Dashboard:** tiles for Wi-Fi, Bluetooth, DND, night light, keep awake and theme; Ctrl+T, Ctrl+N, Ctrl+D; ←→ month.
- **Wi-Fi:** choose a network; a new secured one asks for its password in place (Show, Join, Esc).
- **Bluetooth:** scan, then choose a device to pair. PINs, passkeys and confirmations appear in the popover; it opens
  by itself when a device asks.
