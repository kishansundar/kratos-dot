# KeepAwake

Keep-awake as a shell module driving Quickshell's idle inhibitor: `stay-awake` (open eye, U+E032) when on, `stay-awake-off` (closed eye, U+E033) when off.

**Consumer provides:** the inhibitor state and a toggle.

- Click toggles; `aria-pressed` follows.
- Tooltip after `tipDelay`: "keep awake: off · click to stop the screen sleeping" / "keep awake: on · screen won't sleep".
- Ink only; the state is the eye's shape.
- Replaces any keep-awake tray app; don't run both.
