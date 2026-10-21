# Swiss desktop for NixDesk

**Measure**: a keyboard-first desktop on mango drawn as a precision instrument. The bar's lower edge is a 24-hour
ruler; a red index mark means "now / here" and nothing else. Light Mode is paper and ink, Dark Mode graphite and chalk.
Redesigned on 2026-10-14. The design is described in `design/spec.md`.

## What runs

| Component | Job | Config |
|---|---|---|
| mango | windows, tags, 8 px gaps, neutral focus border | `~/.config/mango/` (git; tag `pre-swiss` = before any of this) |
| quickshell | wallpaper, bar, dashboard, popovers, tray, launcher, clipboard, notifications, volume pop-up, polkit prompt | `~/.config/quickshell/` (git; tags `pre-redesign` = first Swiss shell; commit e1b9cf6 = Omarchy-style) |
| kitty | terminal (Geist Mono; Symbols Nerd Font Mono for icon glyphs); switches colours by itself | `~/.config/kitty/` |
| hyprlock / hypridle | lock screen (wallpaper, the bar's ruled clock at 128 px, ruler), the matrix-rain screensaver and idle timings | `~/.config/hypr/` (`lock-clock.sh`, `screensaver.sh`) |
| Limine, console, ly | boot menu, boot messages and the login screen, always in Dark Mode | `~/nixos/modules/` (`boot.nix`, `theme.nix`; colours from `swiss-colors.nix`, written by `bin/swiss-build`) |
| wlsunset | night light, only while it is on | started by the shell |

Nothing polls. The bar follows mango through one `mmsg watch all-monitors` stream, volume through PipeWire, network
through NetworkManager, Bluetooth through BlueZ, notifications over D-Bus; the clock ticks once a minute. Wi-Fi scanning
runs only while the network popover is open; system load, Tailscale and the Claude Code logs are read only while the
dashboard is open.

Type (the typography audit of 16 October 2026): one family in two cuts. **Geist** for everything set in sans and
**Geist Mono** for annotations, terminals and code (Vercel, SIL OFL-1.1, a grotesque built on the principles of classic
Swiss typography). Where each surface takes it from:

| Surface | Font | Set in |
|---|---|---|
| fontconfig: `sans-serif`, `system-ui`, `monospace`, `serif` | Geist; Geist Mono, then Symbols Nerd Font Mono for icon glyphs; Libron | `~/nixos/modules/fonts.nix` (Noto fills what Geist lacks: Tamil, CJK) |
| GTK 3 / 4 and libadwaita apps, Zen's interface | Geist 11, monospace Geist Mono 11 | dconf `org/gnome/desktop/interface` (defaults in `~/nixos/modules/theme.nix`) |
| Qt apps (qimgv, CoolerControl, OpenRGB) | GTK's fonts, through `QT_QPA_PLATFORMTHEME=gtk3` | `~/nixos/modules/theme.nix` |
| The shell | the scale below | `~/.config/quickshell/Theme.qml` (`font.sans`, `font.monoFamily`) |
| kitty | Geist Mono 11, Symbols Nerd Font Mono for the private-use planes | `~/.config/kitty/kitty.conf` |
| Lock screen | Geist (clock, date), Geist Mono (annotations) | `~/.config/hypr/hyprlock.conf` |
| mango's tab bar and jump labels | Geist Medium 9, Geist Mono Bold 12 | `templates/mode/mango-colors.conf` |
| Zed, Doom Emacs | Geist / Geist Mono | their own settings (`~/.config/zed`, `~/.config/doom`) |
| Console, ly | Terminus 32 (a bitmap console font: the text console cannot draw Geist) | `~/nixos/modules/theme.nix` |
| Web pages | their own fonts; the defaults (`sans-serif`, `monospace`) are fontconfig's | Zen |

The shell's scale, every style named in `Theme.qml` (size / line height, weight): display 48 / 48 Bold, h1 32 / 40
Bold, stat 32 / 40 DemiBold, count 22 / 24 Bold (the bar's numerals), h2 20 / 24 DemiBold (panel titles), body 14 / 20,
mono 13 / 20 (Geist Mono: metadata), label 12 / 16 Medium (bar text), caps 11 / 16 DemiBold tracked (eyebrows). Large
sizes are tightened, small capitals opened; figures are tabular everywhere (`components/Txt`). Body 14 px sits with
GTK's 11 pt (14.7 px) and kitty's 11 pt.

Icons: the shell's glyphs are **Swiss Glyphs** (`~/.config/quickshell/design/glyphs`, the system's own font: a 16 px
grid, 2 px strokes, a 14 px live area), drawn by `components/Icon` in ink; a level never changes a glyph's outline, and
states have their own glyphs, never colour alone. Apps in the dock, the launcher and the tray are the **Swiss app
icons** (`design/app-icons`: one-colour pictograms on a 48 px master and a 16 px drawing, painted in ink); in the dock
each stands on a 48 px tile. GTK apps keep Papirus (light / dark by mode). Claude Code is shown by Claude's own mark.

Geometry: one measure for the frame. The bar is 32 px with an 8 px margin, its baseline 24 px from the top; mango's gaps
are 8 px everywhere (`~/.config/mango/config.conf`), so window edges run on the ruler's 00:00 and 24:00 ticks and the
dock's bottom edge on the windows' bottom border; windows have a 1 px frame, the focused one in ink. Spacing inside the
shell is a 4 px scale (4 / 8 / 12 / 16 / 24 / 32) in `Theme.qml`.

The mark: the NixOS snowflake (nixos-artwork, CC-BY 4.0) set flat, five arms in ink and one in the red
(`components/NixMark`, at 24 px in the bar and 32 px on the dashboard's masthead; the lock screen's logo is generated from
the same drawing). It stands alone, with no name (the hostname may change).

Translucency: the bar and the dock are 68 % opaque over the wallpaper; unfocused windows are 82 % opaque (browsers and
terminals stay solid); kitty's background is 94 % (80 % until the kitty audit of 18 October 2026: the posters'
headlines showed through and quiet text fell to about 3:1). Popovers, the dashboard and the lock screen stay opaque,
for reading.

