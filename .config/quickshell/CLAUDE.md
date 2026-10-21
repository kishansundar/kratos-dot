# Kratos shell (Quickshell on mango): working notes for agents

## Quickshell Swiss (bar) · Panels · Now Playing · Dashboard · Display · Tray row · Launcher (design/)
- The build brief is `design/AGENT_BRIEF.md`; follow its phases and stop at each gate. The bar, popups and overlays
  exist; section 5b added the Now Playing panel (panels/NowPlayingPanel.qml, the "media" popup) and the dashboard
  (panels/DashboardPanel.qml, design/dashboard v2 "instrument sheet": a 1152 px panel centred on the screen, Super+D
  and a right click on the NixOS mark; one 40 px row per vital on four 258 px columns, then Processes, Storage and
  Controls. The owner's choices: the mark alone in the header, the cheap vitals recorded in the background
  (services/Metrics) so the sparklines are full on opening, at most four drives with "+N more"; its data:
  services/Metrics and Processes).
- Nine design systems (`design/busy-indicator/`: the busy mark, see below): `design/swiss/` (the bar),
  `design/panels/` (every popup from the bar: network + Tailscale,
  Bluetooth, sound, notifications, date and time, power, control-centre tiles; built 15 October 2026),
  `design/now-playing/` (panels/NowPlayingPanel.qml), `design/dashboard/` (panels/DashboardPanel.qml), `design/display/`
  (DDC/CI brightness: services/Brightness, panels/DisplayPanel.qml, the sun in the bar, the OSD; built 15 October
  2026), `design/tray-row/` (the chevron, Claude and keep-awake: bar/TrayDrawer, bar/Status; built 15
  October 2026; keep-awake is the cup, not its eyes),
  `design/launcher/` (panels/Launcher.qml, hung under the NixOS mark; its ranking is services/AppMatch.js, checked by
  tests/AppMatchTest.qml: run `sh tests/run.sh` after touching it; built 15 October 2026), `design/dock/` (overlays/Dock.qml,
  one per screen, built 15 October 2026 evening; see the dock notes below). Read the relevant README,
  then `design/<system>/components/<Name>/README.md`, before any UI work.
