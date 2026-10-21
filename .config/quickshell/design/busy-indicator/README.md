# Busy indicator · title module

A 16 px mark after the app id shows two things:
- what the focused kitty window is doing: working, needs you, done, failed;
- any app you just started that has no window yet: starting.

Nothing shows when it is idle. It uses the Swiss ruler motif: ticks, ink, and red for failure only.

Preview: `preview/busy-indicator.gif` (light and dark), `preview/qml-render.png` (BusyMark.qml rendered by Qt Quick).

## States

| State | Mark | Colour | Shown when | Leaves when |
|---|---|---|---|---|
| working | ruler scanner, 4 ticks | lit tick `text`, rest `tick` | a command has run for more than 0.8 s, or Claude is on a turn | the command ends, or Claude stops |
| needs you | 8 px triangle | `text` | Claude asks for a permission or an answer | Claude carries on, or the session goes idle |
| done | check U+E019 | `textMuted` | exit 0, or Claude finished | 3 s after you can see it |
| failed | error U+E01A | `accent` | exit code 1 or more, or Claude stopped on an API error | 8 s after you can see it, or the next state |
| idle | nothing | – | otherwise | – |
| starting (any app) | ruler scanner | as working · title shows the entry's name in `textMuted` | an app started from the launcher, the dock or a keybind has no window after 0.4 s | its window appears or takes focus; after 15 s it gives up quietly |

Rules for starting:
- While an app is starting, the title module shows it in place of the focused window: `zen ▮ Zen Browser` (the name in `textMuted`). When the window opens, `zen  New Tab` takes over in the same place. The window is the confirmation, so there is no check mark.
- Apps that open in under 0.4 s never show anything.
- A matching window opening clears it, and so does an existing window of that app taking focus (single-window apps raise instead of opening). The one exception: if that app already had focus when you launched it, its window regaining focus as the launcher closes doesn't count during the first 0.5 s.
- No window after 15 s: it clears quietly, with no error, because a slow app (Steam) or one that starts in the tray can't be told apart from one that failed.
- Starting more than one app: the newest shows; the others clear on their own.
- It outranks the kitty mark for its 0.4–15 s.

Rules for kitty:
- Commands shorter than 0.8 s never show. Ctrl-C (exit 130) and an unknown exit status leave no mark.
- "After you can see it" means kitty has focus and so does that kitty window. A build that ends while you are in the browser keeps its mark until you come back.
- Claude outranks the shell in the same window: while `claude` runs, its hooks decide the state.
- Long-lived interactive programs (nvim, htop, ssh, tmux, less, a bare `python`, `nix develop`, claude itself…) are not "working". The list is at the top of `busy_watcher.py`.

## Geometry

```
slot        16 × 16, 8 px gap either side, vertically centred on the title
            kept for kitty even when idle, so the title never shifts; other apps have no slot
scanner     ticks 2 px wide at x = 1, 5, 9, 13 · resting 4 px tall · lit 12 px tall · shared foot at y = 14
            lit tick goes 0 1 2 3 2 1 · 150 ms a step · 0.9 s a sweep
            reduce motion: holds on tick 1
triangle    (8,4) (12,12) (4,12), filled
glyphs      Swiss Glyphs, 16 px
tooltip     BusyStore.detail, for example "nixos-rebuild switch · 1:12", "cargo build · exit 101", "Claude · needs you"
            BusyStore.launchDetail while starting, for example "Zen Browser · starting · 0:03"

title row   launching   app id = launchId · mark = working · title = launchName in textMuted
            kitty       app id · mark = status · title          (slot kept when idle)
            other apps  app id · title                          (no slot)
```

## Signals

| Source | Event | Call |
|---|---|---|
| kitty watcher | shell command starts | `qs ipc call busy cmd <win> start ? <cmdline>` |
| kitty watcher | shell command ends | `qs ipc call busy cmd <win> end <exit> <cmdline>` |
| kitty watcher | a kitty window gains focus (tab switch or OS window focus) | `qs ipc call busy focus <win>` |
| kitty watcher | a kitty window closes | `qs ipc call busy drop <win>` |
| Claude Code | SessionStart, SessionEnd, Notification `idle_prompt` | `qs ipc call busy claude <win> clear` |
| Claude Code | UserPromptSubmit, PostToolUse | `… claude <win> working` |
| Claude Code | Notification `permission_prompt`, `elicitation_dialog`, `elicitation_url_dialog` | `… claude <win> needs` |
| Claude Code | Stop | `… claude <win> done` |
| Claude Code | StopFailure | `… claude <win> failed` |

| Launcher, dock | right after `entry.execute()` | `BusyStore.launch(entry)` (in QML) |
| Keybind | spawn `busy-launch <app id> <command…>` instead of the command | `qs ipc call busy launch <app id> <app id>`, then runs the command |
| Quickshell | a window appears (`ToplevelManager.toplevels` objectInsertedPost) or takes focus (`activeToplevel`) | clears the matching launch |

`<win>` is the kitty window id. kitty puts it in `$KITTY_WINDOW_ID` for everything running inside, and Claude Code hooks inherit it.

A launch matches a window when the window's app id (lowercase, or its last dot part) equals one of these: the entry's id, its StartupWMClass (`startupClass`), its command's file name, or kitty for terminal entries. So `org.gnome.Nautilus`, `nautilus` and a command of `/usr/bin/nautilus` all match each other.

## Files