## The bar

```
✻ │ 1 /5  ı ▪ ı ı ı   kitty  title …      Wednesday  21 ┃ 06  14 October      ▷ Title  2 apps │ >_ ☕ wifi ᛒ vol bell ☀ │ ⏻
├━━━━━━━━━━━━━━━━━━━━━━━━━ the day so far ━━━━━━━━━━━━━━━━━━━━━━━━━━┼─────┼──── 24-hour ruler ────┼─────┼─────┤
```

| Item | Left click | Right click | Scroll / other |
|---|---|---|---|
| ✻ the mark | dashboard | | |
| Folio ticks (tall = windows, red = current) | view that workspace | | scroll anywhere on the folio: previous / next |
| Clock (weekday, hours ┃ minutes, date; week and year in its tooltip) | calendar | | |
| Now playing (play / pause icon, title, artist; only while a player has a track) | media popover | | middle click: play / pause |
| "2 apps" (the tray, folded) | the tray apps in a popover: their icons, actions and menus | | the bar never shows tray icons; the apps keep running |
| Claude's mark: Claude Code (amber past 80 % of a plan limit) | Claude Code popover | | tooltip: the reported limits |
| Coffee cup: keep awake (ink with a tick under it while on) | switch it on / off | | the screen neither locks nor sleeps while on |
| Wi-Fi (strength lit over the full fan; a network symbol on a cable; amber: no internet) | Wi-Fi popover | | |
| Bluetooth (off / on / connected glyphs) | Bluetooth popover | | |
| Volume (one speaker; its own symbol when muted; no number) | audio popover, with the value | mute | scroll: ±5 % |
| Bell (a dot: unread; struck: do not disturb) | notification centre | | |
| Sun / moon: the mode in use | switch Light / Dark (the whole desktop, remembered) | | |
| Power | session menu | | |

