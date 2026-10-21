# AGENT BRIEF — Quickshell Swiss: a desktop shell for MangoWC on NixOS

You are building a desktop shell in **Quickshell (QML, Qt 6)** for the **mango (MangoWC)** Wayland compositor on **NixOS (unstable)**, implementing the **Quickshell Swiss** design system that lives in `design/` in this repo. The design system is the source of truth for every visual decision; this brief tells you how to build it safely. Read this whole file, then `design/swiss/README.md`, before writing anything. Work in phases; each ends with a gate where you stop and report.

---

## 0. Non-negotiable rules

1. **Do not break the working system.** Before editing, moving or deleting any existing file, copy it to `<path>.bak-<YYYYMMDD-HHMM>`. Never run `nixos-rebuild switch`, `home-manager switch` or `nh os switch` before the matching `build` has succeeded and you have shown me its result.
2. **Ask before anything irreversible:** deleting files, changing flake input pins, login / display-manager / autologin, GPU or driver modules, `nix-collect-garbage`, rewriting git history, replacing a running notification daemon, adding mango keybinds, changing mango autostart.
3. **Inspect, don't assume.** Discover: flake layout and host names; whether home-manager is a NixOS module or standalone; how mango is installed and where its `config.conf` / `autostart.sh` live; the installed Quickshell and Qt versions and which `Quickshell.*` modules exist; mango's IPC (`mmsg --help`: newer builds take JSON commands — `mmsg get all-tags`, `mmsg watch all-tags`, `mmsg dispatch …`; older ones take flags — `mmsg -g -t`, `mmsg -w`). Build against what is installed and record which interface in `README.md`.
4. **Git:** the flake evaluates from git — `git add` new files before building. Commit at the end of each phase with a clear message. Never force-push.
5. **One source of truth.** Every colour, size, spacing, radius, font, duration lives only in `Theme.qml` (and `theme/palette.json`, copied from `design/swiss/palette.json`), and those mirror `design/swiss/tokens.json` exactly. Before every gate this must return nothing:
   `rg -n '#[0-9A-Fa-f]{6}|pixelSize: *[0-9]|spacing: *[0-9]|radius: *[1-9]|width: *[1-9]|height: *[1-9]' --glob '!Theme.qml' --glob '!design/**'`
