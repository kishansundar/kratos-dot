# PowerMenu

The power menu: lock, suspend, log out, reboot, shut down — words, each with its key. Opened from the `power` glyph at the bar's far right or `qs ipc call power toggle`, hung from the bar rule, `powerWidth` (240).

**Consumer provides:** the five actions (`loginctl lock-session`, `systemctl suspend`, mango's exit / `loginctl terminate-session`, `systemctl reboot`, `systemctl poweroff`), uptime, and the list of open windows.

**Layout**
- Header — "Power" + ruler, uptime in `mono`.
- Rows (`hitTarget`, `body`): Lock **L**, Suspend **S** — a 1px rule — Log out **E**, Reboot **R**, Shut down **P**. The key hint in `mono` `textFaint` at the right. Arrow keys move, Enter or the letter acts, Esc closes.
- No icons on the rows: the words are clearer than any glyph for these.

**Safety**
- Lock and suspend act at once.
- Log out, reboot and shut down start a **countdown** of `powerCountdown` (5 s) in the same panel: "Shutting down in 3 s" (`body` 600), an `accent` ruler draining to zero, the open apps listed in `mono` ("2 apps still open: zen, steam"), and two buttons: **shut down** (now, `accent`) and **cancel**. Esc or cancel stops it. The countdown runs even under reduceMotion — only its animation stops.
- The countdown's fill is the only `accent` while it runs; the menu itself has none.
- Never act on a single accidental keypress from outside the panel: the panel must be open and focused.