Hover anything for a tooltip. While a popover is open, a red mark rises from its control into it (for the clock, from
its stroke).

## Keys

| Keys | Action |
|---|---|
| Super+Space | launcher: type, ↑↓ or Ctrl+J/K, Enter starts, Alt+1-9 starts row n, Esc closes |
| Super+V | clipboard history: Enter or Alt+1-9 copies again, Delete forgets |
| Super+D | dashboard: Ctrl+T light/dark, Ctrl+N night light, Ctrl+D do not disturb, ←→ calendar month |
| Super+W | wallpaper picker: ←→ move, Enter set for the mode in the heading, Tab other mode, Backspace up |
| Super+Esc | session menu: Lock, Log out, Restart, Power off (L/E/R/P); the last three need a second Enter |
| Super+Ctrl+C | calendar: ←→ month, ↑↓ year, Home this month |
| Super+Ctrl+A | audio: ↑↓ row, ←→ volume, M mute, Enter switch output or input |
| Super+Ctrl+W | Wi-Fi: ↑↓ network, Enter connect (asks for a password if needed) |
| Super+Ctrl+B | Bluetooth: ↑↓ device, Enter connect / pair, S scan |
| Super+Ctrl+K | Claude Code |
| Super+Ctrl+M | now playing: Space play, ←→ 5 s, N / P track |
| Super+Ctrl+T | tray apps |
| Super+Alt+C | keep awake on / off |
| Ctrl+Alt+\ | notification centre: D do not disturb, Delete clear all |
| Ctrl+Alt+Backspace | clear notifications |
| Super+Shift+T | Light / Dark Mode (also the sun / moon in the bar and Light / Dark in the dashboard) |
| Super+Alt+N | night light |
| Super+Shift+R / Super+R | reload the shell / reload mango |

## Dashboard

Super+D or a right click on the NixOS mark (a left click opens the launcher). One sheet, 1152 px, centred on the
screen (design/dashboard v2, "the instrument sheet"): a masthead (the mark; host, system and uptime), four headline
figures (processor %, graphics %, memory % used, processor package °C), then one 40 px row per vital with its
ten-minute sparkline (recorded in the background, so it is full when the sheet opens):

| Section | Rows | Source |
|---|---|---|
| Compute | processor, each thread, graphics | `/proc/stat`, `nvidia-smi` (only while open) |
| Memory | memory, video memory | `/proc/meminfo`, `nvidia-smi` |
| Heat | processor package; the cooler's fan and pump | hwmon (coretemp, the Kraken), one reader (scripts/metrics.pl) |
| Network | down, up (the default route's interface) | `/proc/net/dev` |
| Processes | the top 8 by processor, grouped by app; a right click ends one | `/proc/<pid>/stat` |
| Storage | at most four filesystems, "+N more" | `df` |
| Controls | Tailscale and its DNS, night light and its temperature, keep awake and do not disturb with their holds | the services below |

No battery section: this machine has none. Brightness is the Display popover (the sun in the bar), Claude Code has
its own popover (its mark in the bar), session actions are in the power popover.

### Claude Code

Two sources, kept apart:

- **Reported by Claude Code**: model, context window (used, left), session cost estimate and, on Pro / Max plans, the
  five-hour and weekly limits with reset times. Claude Code passes these as documented JSON to its status line;
  `~/.config/quickshell/scripts/claude-statusline.sh` (set as `statusLine` in `~/.claude/settings.json`) saves each
  session's report under its session id (`~/.cache/swiss-desktop/claude/sessions/<id>.json`, private to you, kept
  a day) and the newest one as `status.json`, and prints a short line in Claude Code. The popover shows the plan
  limits from the newest report (they are account-wide), then one line per session with its own context and cost,
  never mixing sessions; each report shows its age. Without a report it says "No report yet".