```
qml/BusyStore.qml            singleton: state per kitty window, app launches, IpcHandler target "busy"
qml/BusyMark.qml             the 16 px mark (scanner, triangle, check, error)
kitty/busy_watcher.py        kitty global watcher → qs ipc
claude/settings.hooks.json   hooks block to merge into ~/.claude/settings.json
bin/busy-launch              keybind wrapper: marks the launch, then runs the app
preview/                     gif and a Qt Quick render
```

Tested here: the store's logic ran in a real QML engine (Qt 6.12, Quickshell types stubbed), and all 36 checks passed: 18 for kitty and Claude, 18 for launches. The launch checks cover timing, reverse-DNS ids, an app id that arrives late, single-window apps, focus returning as the launcher closes, terminal apps, two launches at once, IPC and the 15 s give-up. The watcher's command filter and call order were checked with a fake `qs`. Not tested here: Quickshell itself, kitty, Claude Code, mango.

## Known unknowns

- `exit_status` in the watcher data is in kitty's source (0.48) but not in its docs. If it is missing on your version, commands still show the scanner but never done or failed.
- Claude Code's docs do not say whether `Stop` fires after you press Esc. If it does not, the scanner stays until the session goes idle (`idle_prompt`), or until your next prompt.
- If you start Quickshell with `qs -c <name>`, every call needs `-c <name>`: `QS` in the watcher and the command in each hook.
- Inside tmux, `$KITTY_WINDOW_ID` comes from wherever the tmux server started, so the mark may land on the wrong window.
- Only the focused kitty window shows a mark. Background windows don't.
- Some apps report a window app id that matches none of their desktop entry's fields. Those show "starting" for the full 15 s. The test step below finds them; fix each with a StartupWMClass line in a local copy of the entry, or by passing the right id to `busy-launch`.
- Quickshell's docs say `DesktopEntry.execute()` ignores `runInTerminal`, so terminal entries only work if your launcher already opens them in kitty itself.
- Quickshell's docs don't say whether a window already has its app id when it is added to `toplevels`. The store handles both cases (it waits for `appIdChanged`).
- The focus-return guard assumes mango takes focus away from the app while the launcher is open. If it doesn't, the guard does nothing and does no harm.

## Prompt for your agent

```
Add a busy indicator after the app id in my bar's window-title module: kitty states and app launches. The spec and code are in busy-indicator/ (README.md is the spec). Don't redesign anything.

1. Read README.md, qml/BusyStore.qml, qml/BusyMark.qml, kitty/busy_watcher.py, claude/settings.hooks.json, bin/busy-launch.
2. Verify before wiring:
   - Quickshell: IpcHandler (Quickshell.Io), argument types, the `qs ipc call <target> <function> [args]` syntax, ToplevelManager.activeToplevel and ToplevelManager.toplevels with its objectInsertedPost signal (Quickshell.Wayland), and DesktopEntry id, name, startupClass, command, runInTerminal (Quickshell) on my installed version. Check whether I start Quickshell with -c; if so, add -c <name> to QS in the watcher, to every hook command and to busy-launch.
   - How my launcher and dock start apps (entry.execute() or something else), and how mango keybinds spawn commands.
   - kitty: `kitty --version`; confirm the global `watcher` option in kitty.conf and that on_cmd_startstop data has is_start, cmdline and exit_status (log `data` once, then remove the log line). Confirm shell integration is on.
   - The appId my title module shows for kitty (the store matches "kitty").
3. Install:
   - BusyStore.qml as a singleton next to my other singletons (register it the way my config registers them). BusyMark.qml beside my bar components. Map Theme.text, Theme.textMuted, Theme.tick, Theme.accent and Glyphs.check, Glyphs.error to my names.
   - In the title module: app id, 8 px, BusyMark, 8 px, title. Two cases:
     - While BusyStore.launching: app id = BusyStore.launchId (formatted the way my module formats app ids), mark mode "working", title = BusyStore.launchName in textMuted, tooltip BusyStore.launchDetail. The module must stay visible even when no window has focus.
     - Otherwise: the mark is visible only when the focused app is kitty (slot kept when idle), mode: BusyStore.kittyActive ? BusyStore.status : "idle", tooltip BusyStore.detail.
     - reduceMotion comes from my settings in both cases.
   - In the launcher and the dock: call BusyStore.launch(entry) right after starting the entry.
   - bin/busy-launch on my PATH (via Nix if my packages are declarative). Change my app keybinds to spawn `busy-launch <app id> <command>`.
   - busy_watcher.py in ~/.config/kitty/ and `watcher busy_watcher.py` in kitty.conf (or the home-manager equivalent if kitty.conf is generated by Nix). Restart kitty.
   - Merge the "hooks" block of claude/settings.hooks.json into ~/.claude/settings.json without removing my existing hooks.
4. Test and report each with yes/no:
   - `sleep 3` in kitty: scanner after 0.8 s, check for 3 s.
   - `sleep 3; false`: error mark for 8 s.
   - `ls`: nothing. `sleep 5` then Ctrl-C: nothing. nvim: nothing.
   - Run `sleep 5` and switch to another app before it ends; come back: the check is still there, then goes 3 s later.
   - Claude in kitty: scanner during a turn, triangle at a permission prompt, scanner again after approving, check when it stops. Press Esc mid-turn and tell me what the mark does.
   - Two kitty windows: the mark follows the focused one.
   - `qs ipc call busy get` prints the current state.
   - Start each app in my dock and launcher once. For each one, report whether the scanner and the name show, and whether they clear when the window opens. List every app that runs the full 15 s, with its desktop entry fields and the window's real app id, and propose a fix for each.
   - Start an app that is already open and focused (Zen): the scanner stays until the new window opens.
   - Start a keybind app through busy-launch: same behaviour.
5. Show me the diff and stop. Don't touch other modules.
```
