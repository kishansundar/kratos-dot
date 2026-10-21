"""kitty global watcher: tells Quickshell when a shell command starts and stops.

Install
    cp busy_watcher.py ~/.config/kitty/
    # kitty.conf
    watcher busy_watcher.py
Restart kitty (a config reload only affects windows created after it).

Sends, through `qs ipc call busy ...`:
    cmd <win> start ? <cmdline>
    cmd <win> end <exit code> <cmdline>
    focus <win>          when a kitty window gains focus (tab switch or OS window focus)
    drop <win>           when a kitty window closes

<win> is the kitty window id, the same number as $KITTY_WINDOW_ID inside it.
on_cmd_startstop needs kitty's shell integration (on by default for bash, zsh, fish).
"""

from __future__ import annotations

import os
import queue
import shlex
import subprocess
import threading
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

_q: "queue.Queue[list[str]]" = queue.Queue()
_started = False


def _worker() -> None:
    # One thread, one call at a time: start and end arrive in order and kitty's loop never waits.
    while True:
        args = _q.get()
        try:
            subprocess.run(QS + ["ipc", "call", "busy", *args], stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
        except Exception:
            pass


def _send(*args: str) -> None:
    global _started
    if not _started:
        threading.Thread(target=_worker, name="busy-watcher", daemon=True).start()
        _started = True
    _q.put(list(args))


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


def on_load(boss: Any, data: dict[str, Any]) -> None:
    pass


def on_cmd_startstop(boss: Any, window: Any, data: dict[str, Any]) -> None:
    cmdline = str(data.get("cmdline") or "")
    if window is None or not interesting(cmdline):
        return
    win = str(window.id)
    if data.get("is_start"):
        _send("cmd", win, "start", "?", _label(cmdline))
    else:
        # exit_status is in kitty's source (0.48) but not in its docs; "?" when absent.
        status = data.get("exit_status")
        code = str(int(status)) if isinstance(status, (int, float)) else "?"
        _send("cmd", win, "end", code, _label(cmdline))


def on_focus_change(boss: Any, window: Any, data: dict[str, Any]) -> None:
    if window is not None and data.get("focused"):
        _send("focus", str(window.id))


def on_close(boss: Any, window: Any, data: dict[str, Any]) -> None:
    if window is not None:
        _send("drop", str(window.id))