- **Local logs, today** (an estimate): input, output and cache tokens summed from `~/.claude/projects/*/*.jsonl` by
  `scripts/claude-usage.sh`, counted once per response, only files changed today, every 60 s while the popover is
  open. The log format is internal to Claude Code; if it changes, the popover says "Usage unavailable".

Nothing is uploaded and no conversation text is shown. To remove the status line, delete the `statusLine` entry from
`~/.claude/settings.json`. Claude Code's own theme is set to "auto", so it follows kitty, which follows Light / Dark Mode.

### Tailscale

`tailscale status --json` with a 4 s timeout, when the dashboard opens and every 30 s while it is open (the Network
popover reads it every 5 s while open). States: **Connected** (IP, devices online, tailnet), **Disconnected**
(stopped), **Service not running** (neutral, not red), **Needs login**, **Starting**, **Not installed**, **Unknown**
(with the reason; a failed check is never shown as Disconnected). The time it was read is shown under it. The
dashboard's switch runs `tailscale up` / `down` (kishan is Tailscale's operator, so no sudo; Tailscale DNS stays off
unless its own switch is on), and the Network popover picks an exit node.

Every popover: Esc or a click outside closes it; clicking another bar control switches to its popover. Each one ends
with its keys as a small annotation.

## Light and Dark Mode

```
bin/swiss-mode light | dark | toggle | status
```

| What | How it follows | When |
|---|---|---|
| bar, popups, notifications, wallpaper | shell watches `~/.local/state/swiss/mode` | at once |
| window borders, desktop colour | `mango/colors.conf` -> `build/current/`, then `mmsg dispatch reload_config` | at once; windows stay put |
| kitty | its own `light-theme.auto.conf` / `dark-theme.auto.conf`, from the system colour scheme | at once, in open windows |
| fish, lazygit | ask kitty for its background: fish's `swiss` theme (`~/.config/fish/themes/`) and lazygit's `lightTheme` / `darkTheme` (`~/.config/lazygit/config.yml`), both from `build/` | at once, in open shells and lazygit |
| fzf, starship, fastfetch, eza, git | the 16 terminal colours only, so kitty's palette decides | at once |
| GTK 4 apps, browsers, Electron apps | dconf `color-scheme` through the desktop portal; `gtk-4.0/gtk.css` has both palettes | at once (apps that follow the system) |
| GTK 3 apps | dconf `gtk-theme` and `gtk-3.0/gtk.css` -> `build/current/` | not checked in a live GTK 3 app |
| lock screen, btop | `build/current/` | next time they start |
| boot menu (Limine), console, login screen (ly) | Dark Mode only: `bin/swiss-build` writes `~/nixos/modules/swiss-colors.nix` from `tokens/dark.env` | after `nrs` |
| Qt apps (OpenRGB, qimgv, CoolerControl) | not themed | their own look |

Wallpapers: `~/Pictures/Wallpapers/` (sources in `SOURCES.txt`). To use another picture for a mode, change `wallpaper=` in
`tokens/<mode>.env` (path relative to your home) and run `bin/swiss-build`.

### Terminal colours

kitty's 16 colours are `ansi0`-`ansi15` in the tokens, one palette per mode with the same meanings. What a terminal
config may rely on, in both modes (kitty audit, 18 October 2026; `tests/contrast.sh` checks the pairs):

| Use | Slot | Why |
|---|---|---|
| text | 39 (default) or 15 (bright white) | 15 is the strongest ink in Light Mode, near-white in Dark Mode |
| quiet text (paths, times, counts) | 8 (bright black) | 5.2:1 on paper, 5.3:1 on graphite |
| meanings | 1 red, 2 green, 3 yellow, 4 blue, 5 magenta, 6 cyan | 5.4-9:1 as text in both modes; 9-14 are deeper (Light) or lighter (Dark) |
| text on a coloured ground | Light Mode: white (7) on 1-6 or 8; Dark Mode: black (0) on 1-6 | the colours are dark on paper, light on graphite |
| a selected line | the `selection` token (fish, lazygit), or reverse video | 13.6:1 / 12:1 under normal text |

