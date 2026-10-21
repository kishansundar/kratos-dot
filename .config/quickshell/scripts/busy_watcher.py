"""kitty global watcher: tells Quickshell when a shell command starts and stops.

From the owner's busy-indicator package (16 October 2026), for the shell's services/Busy. The file lives in the shell's
repo (scripts/busy_watcher.py); ~/.config/kitty/busy_watcher.py is a link to it, and kitty.conf says
    watcher busy_watcher.py
kitty attaches global watchers to a window when it creates it: windows opened before the line (or before a config
reload) never report. kitty 0.49.2 passes exit_status, and makes a missing one 0.

Sends, through `qs ipc call busy ...`:
    cmd <win> start ? <cmdline>
    cmd <win> end <exit code> <cmdline>
    focus <win>          when a kitty window gains focus (tab switch or OS window focus), and before a command event
                         from the window that has the focus (a restarted shell, which knows no focus yet, learns it
                         at the next command instead of at the next focus change)
    drop <win>           when a kitty window closes

<win> is "<kitty pid>:<window id>", the same as "$KITTY_PID:$KITTY_WINDOW_ID" inside it.
Departures from the package, all found running it here: the window is keyed by kitty's pid too (each kitty started from
Super+Return is its own process, every one numbering its windows from 1); the calls go through one helper shell, not
a thread (see _HELPER); the focus before a command event.
on_cmd_startstop needs kitty's shell integration (on by default for bash, zsh, fish).
"""

from __future__ import annotations

import os
import shlex
import subprocess
from typing import Any

# If you start Quickshell with `qs -c <name>`, use ["qs", "-c", "<name>"].
QS = ["qs"]

# Long-lived interactive programs: running is not working. Claude reports through its own hooks.
IGNORE = {
    "claude", "nvim", "vim", "vi", "nano", "hx", "helix", "emacs", "micro", "kak",
    "less", "more", "man", "most", "bat",
    "htop", "btop", "top", "nvtop", "glances", "watch",
    "ssh", "mosh", "tmux", "zellij", "screen",
    "yazi", "ranger", "lf", "nnn", "lazygit", "tig", "gitui", "fzf", "sk",
    "nix-shell", "kitten", "kitty",
}
IGNORE_SUB = {("nix", "repl"), ("nix", "develop"), ("nix", "shell"), ("git", "log"), ("journalctl", "-f"), ("tail", "-f")}
# Interactive only when run bare (a REPL); with arguments they run a script and count.
REPL_IF_BARE = {"python", "python3", "ipython", "node", "deno", "bun", "ghci", "irb", "lua", "bc", "sqlite3", "psql"}
WRAPPERS = {"sudo", "doas", "env", "nice", "ionice", "time", "command", "exec", "nohup", "builtin"}

# One helper shell makes the calls, one at a time: start and end arrive in order and kitty's loop never waits. Each
# call is a line of tab-separated arguments on its stdin. (The package's worker thread did not do here: kitty holds
# Python's lock while it waits for events, so the thread ran its calls seconds late, a command's end only when the
# next key was pressed, and the scanner never stopped.)
_HELPER = 'while IFS="$(printf "\\t")" read -r -a f; do "$@" ipc call busy "${f[@]}" </dev/null >/dev/null 2>&1; done'
_helper: "subprocess.Popen[str] | None" = None


def _send(*args: str) -> None:
    global _helper
    line = "\t".join(" ".join(a.split()) or "?" for a in args) + "\n"
    for _ in range(2):
        if _helper is None or _helper.poll() is not None:
            _helper = subprocess.Popen(["bash", "-c", _HELPER, "busy-watcher", *QS], stdin=subprocess.PIPE,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
        try:
            assert _helper.stdin is not None
            _helper.stdin.write(line)
            _helper.stdin.flush()
            return
        except (OSError, ValueError):
            _helper = None


def _words(cmdline: str) -> list[str]:
    try:
        words = shlex.split(cmdline)
    except ValueError:
        words = cmdline.split()
    while words:
        head = words[0]
        if "=" in head and not head.startswith("=") and "/" not in head.split("=")[0]:
            words.pop(0)                               # FOO=1 make
        elif os.path.basename(head) in WRAPPERS:
            words.pop(0)
            while words and words[0].startswith("-"):  # sudo -E make
                words.pop(0)
        else:
            break
    return words


def interesting(cmdline: str) -> bool:
    words = _words(cmdline)
    if not words:
        return False
    prog = os.path.basename(words[0])
    if prog in IGNORE:
        return False
    if len(words) > 1 and (prog, words[1]) in IGNORE_SUB:
        return False
    if prog in REPL_IF_BARE and len(words) == 1:
        return False
    return True


def _label(cmdline: str) -> str:
    text = " ".join(cmdline.split())[:80].lstrip("-") or "command"
    return text


# kitty process : window id, the same as "$KITTY_PID:$KITTY_WINDOW_ID" inside it (the hooks use that). Every kitty
# started from Super+Return is its own process, and each numbers its windows from 1.
def _key(window: Any) -> str:
    return f"{os.getpid()}:{window.id}"


def on_load(boss: Any, data: dict[str, Any]) -> None:
    pass


def _has_focus(boss: Any, window: Any) -> bool:
    # kitty misses a new OS window's first focus (it comes before the window exists), so is_focused stays False
    # there until the focus leaves and comes back; the OS window's focus is known all the same.
    try:
        from kitty.fast_data_types import current_focused_os_window_id
        os_focused = window.os_window_id == current_focused_os_window_id()
    except Exception:
        os_focused = False
    return bool(window.is_focused or (os_focused and window is boss.active_window))


def on_cmd_startstop(boss: Any, window: Any, data: dict[str, Any]) -> None:
    if window is None:
        return
    win = _key(window)
    # Any command in the focused window says so, shown or not (claude, nvim): a new terminal, or a restarted shell, is
    # known before the first thing that shows.
    if _has_focus(boss, window):
        _send("focus", win)
    cmdline = str(data.get("cmdline") or "")
    if not interesting(cmdline):
        return
    if data.get("is_start"):
        _send("cmd", win, "start", "?", _label(cmdline))
    else:
        # exit_status is in kitty's source (since 0.48; 0.49.2 makes a missing one 0) but not in its docs; "?" when absent.
        status = data.get("exit_status")
        code = str(int(status)) if isinstance(status, (int, float)) else "?"
        _send("cmd", win, "end", code, _label(cmdline))


def on_focus_change(boss: Any, window: Any, data: dict[str, Any]) -> None:
    if window is not None and data.get("focused"):
        _send("focus", _key(window))


def on_close(boss: Any, window: Any, data: dict[str, Any]) -> None:
    if window is not None:
        _send("drop", _key(window))