6. **No invented APIs.** Use only Quickshell types and properties present in the installed version (check quickshell.org/docs for that version, or the installed QML modules). Say what you checked.
7. **Hot reload.** Quickshell reads QML from the repo working tree via `xdg.configFile."quickshell/swiss".source = config.lib.file.mkOutOfStoreSymlink "<repo>/quickshell-swiss";` (or the repo's equivalent). Nix installs only packages, fonts and the symlink. Run with `qs -c swiss`.
8. **Report honestly.** At each gate: what works, what doesn't, what you could not verify. Never claim visual correctness without a screenshot (`grim -o <output>`).

---

## 1. Target

| Item | Value |
|---|---|
| Host | **Desktop only**: i7-8700K, NVIDIA GTX 1070 (Pascal), ASUS Maximus X (on-board Wi-Fi + Bluetooth). No battery, no backlight. Touch no other host in the flake. |
| GPU | Read-only for you: report the driver (`nvidia-smi`, `lsmod \| rg nvidia`) and any flicker; never change driver, kernel params or `hardware.nvidia.*`. |
| Monitors | Discover count, names, resolution, scale (`mmsg`, `wlr-randr`). One bar per monitor. |
| Session | Started from mango autostart or a `systemd --user` service (whichever the repo already uses), guarded so it never runs twice. Propose the exact line; add it only after I approve. |

---

## 2. The design system — read these, in this order

1. `design/swiss/README.md` — principles, colour meanings, type, layout, the ruler, states, motion, iconography. **Follow it literally.**
2. `design/swiss/tokens.json` — every value. Mirror it into `Theme.qml` (`pragma Singleton`, `readonly property` per token, grouped: `Theme.color.*`, `Theme.font.<style>.{family,size,weight,lineHeight,letterSpacing}`, `Theme.space.s0…s8`, `Theme.size.*`, `Theme.radius`, `Theme.dur.*`). `Theme.qml` loads `theme/palette.json` with `FileView` (watched) for live tuning.
3. `design/swiss/components/<Name>/README.md` before building each component; `preview.html` beside it shows the intended look (a reference, not code to port — open it in a browser to compare).
4. `design/glyphs/` — the icon font and its `Glyphs.qml` map.

Key rules you will be checked against (all from the README):
- **One accent.** Swiss red (`accent`) marks exactly one thing per view: the focused tag tick, today, the primary action, the focus ring (and a slider's value tick only while hovered / dragged). Everything else is ink and neutrals. `ok` / `warn` / `error` only for a real state, always with a glyph or word.
- **Three marks, in ink** (borrowed from the Bauhaus): filled circle = on / selected, 2px ring = off, solid triangle = attention (urgent tag cap, near-limit meter, weak signal — always with a word). Circles and triangles are never coloured. `radiusCircle` exists only for the circle mark; every rectangle has radius 0.
- **Light and dark are equals.** Both themes must look right before anything is "done". Colours animate on switch (`durFast`); layout never changes.
- **The ruler** is the signature: heading rulers, ruler slider, meter, tag ruler, ruled clock (`HH | mm`), module ticks on the bar's bottom rule.
- Sentence case for content and labels; section eyebrows in `caps` (UPPERCASE); metadata in Geist Mono, lowercase, `textMuted`.
- Hairlines, not boxes; no shadows, blur, gradients.
- Tabular figures on every changing number (`font.features: { "tnum": 1 }`, Qt ≥ 6.6; if older, use Geist Mono for those numbers and say so).
- Everything clickable ≥ `hitTarget` (32 px), except tag ticks (documented exception).

---

## 3. Fonts and glyphs (Nix)

- Packages: `geist-font` (Geist + Geist Mono — verify Geist Mono is in it; if not, report and propose a fix), `noto-fonts` (Noto Sans Tamil fallback is required — Tamil window titles must render).
- Glyph font: `design/fonts.nix` installs Geist, Noto and `design/glyphs/SwissGlyphs.ttf` in one list:
  ```nix
  fonts.packages = [ /* existing */ ] ++ (import ./quickshell-swiss/design/fonts.nix { inherit pkgs; });  # adjust the path to the repo layout
  ```
  (or add it to `home.packages` with `fonts.fontconfig.enable = true`, whichever the repo already uses).
- Verify before first use: `fc-list | rg -i 'geist|swiss glyphs|noto sans tamil'` — use exactly the family names it prints.
- Copy `design/glyphs/Glyphs.qml` into the shell as a singleton (register in `qmldir`). Icons are `SIcon { glyph: Glyphs.wifi3 }` — a `Text` in family `Swiss Glyphs`, `Theme.size.iconBar`, positioned on whole pixels. Never type codepoints by hand.
- At startup, check the glyph font loaded (e.g. a `FontLoader` or `Qt.fontFamilies()` check) and log one warning if not.
- The NixOS mark is two stacked glyphs (`Glyphs.nixosA` in `accent`, `Glyphs.nixosB` in `text`). Its geometry is the official snowflake (NixOS/nixos-artwork, CC-BY 4.0): credit it in `README.md`.
- To add or change a glyph: edit `design/glyphs/defs.py`, run `python3 design/glyphs/build.py design/glyphs` (needs `shapely`, `fonttools`, `brotli`), commit the regenerated font, `Glyphs.qml`, `glyphs.json` and SVGs together. Codepoints are append-only.

---

## 4. File structure

```
quickshell-swiss/
├── design/                 # the design system (read-only for you, except glyph additions)
├── shell.qml               # ShellRoot: Bar per screen, Notifications, Osd, ControlCentre, IpcHandlers
├── Theme.qml               # pragma Singleton — ALL tokens, mirrored from design/swiss/tokens.json
├── Glyphs.qml              # copied from design/glyphs/
├── qmldir
├── theme/palette.json      # copied from design/swiss/palette.json (light + dark)
├── services/               # singletons, no visuals: Mango, Audio, Network, Bluetooth, Notifs, Media, Idle, State
├── components/             # SText, SIcon, SRuler, SMeter, SSlider, SButton, STile, SDeviceRow, SPopup, STooltip, marks (SCircle, STriangle)
├── modules/                # bar modules: NixMark, Tags, Title, Media, Status, Clock
├── panels/                 # SPopup, NetworkPanel, BluetoothPanel, VolumePanel, NotificationsPanel, DateTimePanel, PowerMenu, ControlCentre (Tiles), NowPlayingPanel
├── overlays/               # Toasts, Osd
├── .qmlls.ini              # for Zed completions (no machine-specific paths if avoidable)
└── README.md               # wiring, mmsg interface used, contrast table, decisions, known limits, backups, credits
```

`SText` takes a `variant` (`display`, `count`, `h1`, `h2`, `body`, `label`, `caps`, `mono`) and reads `Theme.font.<variant>`; nothing else sets font sizes.

---

## 5. Components (build in this order; each needs default, hover, pressed, focus, disabled and empty states)

1. **Primitives:** `SText`, `SIcon`, the three marks, `SRuler` (heading ruler and full-width), `SButton`.
2. **Bar** (`design/swiss/components/Bar`): 1px `line` bottom rule with module-start ticks; left — NixOS mark, Tags, app id (mono) + title; right — Media, Status glyphs (agent, awake, network, Bluetooth, audio), Clock. Layer-shell namespace `quickshell-swiss-bar`, exclusive zone = `barHeight`.
3. **Tags** (`services/Mango.qml` + `modules/Tags.qml`): `mmsg` in watch mode via `Process` + `SplitParser`, parsed per monitor into `{ index, occupied, focused, urgent, clientCount }`, `layout`, `focusedTitle`, `focusedAppId`. Restart the watcher with backoff (1 s → 5 s) and log it; no zombie `mmsg` after reload. Click = view, middle = toggle view, right = move focused client, scroll = next / prev.
4. **Clock** (`HH | mm`, ink separator tick); a click opens the **DateTimePanel** (`design/panels/`: live time, month calendar with today = `accent` fill, Monday first, ISO weeks, world clocks).
5. **Audio** (`Quickshell.Services.Pipewire`, bind `PwObjectTracker` for nodes you read): bar glyph by level (`volume0…2`, `volumeMute`), scroll ±5 %, middle-click mute; popup with output / input `SSlider`s and device rows (filled ink circle = selected, ring = not).
6. **Network**: native module only if the installed Quickshell has one; else `nmcli -t` polled ≤ 5 s and on popup open. Wi-Fi glyph by band (`wifi0…4`); a weak link adds an ink triangle with the word "weak"; never log passwords.
7. **Bluetooth**: `Quickshell.Bluetooth` if present, else `bluetoothctl`; hide entirely without an adapter.
8. **Stay awake**: an idle inhibitor (use Quickshell's idle-inhibit type if the installed version has one; otherwise `systemd-inhibit --what=idle` held by a `Process`). Glyph `awake` / `awakeOff`; toggle in the bar and the control centre; persisted in `State`.
9. **Agent sessions** (optional, ask first): glyph `agent` with a count of running coding-agent sessions and a meter panel for plan limits, as in `design/swiss/components/Meter`. Ask me where the data comes from before building it; do not scrape anything.
10. **Tray drawer** (`Quickshell.Services.SystemTray`, spec: `design/swiss/components/Tray`): a chevron in the bar; clicking it slides the tray icons out *inside the bar* to its left (no panel, no floating window). Animate the drawer's width over `Theme.dur.drawerOpen`, instant under `reduceMotion`; mark its extent with a 2px ink line on the bar rule. Stays open until the chevron or Esc closes it. Pinned item ids live in `State` and stay visible when closed. A hidden `NeedsAttention` item puts an ink triangle on the chevron and names itself in the tooltip. Left click = activate, middle = secondary activate, right = the item's own menu as a dropdown hung from the bar rule (use `QsMenuAnchor` or the installed equivalent). App icons as given at 16 px; passive items hidden unless pinned.
11. **Notifications** (`Quickshell.Services.Notifications`): first check no other daemon owns `org.freedesktop.Notifications` (`busctl --user status org.freedesktop.Notifications` or equivalent); if one does, stop and ask. Toasts per `design/swiss/components/Toast`; history and DND in the control centre; DND persisted.
12. **Now Playing** (`Quickshell.Services.Mpris`, spec: `design/swiss/components/NowPlaying`): player id (mono) · title slot · previous / play-pause / next, at the right of the bar's right group before the tray. Text `Title — Artist` in a slot no wider than `Theme.size.npTextMax` (192 px); it shrinks for short text; the transport stays fixed at the module's right edge. When the text overflows: hold `marqueeHold`, scroll at `marqueeSpeed` px/s (linear) inside a clipped slot, the text followed by a copy `marqueeGap` later so it loops seamlessly; run two loops after each track change, then rest elided; hover replays and pauses; never scroll under `reduceMotion` (elide + tooltip). Implement the scroll with a `NumberAnimation` on `x` of a two-copy `Row` inside a clipping `Item` — measure with `TextMetrics`/`implicitWidth`, no timers polling the text. Progress: a 2 px ink line on the bar rule under the slot (position / length, updated ≤ 1 Hz; hidden for streams). Paused: title `textMuted`, play glyph. Buttons disabled when the player can't do the action. Several players: `+N` after the id; clicking the id cycles, preferring the one playing. No player: the module is absent. Title click opens the Media popup (art, seek ruler, player list); middle-click toggles play / pause.
13. **OSD** (`design/swiss/components/Osd`): right-aligned under the bar, never bottom-centre; fades after 1.2 s.
14. **Control centre**: tiles (Wi-Fi, Bluetooth, DND, stay awake, theme — the theme tile shows the mode as a word, LIGHT / DARK), sliders, media, notification history. IPC `qs ipc call cc toggle`.
15. **Theme**: `State.qml` persists the mode in `$XDG_STATE_HOME/quickshell-swiss/state.json` (written atomically). `IpcHandler` target `theme` with `toggle()`, `set(mode)`, `get()` (`qs ipc call theme toggle`). Propose a mango keybind; add it only after I approve. Optional, ask first: also set `gsettings … color-scheme` so GTK apps follow (check `gsettings`/`dconf` exist).

**Not built:** battery, power profile, backlight, lock screen, wallpaper.

---

## 5b. The sibling systems

- **Now Playing panel** — `design/now-playing/` (README first, then Layouts and States). Version 2: the art's aspect ratio picks the layout (album / video / bare), the time row has four forms (seekable, read-only, live, untimed) chosen from what the player reports — never "live" just because length is missing — and the play square's focus ring shows only for keyboard focus. Before writing QML, run `playerctl -l`, `playerctl -p <name> metadata` and `playerctl -p <name> position` for Zen (YouTube tab) and one music player and commit the output; test the layout and time-row choice against it. Build it as `panels/NowPlayingPanel.qml` on the same `Theme.qml`; add `artSize`, `artWideRatio`, `playButton`, `positionTick`, `seekStep`, `volumeStep`, `titleLines`, `titleLinesWide`, `artSquareMin`, `artSquareMax`, `liveProbe`.
- **Display (brightness)** — `design/display/` (README first). DDC/CI brightness for the monitor: the `brightness` glyph (U+E031, `Glyphs.brightness`, a sun) sits immediately LEFT of the volume glyph — bar order Wi-Fi · Bluetooth · brightness · volume · bell · theme · power in the bar; it opens `panels/DisplayPanel.qml`; the brightness keys show an OSD in the volume OSD's place. Add `ddcutil` to the NixOS packages (applies after the rebuild). One `Brightness` service owns the bus: detect the bus once (`ddcutil detect`), read with `getvcp 10 --brief` (and `12`), write with `setvcp 10 <n> --bus <n>`, one process at a time, latest target wins, read back after every write. Slider sends on release; keys and scroll merge within `ddcSettle` (300 ms). Replace the `brightnessctl` binds in `bind.conf` with IPC calls into the shell. Add `brightnessStep`, `brightnessPresets`, `brightnessFloor`, `ddcSettle`, `ddcTimeout`, `osdHold`, `pendingTick`, `osdWidth`, `osdHeight`, `durSlow` to `Theme.qml`. The dashboard (another session) must use this same service if it shows brightness.
- **Tray row** — `design/tray-row/` (README first). Only the tray chevron, the Claude tray item and keep-awake. Order: `[drawer ←] chevron · Claude · keep-awake | Wi-Fi …`; Claude and keep-awake sit right of the chevron and never move. Chevron = `Glyphs.chevronLeft` / `chevronRight` at 16px. Keep-awake = a shell module on Quickshell's idle inhibitor using `Glyphs.stayAwake` (U+E032, open eye) / `Glyphs.stayAwakeOff` (U+E033, closed eye); quit any keep-awake tray app. Claude = the app's own tray icon tinted to `Theme.text` (MultiEffect colorization or ColorOverlay) at 16px on whole pixels; never redraw or replace the logo. Copy the new `design/glyphs/SwissGlyphs.ttf` and `Glyphs.qml` (52 glyphs) into the shell. Check the generated property names in `Glyphs.qml` before using them.
- **Launcher** — `design/launcher/` (README first). Replaces the current launcher. Opens flush under the bar rule, left-aligned with the NixOS mark, 576 wide. Filter for real: rank name-prefix › word-start › initials › substring › generic name/keywords; one typed letter matches only name and word starts. First row always selected; Enter opens it. Icons = the app's own, tinted to `Theme.text` at 16px; matched letters underlined 2px ink; generic name in textMuted; row numbers only while Alt is held. Query on a ruler whose fill = matches ÷ apps. Empty query shows 6 recent apps. Write a small unit test for the ranking (e.g. "f" → Files, Yazi File Manager, Advanced Network Configuration; "fm" → Yazi File Manager) before wiring the UI.
- **Status panels** — `design/panels/` (README first, then Popup, then Parts). Every popup shell (`SPopup`) and the control-centre `Tile` live here too. Network (wired, Tailscale, Wi-Fi), Bluetooth, sound, notifications, date and time, and the power menu, each opening from its place in the bar (date and time from the clock) (the `power` glyph sits at the bar's far right). These replace the plain popups listed in §5 for audio, network, Bluetooth and the notification history. Add `fieldH`, `miniMeter`, `listMax`, `powerWidth`, `notifWidth`, `scanTimeout`, `powerCountdown`, `connectTimeout`, `volumeStep`, `volumeMax`, `notifBodyLines`, `notifGroupMax` to `Theme.qml`. Power: lock and suspend act at once; log out, reboot and shut down run only after the visible 5 s countdown, cancellable with Esc. Never log Wi-Fi passwords.
- **System dashboard** — `design/dashboard/` (README first, then Overlay). A full-screen overlay toggled by `qs ipc call dash toggle` (propose a keybind; ask first). Adds chart colours (`series1`…`series4`, `seq1`…`seq7`, washes), chart sizes, refresh rates and `threshold` / `control` defaults to `Theme.qml`. Sample only while visible. Its **Controls** row: Tailscale brought up with `--accept-dns=false` (Tailscale DNS stays off unless the option is turned on), night light via `wlsunset`/`gammastep` only if mango supports wlr gamma-control (check and report), caffeine = the same idle inhibitor as the bar's stay-awake, do not disturb = the notification server's flag. Ask before running `tailscale set --operator=$USER`.
- Build order after Phase 4: status panels, then the Now Playing panel, then the dashboard (its own phase with its own gate: screenshots of the overlay in both themes, sampling stops when hidden, each control's state read back after toggling).

## 6. Phases and gates

**Phase 1 — Discovery (no file changes).** Report: flake structure and hosts, home-manager mode, mango install and config paths, Quickshell + Qt versions, available `Quickshell.*` modules (incl. idle inhibit, networking, bluetooth), `mmsg` interface and tag count, monitors and scales, running bar / notification daemons, fonts present, NVIDIA driver. Propose the exact Nix changes and autostart line.
*Gate:* I approve the plan.

**Phase 2 — Foundation.** Nix packages, fonts, glyph font, symlink; `Theme.qml` (generated from `design/swiss/tokens.json` — write a tiny script if that is less error-prone than typing, and keep it in the repo), `palette.json`, `Glyphs.qml`, `State.qml`; primitives; a bar with only the NixOS mark, the ruled clock and the module ticks.
*Gate:* `nixos-rebuild build` (or HM build) succeeds; `qs -c swiss` starts with **zero** QML warnings; token grep clean; `fc-list` shows Geist, Geist Mono, Swiss Glyphs and Noto Sans Tamil; `qs ipc call theme toggle` switches both themes; screenshots of the bar in both themes beside `design/swiss/components/Bar/preview.html`.

**Phase 3 — Bar complete.** Tags (live, per monitor, all actions), title, media, status glyphs, stay awake, tray, clock + calendar, audio / network / bluetooth popups.
*Gate:* tag switches reflect in < 100 ms; kill `mmsg` and show recovery; no zombie `mmsg` (`pgrep -a mmsg`); monitor hot-plug tested or stated untested; screenshots of every popup in both themes.

**Phase 4 — Overlays.** Notifications (after the daemon check), OSD, control centre.
*Gate:* `notify-send` low / normal / critical, long body, actions, image; DND suppresses toasts; screenshots in both themes.

**Phase 5 — Audit.** Every item below true, `README.md` written, final commit.

---

## 7. Acceptance checklist

- [ ] Token grep clean; `Theme.qml` matches `design/swiss/tokens.json` value-for-value (diff them with a script and paste the result).
- [ ] Every text / ground pair in the README's contrast table holds in **both** themes; in light, `ok` / `warn` are never text on `surfaceAlt`.
- [ ] `accent` marks at most one thing per view. Circles (on / selected) and triangles (attention) are ink in both themes; nothing relies on colour alone.
- [ ] Both themes screenshot-checked for every bar module, popup, toast and OSD; theme choice survives restart and reboot.
- [ ] Radius only 0, or a true circle for the on-mark; no shadows, blur, gradients.
- [ ] One baseline across the bar; tabular figures everywhere numbers change (clock and volume never shift width).
- [ ] Glyphs at 16 px on whole pixels, via `Glyphs.qml` only; startup font check present.
- [ ] No battery / backlight / power-profile code.
- [ ] No rendering artefacts on the GTX 1070 across tag switches, popups and OSD (report the driver version).
- [ ] mango watcher reconnects; no zombie processes after reload.
- [ ] Log free of warnings and binding loops after 10 minutes; idle CPU ≤ ~1 % (measured, number reported).
- [ ] DND and stay-awake survive `qs` restart and reboot.
- [ ] `nixos-rebuild build` passes for the desktop host only; no other host touched; every new file committed; backups listed in `README.md`; NixOS mark credited.

## 8. When unsure

Stop and ask with options and your recommendation — especially for notification daemons, keybinds, autostart, anything NVIDIA, and agent-session data sources. For a visual question the design system does not answer, pick the more restrained option, match the nearest `preview.html`, and record it under "Decisions" in `README.md`.