Never white (7) as text: in Light Mode it is a light ground (the surface2 grey), nearly invisible on paper. Colours
16-255 are kitty's fixed xterm values in both modes (the grey ramp 232-255 runs dark to light whatever the mode), so
configs avoid them. Faint text (SGR 2) is kitty's `dim_opacity 0.7`: 2.9:1 on paper, still clearly quieter on
graphite. The same 16 colours are the terminal palettes of Neovim's `:terminal` and Zed's terminal.

## Files

```
~/.config/swiss-desktop/
  tokens/light.env, dark.env    every colour and the wallpaper, by name (edit here)
  templates/mode/*              one file per app, filled once per mode
  templates/both/gtk4.css       filled with both modes at once
  bin/swiss-build               tokens + templates -> build/   (run after any edit above)
  bin/swiss-mode                chooses build/light or build/dark
  build/{light,dark}/           generated (not in git: run swiss-build); build/current links to the active one
  tests/contrast.sh             WCAG contrast of every pairing the desktop draws (82 pairs)
  tests/lint.sh                 build + contrast + mango config + links (safe to run anytime)
  tests/measure.sh [s]          CPU and memory of mango and quickshell
  backups/<time>/               files as they were before (not in git)

~/.config/quickshell/            the shell (its own git repo): the folder map is at the top of shell.qml,
                                 the agents' notes and the owner's choices in CLAUDE.md
```

Preferences that survive a restart live in `~/.local/state/swiss/` (`mode`, `shell.json`).

## If something breaks

- **Bar or popups gone:** mango keeps running without the shell. Super+Return opens kitty; run `quickshell &`, or read `qs log`.
  A shell file with an error does not take the running shell down: the last working version stays until the file is fixed.
- **Wrong colours after an edit:** `tests/lint.sh` names what is wrong; `bin/swiss-build` rebuilds.
- **mango will not start or reload:** `mango -p -c ~/.config/mango/config.conf` names the bad line.
- **From another machine:** SSH over Tailscale works whatever the desktop is doing; Ctrl+Alt+F2 gives a local console.
- **Never start a second, nested mango for testing without stand-ins for `systemctl` and `dbus-update-activation-environment`:**
  mango points the whole session's activation environment at itself on start and stops `graphical-session.target` on exit.

## Undo

Back to Measure without the dashboard (before this round): `git -C ~/.config/quickshell checkout ef94fa3 -- . && git -C ~/.config/quickshell clean -fd`,
then delete the `statusLine` entry from `~/.claude/settings.json`.

Back to the previous, Omarchy-style shell (before Measure):

```
git -C ~/.config/quickshell checkout e1b9cf6 -- . && git -C ~/.config/quickshell clean -fd
git -C ~/.config/swiss-desktop checkout 60c05af -- tokens && ~/.config/swiss-desktop/bin/swiss-build
cp ~/.config/swiss-desktop/backups/pre-redesign/hyprlock-redesign.conf ~/.config/hypr/hyprlock.conf
```

Back to the first Swiss shell (before this redesign):

```
git -C ~/.config/quickshell checkout pre-redesign -- . && git -C ~/.config/quickshell clean -fd
git -C ~/.config/swiss-desktop checkout pre-redesign -- tokens templates && ~/.config/swiss-desktop/bin/swiss-build
sed -i 's/^gap_\(inner\|outer\)_\(horizontal\|vertical\)=8/gap_\1_\2=16/' ~/.config/mango/config.conf
cp ~/.config/swiss-desktop/backups/pre-redesign/hyprlock.conf ~/.config/hypr/hyprlock.conf
```

Everything (back to before the Swiss desktop): `git -C ~/.config/mango checkout pre-swiss -- .`, remove `~/.config/quickshell`,
and restore `~/.config/hypr`, `~/.config/btop` and the dconf settings from `backups/20261014-190112/`.