- Panels: Theme.panel holds design/panels' tokens, Theme.display design/display's. Shared parts: components/Field,
  ErrorLine, MiniMeter, PanelFooter, RowItem (busy, right / middle click; every menu's row, the dock's too), Switch
  ("on" / "off"), MenuRule (every menu's separator), TipBox (every tooltip's box), SliderRule (both sliders' ruler),
  NotifExtras (a notification's progress and actions, toast and centre), HoverFill (every control's press / hover
  fill and its fade) and FocusRing (every control's keyboard outline), Segment (a choice of a few words: the dashboard's
  holds, the picker's sort and shape); services/Format.js (ISO week, m:ss, clock, spans, percent figures, file sizes);
  Mango.readClients (the one reader of `mmsg get all-clients`). Theme.cacheDir is the shell's cache folder
  ($XDG_CACHE_HOME/swiss-desktop) and Theme.dryRun the rig's SWISS_DRY_RUN=1: Net, Bt, Trash, the power menu and
  process terminate only log "DRYRUN ..." under it. Every change to
  NetworkManager and BlueZ goes through services/Net and services/Bt, and every DDC write through services/Brightness
  (the one writer to the I²C bus; ddcutil comes from ~/nixos). Departures, with reasons in each file's header: no
  Suspend in the power menu (Kratos never sleeps), no "date & time settings" (none installed; the zone is set in
  NixOS), settings links ("network settings", "sound settings") only while their apps are installed.
- Switching popovers (overlays/PanelHost, 19 October 2026, from the Caelestia review): with one open, another asked
  for keeps the card on screen: its content fades out (motion.fast), the new panel loads, the card moves and resizes
  to it over motion.spatial (200 ms OutCubic, not a token) while the new content fades in (motion.med), cut at the
  card's border meanwhile. A switch mid-switch starts from where the card is; Esc or a click outside closes it where
  it is. The dashboard and the clipboard (not hung from the bar) still open afresh. SWISS_MOTION_SCALE=N stretches
  motion fast / med / slow / drawer / spatial (5 gives clear stills in a rig). Check a switch by its end state: a
  grim of the switched-to card is pixel-identical to a fresh open (the pointer and live text aside).
- Dock (design/dock, the owner's nixos-mark-and-dock package): overlays/Dock.qml, one per screen (shell.qml Variants),
  hidden every time, on an empty tag too (the owner's ask, 19 October 2026: no more showing by itself on an empty tag,
  over the package; Theme.dock.showDelay is gone); a window mapping on an empty tag (Mango.monitors client_count, from
  the existing `mmsg watch` stream) puts it away at once, and `qs ipc call dock focus` reveals it for the keyboard.
  The bottom edge under the dock brings it up (the owner's choice, 15 October 2026, over the package's
  "no hover-to-reveal"), slide up 180 ms: a 1 px strip layer, always mapped, 150 ms of pressure; it goes 150 ms after the pointer
  leaves, at once after a click on an app. mango gives a surface that maps under a still pointer no enter until the
  pointer moves, so the strip's own hover counts as "on the dock" and the input mask is the dock's resting
  rectangle, not the sliding body. A delegate that changes Prefs.dockPinned is destroyed mid-handler: reset state first.
  Geometry, the owner's pick C of three rendered (15 October 2026): the dock stands the window gap (Theme.bar.padX)
  above the bottom edge with a 1 px line all round, its bottom edge on the windows' bottom border (y 1431 at 1440 px);
  icons centred in the 80 px cell (16 / 16), the running mark s1 under the icon. The 8 px under it is the full-screen
  layer's input while shown (item `gap`), so the pointer crossing it from the edge strip still counts as on the dock.
  No NixOS cell (the owner found it redundant beside the bar's mark, 15 October 2026); the dock ends in a trash, the
  owner's ask ("like the macOS dock"): the Swiss app icons' user-trash (outline) / user-trash-full (solid) at 48 px
  in ink, like the apps beside it (the owner's pick, 16 October 2026 ~13:30, from a rendered A/B; at 12:08 they had
  chosen the icon theme's own full-colour bin over an ink bin drawn in QML). Where the set has no bin, the icon
  theme's own (the theme swiss-mode gives GTK for the mode, the icon_theme token, Papirus-Dark / -Light, via
  scripts/icon-lookup.sh, since the shell sets no icon theme). It watches ~/.local/share/Trash/files with
  FolderListModel; click opens
  `nautilus trash:///`, right click Empty Trash… asks once, then deletes files/, info/, expunged/ and directorysizes
  (no gio here): all of that is services/Trash (one for the shell; each screen's dock reads it). Files dropped on it
  go in through trash-put (trash-cli, from ~/nixos modules/dev.nix), the drop
  taken as a copy so the sender never deletes anything itself; a drag held at the bottom edge brings the dock up and
  keeps it while on the strip, the gap or the dock, which refuse the drop ("no drop" cursor). SWISS_TRASH_DIR points
  a test shell at a stand-in (trash-put --trash-dir); under SWISS_DRY_RUN without it, emptying and drops only log
  DRYRUN. The dock's width is counted (dockWidth), not read from its Row. Test drops in a rig with a real Nautilus on
  the rig's display and bus: GSETTINGS_BACKEND=memory and XDG_*_HOME in the rig (~/.cache/swiss-desktop-work/trash
  naut.sh, drag2.sh).
  Running apps come from Mango.clients (`mmsg get all-clients`, read only while a dock is shown) joined to desktop
  entries with DesktopEntries.heuristicLookup(appid); pinned apps are Prefs.dockPinned (desktop ids; drag to reorder,
  drag up to unpin, right click Pin / Unpin). Theme.dock holds its tokens. Three top layers per screen: the dock
  itself ("swiss-dock-body", dock-sized, on the bar's ground: bg at Theme.bar.opacity, the owner's choice, and not
  blurred: mango's optimized blur shows the blurred wallpaper, never the window under the dock, and the wallpaper there
  is the ground's own colour, so it read as solid beside the bar; mango rule.conf `no_blur` for ^swiss-dock-body$, the
  owner's choice on 16 October 2026; it slides up by growing its height from the edge, since mango does not move a mapped layer whose margin
  changes), a full-screen transparent one for the name label and the menu ("swiss-dock": input only while the menu is
  open, then everywhere but the dock, so a click outside closes it), and the 1 px edge strip ("swiss-dock" too). mango
  needs `layer_rule=no_blur:1,layer_name:^swiss-dock$` (rule.conf has it, anchored; the body has its own rule), or it
  blurs the whole wallpaper. Keyboard:
  `qs ipc call dock focus` (Panels.dockFocusRequested); the menu and keyboard mode take the keyboard exclusively, since
  mango grants on-demand focus only from a click (too late for the menu's Esc). Focus a window with
  Mango.focusClient(id) (`mmsg dispatch focusid client,<id>`), close it with Mango.closeClient(id).
  Qt's JavaScript engine has no Array.flatMap (a binding that used it kept its old value, with a TypeError in the log).
- Busy mark (design/busy-indicator, the owner's package, 16 October 2026): a 16 px mark after the app id in the bar's
  title. kitty: working (a command past 0.8 s, or Claude's turn), needs you (Claude asks), done (3 s once seen), failed
  (8 s once seen); any app starting from the launcher, the dock (Busy.start(entry)) or a keybind
  (scripts/busy-launch <app id> <command>, called by path from ~/.config/mango/bind.conf) shows its id, the scanner and
  its name until a matching window opens or takes the focus (15 s at most, then quietly). All three start it through
  scripts/launch (the owner's ask, 20 October 2026, after Helium quit silently on a stale profile lock): its output
  goes to the journal under the launch's id (`journalctl -t helium`; before, the launcher's and the dock's went to
  /dev/null), and an app that quits with an error within 5 s gets a notification from its name ("Helium did not
  start", its first error line, the exit code) and its starting mark ends (`qs ipc call busy launchFailed <id>`).
  Rig: stand-in apps and entries in ~/.cache/swiss-desktop-work/launchg/apps on the rig shell's XDG_DATA_DIRS. services/Busy (the package's
  BusyStore), components/BusyMark, Theme.busy; `qs ipc call busy get` / `dump`. Feeds: ~/.config/kitty/busy_watcher.py
  (a link to scripts/busy_watcher.py; `watcher busy_watcher.py` in kitty.conf, so only kittys started since report) and
  Claude Code hooks in ~/.claude/settings.json (scripts/busy-hooks.json is the block that was merged, identical to
  it on 20 October 2026; delete that block from settings.json to undo). The owner's choices: no slot while idle (the title moves aside for the mark); an app's
  name ending its title is trimmed (bar trimTitle); every mark centred on the title's text (row 20, from the font's
  "H" and "x" ink), picked from a rendered A/B over the bar's icon line (row 16). Departures from the package, each found in the rig: windows keyed
  "$KITTY_PID:$KITTY_WINDOW_ID" (every kitty from Super+Return is its own process, all numbering windows from 1), and
  the kitty in front taken from mango's window pid (so kittys without the watcher, opened before it, still get Claude's
  marks); the watcher calls qs through one helper shell (a Python thread in a kitty watcher runs only when kitty's loop
  wakes: a command's end came with the next key press); it reports the focus on every command in the focused window
  (kitty misses a new OS window's first focus: use fast_data_types.current_focused_os_window_id); a PermissionRequest
  hook (Notification permission_prompt waits about 6 s); a window id is matched as the bar shows it (".piper-wrapped").
  Claude Code's Stop does not fire on Esc: the scanner then waits for idle_prompt (about 60 s) or the next prompt.
  Test in a rig with kitty-old.sh / kitty.sh (with and without the watcher), hooks/*.sh typed into the rig kitty, and
  apps/applications/*.desktop on the rig shell's XDG_DATA_DIRS (~/.cache/swiss-desktop-work/trash).
- App icons (design/app-icons, the owner's package, 16 October 2026): 26 one-colour pictograms (24 apps, the trash
  empty and full) in assets/app-icons, laid out as an icon theme (scalable/ = 48 px masters, 16x16/ = 16 px drawings;
  apps/, places/, status/), one file per icon name, the name the app's desktop entry gives. services/AppIcons lists the
  folder and components/AppIcon paints a drawing in `color` (Theme.colors.text) through its alpha (MultiEffect mask,
  min 0.5, spread 1: measured, the ink is the text colour exactly and the edges keep their anti-aliasing); 16 px and
  under the 16 px drawing, above it the master. Used by the launcher rows (16), the tray (16) and the dock (48, and its
  trash); where the set has no drawing, each site shows the app's own icon as before. Departures from the package: no
  `//@ pragma IconTheme Swiss` (AppIcon loads the files by path, so the shell still sets no icon theme and nothing else
  changes, notifications included); the launcher's selected row keeps ink (its fill is pale, not the dark band the
  package assumed); the launcher is 16 px, not 24. Tray items that send pixels are matched by id or title
  (AppIcons.trayIds: 1Password's id 1Password_status_icon_1, RustDesk's title "rustdesk", since its id carries a
  process number; Steam by id or title, unverified until it is installed). Add, replace (in place or by rename) or
  delete a file and the shell follows at once, no restart (tested in a rig, 16 October 2026); a deleted drawing gives
  that app its own icon back. Dock tiles (the owner's pick of three rendered, 16 October 2026 afternoon): each cell's
  icon on a 48 px tile in surfaceAlt (Theme.dock.icon), the icon at Theme.dock.pictogram 36 px (the masters at 3/4),
  hover = the tile in the line colour (no cell fill); measured, every pictogram sits with 9 px margins on its tile. The
  set's Spotify note was redrawn at the full 40 px live area (its 34 px read small beside the rest).
- Wallpaper picker (overlays/WallpaperPicker, Super+W), after skwd-wall's pickers (the owner's ask, 20 October 2026:
  "skwd-wall but adapt to our design", every picture its own card, no grouping by name): M switches "slices"
  (parallelograms leaning 25 px over 360, slices 90 wide and 8 px apart along the slant, the marked one 640, fading
  towards the screen's edges: skwd-wall's small Slices preset; ListView spacing gap - skew) and "wall" (8 x up to 3
  16:9 tiles, fewer rows when a filter leaves fewer); Prefs.wallLayout. Both keep the picker's grey-until-marked cards
  on a line with the red index. A filter row of words: sort colour (default, as skwd-wall) / date / name / size,
  colour swatches with counts (only the colours present), shape all / wide / tall, favourites only (F marks,
  Prefs.wallFavourites, a filled circle on the card), random (R marks one). Shift+Left/Right colours, Alt+Left/Right
  sorts. Colour and size come from services/PictureFacts.js (tests/PictureFactsTest.qml): twelve hues 30 degrees apart
  or neutral (chroma under 0.12), whichever covers most of a 64 px copy, read one picture at a time while the picker
  is open, nearest the marked card first: the original decoded once at 640 px -> grab -> its thumb (the only copy the
  cards show; a card is blank until then) -> the thumb at sourceSize 64 -> grab -> file -> Canvas, and the size from
  the file's first bytes (od). One cache, picture-facts.json beside the thumbs: per thumb name the path, the facts
  (or failed: "can't be read") and the bar strips by screen width (the old second file, bar-strips.json, was folded in
  on 20 October); a strip is kept under the picture it was grabbed from (the key travels with the grab); on opening, entries whose file is gone or changed and thumbs with no entry are removed (only
  md5-seconds.jpg names), a thumb gone missing is made again, and a reading stuck past 10 s is let go, so a picture
  added later sorts and filters by itself and nothing stalls the queue. A folder that does not exist says "No such
  folder" (Backspace goes up its path). 20 October: 34 decodes instead of 78 on a first open of the 32 posters. The posters read as
  neutral (black / grey / cream) and red (orange). The caption warns "smaller than the screen" beside the bar
  contrast check. Each card's parallelogram is a Shape: the ground (also the MouseArea's containmentMask, so leaning
  neighbours never take each other's clicks), the picture's MultiEffect mask (min 0.5, spread 1) and the frame.
  Inline components do not see the file's ids: Face gets the view as `picker`. A folder opened mid-reading takes
  over the queue. Rig: ~/.cache/swiss-desktop-work/skwdpick (qs-home.sh runs the shell with HOME=$W/home, whose
  Pictures/Wallpapers holds a link to the posters and generated samples; desktop/bin/swiss-wallpaper is a stand-in).
- The polkit prompt (overlays/Polkit, the session's agent) is a panel card: components/AuthPrompt (eyebrow "as <user>",
  the app's message, Field, ErrorLine, authenticate / cancel, the action in PanelFooter), centred on mango's active
  monitor over a dimmed screen. It follows PAM: the field only while isResponseRequired ("checking…" otherwise), the
  password cleared as it is sent. The rig cannot receive real requests (the live agent holds the session); test the
  live one with `busctl call --allow-interactive-authorization=yes org.freedesktop.login1 /org/freedesktop/login1
  org.freedesktop.login1.Manager SetWallMessage sb "" false` (harmless; killing busctl cancels the request).
- Screenshots (scripts/screenshot.sh region | window | screen, 19 October 2026, after Caelestia's area picker; mango's
  binds call it by path): each shot goes to the clipboard, ~/Pictures/Screenshots/<date time>.png and a notification
  (summary "Screenshot", body "W × H · copied · in <folder>", the file as image-path: the toast is text only, the
  notifications panel shows the picture). region is slurp fed the content box of every window visible on the focused
  monitor (mmsg all-clients x / y / width / height include border_px, read from mango's config.conf; none for a
  fullscreen window) and the monitor itself last, so a click takes a window or, on the bare desktop, the screen; Esc
  cancels quietly. Look: the mode's ground at 45 % as the veil, the box under the pointer clear with a 1 px rule in the
  one red and slurp's size label in Geist Mono. slurp fills given boxes with -B INSTEAD of -b, so -B must be the veil
  too (a transparent -B left every window unveiled; an ink tint plus the screen box greyed everything). No notify-send
  or gdbus here: busctl --user, with `--` before `call` (it reads the expiry -1 as an option otherwise); it follows
  DBUS_SESSION_BUS_ADDRESS, so a rig's shots notify the rig's shell. grim -T (one window's own pixels) failed in the
  pixman rig ("Invalid stride"); window shots crop the screen at the window's box, so anything over it shows.
  Rig: ~/.cache/swiss-desktop-work/shot (shoot.sh runs the script with SWISS_SHOT_DIR / SWISS_DESKTOP_DIR /
  XDG_STATE_HOME / SWISS_MANGO_CONF; demo.sh MODE drives a region shot with vin and opens the panel).
- Values only from the systems' `tokens.json` files (Now Playing and the dashboard are Swiss's tokens plus their own),
  mirrored in one `Theme.qml`; never introduce a value not in them. Colours reach the shell through
  ~/.config/swiss-desktop (tokens/*.env -> swiss-build -> build/<mode>/palette.json), which also colours mango, kitty,
  GTK and the lock screen.
- Dashboard Controls, checked 15 October 2026: mango exposes `zwlr_gamma_control_manager_v1` (v1), so night light is
  supported (services/NightLight.qml already runs wlsunset). Tailscale: the owner granted kishan the operator role in
  ~/nixos/configuration.nix (`services.tailscale.extraSetFlags = [ "--accept-dns=false" "--operator=kishan" ]`,
  re-applied at boot; no --ssh, by the owner's choice), so `tailscale up/down/set` need no sudo once that is switched
  to. Ask before binding a key to the overlay.
- Icons: Swiss Glyphs only, via `Glyphs.qml` and `components/Icon` at 16 px on whole pixels; the font is loaded from
  `assets/fonts/SwissGlyphs.ttf` by Theme's FontLoader (no install needed). No Material Symbols, Nerd Fonts, emoji.
  Nothing the running shell loads lives in design/ (the packages are references). `design/glyphs/defs.py` is the glyph
  source (append-only codepoints); after a change run `python3 design/glyphs/build.py design/glyphs` (needs shapely +
  fonttools + brotli: `nix-shell -p "python3.withPackages (p: [p.shapely p.fonttools p.brotli])"`): it writes
  assets/fonts/SwissGlyphs.ttf and the root Glyphs.qml in place, and the references (svg/, glyphs.json, the woff2)
  into design/glyphs. Then restart the shell fully. Credit the NixOS snowflake (NixOS/nixos-artwork, CC-BY 4.0).
  Glyphs added here: v1.2 power, square, square-off, bell-unread; v1.3 tick; v1.4 chevron-left-small, -right-small;
  v1.5 night (from the package). The package numbers night U+E02F, which is power here: in the shell night is U+E036
  (`Glyphs.night`). v1.6 brightness (the display package's sun, its U+E031 is square-off here: U+E037); power took
  the panels package's drawing (a wedge gap) at its own codepoint. v1.7 stay-awake, stay-awake-off (the tray-row
  package's eyes; its U+E032 / U+E033 are bell-unread and tick here: U+E038 / U+E039; no longer used). v1.8 sleep,
  sleep-off ("Zz" and struck "Zz": keep awake, U+E03A / U+E03B). v2.0 (local) the balance pass: every status glyph
  inside a 14 px live area (1..15), centred, 2 px strokes: Bluetooth, sun, Wi-Fi (fan opened 33 degrees), speaker,
  bell, power and chevrons redrawn; awake-dot / awake-dot-off added (U+E03C / U+E03D). Claude's SVG mark is drawn
  14 px too (components/Icon). New glyphs keep to that live area. v2.1 (local, 15 October 2026 evening): bell,
  bell-unread and bell-off redrawn as a solid bell with a round dome, loop, 11 px rim and clapper (the owner's pick
  from rendered options; the old one read as a pawn). v2.3 (local, 15 October 2026 night): volume-1 / volume-2
  waves as two 2 px arcs of one fan opened 33 degrees like the Wi-Fi fan (the owner's pick C of three rendered in the
  bar; the straight bars made the low-volume speaker read as a media button). Cone, volume-0 and muted unchanged. Swiss Glyphs 1.6 (swiss-glyphs-1.6.zip, 15 October
  2026): its redrawings (Wi-Fi fan, round search lens, half-filled circle for theme, slimmer bell, solid sun, Bluetooth
  inside its box, taller chevrons, bigger pupil) are its defs.py block appended verbatim at the end of defs.py, so they
  land on the shell's codepoints; bell-unread follows the slimmer bell. Never swap in a package's SwissGlyphs.ttf or
  Glyphs.qml: packages number 52 glyphs U+E000-E033 and this font's numbers differ (U+E02F is power here, the moon
  there; brightness is U+E037 here, absent there). The previews' fonts (`design/*/fonts/`) are the package's own and keep its numbering.
- Where `design/AGENT_BRIEF.md` disagrees with `design/swiss/README.md` on fonts, icons or icon sizes, the README wins.
- `design/*/components/*/preview.html` show the intended look; they are references, not code to port.
- Marks, in ink: filled circle = on / selected, ring = off, triangle = attention (always with a word); the red square
  fill is the one active thing.

## The owner's choices that override the package (15 October 2026)
- Keep the Measure 24-hour day ruler on the bar's lower edge (bar/DayRuler) and the screen-centred clock with its red
  "now" stroke (the package wants module ticks and the clock at the right edge). The ruler's day-so-far is the 1 px
  hairline in red ending in a red now tick (marker wide, 8 px), the owner's pick from rendered options on 15 October
  2026 evening (the tick-colour line was too faint; a 3 px ink fill was too heavy and hid Now Playing's 2 px ink track
  progress, which now lies over the red line and stays visible).
- Keep-awake: the shell's own on/off mark (awake-dot / awake-dot-off: a filled 10 px circle while kept awake, a ring
  while the screen may sleep), in the bar between the chevron and Claude: the owner's pick on 15 October 2026 ("the
  cup doesn't match the Swiss design"), after a square box, a tick that read as a comma, the eyes, a "Zz" and the cup.
  Super+Alt+C and the dashboard's Caffeine switch also toggle it. The tray drawer's chevron is the 16 px chevron-left / -right (the small
  6 px one did not match its neighbours). Both by the tray-row package the owner asked for, 15 October 2026.
  Claude Code keeps Claude's own mark in the bar, filled with ink at 16 px; it is the shell's Claude Code module (a
  click opens the claude panel), not the Claude desktop app's tray item the package assumes (not installed here), and
  stays amber near a plan limit. The row runs straight into Wi-Fi with no gap (the owner's choice; the package wants rowGap).
  App icons in the tray, the launcher and the dock: the owner's Swiss app icons (design/app-icons, 16 October 2026) in
  ink; any app outside the set keeps its own icon and colours, except the tray apps in AppIcons.trayInk, whose own
  picture is one colour made for one kind of panel and is drawn in ink through its alpha (CoolerControl: its white
  sliders vanished on the Light bar, 19 October 2026). Known by id or title, not by reading pixels (see Canvas below). (On 15 October the owner had kept every app's own
  colours over the tray-row and launcher packages' ink tint; their own icon set replaced that.)
  The bar's NixOS mark is the Swiss two-tone mark (components/NixMark, 24 px, five ink
  arms and one red arm, from the owner's nixos-two-tone-bar package, 15 October 2026 evening): glyphs nixos-rest and
  nixos-accent (v2.2, ported as data into defs.py from nixos-two-tone.json, not by swapping the package's font, whose
  numbering differs), drawn unhinted; the dashboard masthead uses it too (32 px), and the lock screen's logo is generated
  from the same nixos-two-tone.json (swiss-desktop templates/mode/logo.svg).
  A rebuilt SwissGlyphs.ttf needs a full shell restart BEFORE any other QML edit: a hot reload after the font file
  changed drew every glyph as the wrong character (15 October 2026).
- One red, the wallpaper posters' own #E93F20 (the owner's choice, 16 October 2026, after a review found the shell's
  crimson beside the posters' orange-red): swiss-desktop's accent_fill in both modes, for every mark and fill. Red text
  (accent / error) is the same hue, #C02E13 in light and #EC5A40 in dark, for 4.5:1; text on a red fill is ink in both
  modes (white on this red is 4.0:1). The packages' tokens.json reds (#C4261A / #FF4136) are superseded.
- A little translucency (bar 85 %, unfocused windows 82 %, kitty 0.80; a step more see-through on the owner's request,
  15 October evening, from 75 / 88 / 0.85; the bar back up from 68 % on 20 October, so a poster's red no longer reads
  as a second red behind the status icons) despite the package's "no glass". The dock has the bar's ground too (the
  owner asked, 15 October evening; design/dock wants a solid surface).
- Wi-Fi and Bluetooth passwords and pairing happen in the shell (no terminal hand-off). Power-menu letters are drawn
  as keys. A pairing request takes no answer in its first Theme.panel.answerDelay (1 s, the owner's choice, 20 October
  2026; BtAgent.armed): every key does nothing, the field and buttons are off, since the request takes the keyboard
  while the owner may be typing elsewhere. Rig: the bluetoothctl stand-in prints a request written to logs/bt-request.
- Launcher (design/launcher, 15 October 2026): an empty query shows the recent apps, as the owner's launcher package
  asks (before it, the launcher listed nothing until something was typed). App icons: the Swiss app icons in ink (see
  App icons), other apps their own. Super+Space or a click on the NixOS mark opens it (the owner's
  choice, as the package asks); a right click on the mark opens the dashboard (also Super+D).
- Launcher calculator (19 October 2026, from the Caelestia research the owner asked to "do all"; not in design/launcher):
  a query starting with "=" goes to qalc (libqalculate, ~/nixos modules/desktop.nix) calcSettle after typing pauses,
  one qalc at a time; the answer is one selected row ("=" in the icon slot, the value in mono ink, grouped as qalc
  groups it), Enter or a click copies it plain (wl-copy; no grouping spaces, "-" for qalc's "−"). qalc -t hides its
  messages and exits 1 after an error but still prints a value, so a second plain run supplies "error:" / "warning:"
  lines (~45 ms each): an error replaces the row (textMuted), a warning stands under it in textFaint ("Division by
  zero.", the exchange rates' age). Settings per run: -m calcLimit, upxrates 0 (never fetches: strace showed no socket
  at all), autoconversion 0 (single units: "12 km to miles" was "7 mi + 803 yd + 1 ft + 0.94 in"), digit grouping 1
  (U+202F). qalc writes qalc.cfg on every run: its XDG_CONFIG_HOME / XDG_STATE_HOME are the shell cache's
  swiss-desktop/qalc, the data dir stays the owner's (so `qalc -e` rates count). A trailing " in <unit>" becomes
  " to <unit>" (qalc alone reads "in" as inches). Terminal apps start in their entry's Path= (kitty --directory).
  Rig: ~/.cache/swiss-desktop-work/calc (env.sh puts calcbin/qalc on PATH; CALC_PATH= qs.sh tests "needs qalc").
- The bar keeps the bell, the light / dark glyph and power (not in the package's bar).
- The focused tag's layout beside its numeral (bar/LayoutMark, the owner's ask, 20 October 2026; their pick A of four
  rendered): a 17 x 13 plan of the panes in 1 px rules, textMuted, from mango's layout_symbol (Mango.layoutName reads
  `mmsg get layouts` once); click = switch_layout (Super+N). Not under the numeral: the 8 px there are the day ruler's.
- The brightness OSD shows a step at once, red fill and ink value like the volume's (the owner found the package's
  grey "until read back" state weird, 15 October 2026); only a failed write says so ("· no answer", the value goes
  back). The first key press or wheel notch of a burst is written at once, the rest merge within settle into one more
  write. A wheel notch on a bar slot hides its tooltip until the pointer leaves, as a press does. The Display panel
  keeps its "setting…" state.

## QML / Quickshell gotchas found here
- `sh tests/lint.sh [--all] [files]` runs qmllint (Quickshell's own qtdeclarative) with Quickshell's types and the
  qs.* modules resolved: it starts Quickshell off screen on an empty ShellRoot in a scratch copy only to get the
  .qmlls.ini Quickshell writes (no services, no bus), ~2 s. By default it reports only what proved real (a member
  shadowing its base type's: a function `move` on a Column hid the positioner's move transition in CalendarGrid,
  SearchList and NetworkPanel, renamed moveDays / moveBy); `--all` shows qmllint's noise (Theme's QtObject groups,
  outer ids in delegates, singletons' members, Quickshell types its qmltypes leave out). Its filter was re-checked on
  qmllint 6.12.0 (20 October 2026: it now also reports ids that shadow a property, and checks that every popover
  PanelHost loads by name has its file). Run it beside tests/run.sh after an edit.
- Prefs (shell.json) is watched and never written over when it does not parse; unknown keys and wrong-typed values
  are written back as found (see its header). busctl needs `--` before `call` when an argument is negative (-1).
- Notifs.fullscreen (ToplevelManager.activeToplevel.fullscreen, from mango's wlr-foreign-toplevel): no pop-ups while
  the focused window is fullscreen (critical ones still show); Notifs.progress(n) reads the "value" hint.
- Media keys: `qs ipc call bar playPause / next / previous` act on Media.player (the bar's), not playerctl's pick.
- A row's MouseArea must lie under its content, or it takes every press from the controls inside (RowItem).
- A card is as wide as its panel's `width`, not its implicit width (PanelHost).
- A PopupWindow that grows while shown keeps drawing at its first size; a grab popup closed with Esc leaves mango's
  keyboard focus nowhere: tray menus go through PanelHost ("traymenu") instead.
- A panel PanelHost loads must set `focus: true` on its root (a FocusScope too), or no key reaches it but Esc.
- A property named on<Capital> reads as a signal handler: Theme.colors.onAccent came out #000000. The token onAccent is
  Theme.colors.textOnAccent; never name a property onSomething.
- Now Playing v2 is built against recorded player output (design/now-playing/recorded): Zen / Firefox on YouTube send no
  mpris:length and a Position stuck at 0 (untimed, never "live"); Quickshell's own `position` counts on by the clock
  while playing, so "live" is decided from the player's D-Bus Position read twice, liveProbe apart. Measured
  2026-10-15 (throwaway Zen 1.23.2b in a rig): Zen does report YouTube's time, guessed from the <video>, but often
  loses it (on load or after an in-page move to the next video: a race). ~/nixos/modules/apps/youtube-mpris.user.js
  (Violentmonkey) calls setPositionState from the element and kept it right in every run. Untimed is a plain rule.
- mpv's MPRIS plugin always says CanSeek and gives a stream a length that grows: a "live" state cannot be produced
  with mpv (browsers and radio players report no length).
- QML singletons are created on first use: a service that must act at start (NightLight restoring a saved night light)
  is touched in shell.qml. wlsunset outlives a killed shell (it never writes, so no broken pipe); NightLight starts it
  through a pid file per display and stops a leftover first. nvidia-smi -lms dies with the shell (broken pipe).
- Item already has top, right, left, bottom, scale, state, clip: a property or id with one of those names breaks
  the file ("Cannot override FINAL property") or shadows the item's own.
- New QML files register only on a full restart. Test in a rig (~/.cache/swiss-desktop-work/panels: up.sh, mksafe.sh,
  qs.sh, bin/t; mkrig.sh NAME BRANCH copies it with its own worktree). It runs the shell with SWISS_DRY_RUN=1 (Net / Bt
  log "DRYRUN" instead of changing the real Wi-Fi, this machine's only link, or the real adapter; Theme.dryRun) and stand-ins for
  tailscale, ddcutil, xdg-open, wl-copy, systemctl, loginctl and mmsg quit on its PATH (ts/, ddc/ hold their states).
  Each rig has its own bus, display and worktree (audit3 is an older one, without the stand-ins); never test by editing
  the live tree (Quickshell reloads it at once).
  Another session may be using a rig: make your own copy, and never kill quickshell by name.
  mksafe.sh's rsync replaces the files it changes, and Quickshell loses its watch on them: to hot-reload a rig, also
  append to a file rsync left alone (safe/shell.qml), or restart it with qs.sh.
- A Repeater over a JS array hands each delegate a copy of its object: a delegate that must follow later changes
  looks the live object up by index (DisplayPanel), and a service that changes objects in place counts a revision
  for bindings to read (Brightness.revision) instead of re-announcing the array (which would rebuild the delegates).
- Qt's Canvas (found tinting tray icons, since dropped): putImageData(img, x, y) draws nothing (pass the dirty rect
  too), it blends over what is there (clear first), and it takes straight alpha as getImageData gives it.
  Canvas.loadImage, and drawImage of an Image item (it loads the item's URL again itself), ask the image provider on
  Qt's reader thread: Quickshell's icon provider (QIcon's theme loader) is not thread-safe, and beside the IconImages
  loading on the GUI thread a hot reload crashed the shell (19 October 2026, a tray check that read pixels; reproduced
  2 in 37 reloads in a rig, 0 in 105 without it). Never feed tray or app icon URLs to a Canvas.
  MultiEffect's mask edge runs from (min·(s+1)-s) to min·(s+1): min 0 with any spread makes every pixel opaque. A
  plain alpha mask turns an icon drawn on a plate (RustDesk's ring on a white tile) into a blank square.
- An eliding Text whose width is bound to its own implicitWidth loops (ProcessTable's count): leave its width alone.
- Text spaced by its advance box shows the glyphs' side bearings (the clock's stroke had 7 px on one side, 8 on the
  other). Where optical spacing matters, place by ink, and measure it: TextMetrics.tightBoundingRect is itself about
  1 px off against hinted NativeRendering, so the clock uses bar/ClockInk.js, a table of real ink edges rendered and
  measured by tools/clock-ink (regenerate after a font or style change). Check spacing by measuring a grim capture
  (area-weighted edges), not by eye.
- A rebuilt assets/fonts/SwissGlyphs.ttf needs a full shell restart: a hot reload keeps the old font (verified 15
  October 2026).
- Quickshell refuses imports from outside the config's folder ("Script qrc:/qs-blackhole unavailable") and Qt.quit()
  has no receiver in it: tests/run.sh copies services/ and tests/ into a scratch root and stops each test by its pid.
- FolderListModel made with a folder that does not exist lists the process's working folder instead (its
  componentComplete), and goes Null only when the folder is set later: compare its `folder` with the one asked for.
  A blockLoading FileView's text() read in Component.onCompleted came back empty: read it in onLoaded / onLoadFailed.
- FolderListModel's fileBaseName stops at the first dot ("org" for org.gnome.Nautilus.svg): use fileName. Its folder
  watch sees files created, deleted and renamed, not a file written over in place (cp onto it: inotify IN_MODIFY is
  not on a directory watch), so services/AppIcons also watches each file (FileView watchChanges) and listens to the
  model's dataChanged (a rename over a file keeps the count).
- The shell's icon theme is hicolor, pinned by scripts/run-shell.sh with QS_ICON_THEME (Quickshell also has `//@ pragma
  IconTheme`), so app and tray icons come from hicolor: the apps' own, except the Swiss app icons, which AppIcon loads
  by path. The pin matters since the session has QT_QPA_PLATFORMTHEME=gtk3 (~/nixos/modules/theme.nix, so Qt apps the
  launcher and dock start take the GTK colours): under gtk3 without a pinned theme, Quickshell.iconPath returns ""
  for every name (measured 16 October 2026). Never unset the variable for the shell instead: its children inherit it. An icon only in a theme
  (nm-connection-editor's preferences-system-network) draws
  Quickshell's magenta checkerboard: check with Quickshell.iconPath(name, true) (the launcher shows a plain square).
  The launcher rig's vin (~/.cache/swiss-desktop-work/launcher) adds `hold MODS KEY` / `release - KEY` (Alt held).
- Quickshell 0.3.2's notification server sends ActionInvoked but never ActivationToken, so an app that raises its own
  window only with a token (kitty) stays behind on a click, and mango lets only zen and helium take the focus without
  a valid one (rule.conf activation_bypass). Notifs.goToSender brings the sender's window instead (16 October 2026, the
  owner's ask): a `busctl monitor` pairs each Notify call with the server's reply (id -> sender's bus name), and a
  click maps the name to its process, or a parent, with one mango window (`mmsg dispatch focusid`). Test it in a rig
  with kitty windows that send `printf '\e]99;;text\e\\'` while another window has the focus.
- Text with wrap, elide and maximumLineCount reports an implicitHeight one line too tall when the text wraps to exactly
  the limit: cap the height at the limit (NotifItem), not at lineCount (which follows the height).
- A Row (any positioner) lays out only while its window is shown: a size read from one in a hidden window stays at
  its first value (the dock's edge strip, sized from the dock's row, was one cell wide after a restart over windows).
- Drag and drop (Wayland, mango): a drag is not the pointer, so no hover or containsMouse reaches a surface while one
  passes; DropArea.containsDrag is the only sign. A DropArea whose onEntered refuses never sets containsDrag; a
  DropArea inside another takes the drag from it (the outer one exits). drag.accept(Qt.IgnoreAction) still accepts
  the offer's type, and the compositor then picks copy: to show "no drop" yet keep containsDrag, accept on entering and
  refuse in onPositionChanged (Qt then sends accept(nil)). WAYLAND_DEBUG=1 on the shell shows each data_device enter
  with the surface and its local position.
