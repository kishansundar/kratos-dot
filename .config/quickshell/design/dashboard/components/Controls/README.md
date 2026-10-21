# Controls

Four switch rows in the dashboard's fourth lower column: Tailscale, night light, caffeine, do not disturb.

**Consumer provides:** each feature's current state (read back from the system, never assumed), the actions, and change notifications.

**The row**
- Two `listRow` (32) rows per control, so the column keeps the lower band's rhythm: the switch row (`role="switch"`): mark (filled circle on / ring off) · name (`body`, 600 when on) · state word at the right (`label`, `text` when on); then the option row, indented to the name, in `mono` `label`. Off rows are `textMuted`. Hover `surfaceAlt`.
- No glyphs: the names say what each is.
- While a command runs the word reads "…"; on failure it snaps back and the word becomes "failed" in `error` with the error glyph.
- Never a filled block, never `accent`.

**Tailscale**. On: `tailscale up --accept-dns=false`; off: `tailscale down`. Option "tailscale dns" (ring = off; on runs `tailscale set --accept-dns=true`). State word: "stopped", or the tailnet IPv4 when connected, or "needs login" with a triangle. Requires `tailscale set --operator=$USER` once (the agent asks first).

**Night light**. On: start `wlsunset` / `gammastep` at `nightTempDefault` (only if mango supports wlr gamma control; else "unsupported"). Option row: a mini ruler 2500–6500 K with the value at its right; arrows step `nightTempStep`. "sunset → sunrise" lives in the row's right-click menu to keep one option row.

**Caffeine** — the same state as the bar's keep-awake (open eye) in Quickshell Tray Row. Option: `30m · 1h · 2h · off`, the selected one with a 2px ink underline. State word "until 18:48".

**Do not disturb**. Same duration option; "0 held" after it.

- All persist in `State` except Tailscale, whose truth is `tailscale status`.
- Keyboard: Tab through rows; Space / Enter toggles; options follow.
