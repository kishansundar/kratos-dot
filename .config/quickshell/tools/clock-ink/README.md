# Clock ink table

`bar/Clock.qml` places the hours, minutes, weekday and date by where their ink really is, read from `bar/ClockInk.js`.
Qt's TextMetrics tight box is about 1 px off against the hinted, natively rendered Geist, enough to make the gaps around
the red stroke visibly uneven. Regenerate the table after any change to the clock's fonts or styles:

1. On a scale-1 Wayland output, with the pointer away from the top-left corner:
   `quickshell -p tools/clock-ink/shell.qml`, capture `grim -g "0,0 1000x400" light.png`, quit it;
   the same with `PROBE_DARK=1` into `dark.png`. (A test rig's headless mango works; the live desktop does too, but the
   probe window then sits under the bar's exclusive zone: shift the capture accordingly.)
2. `python3 tools/clock-ink/measure.py light.png dark.png bar/ClockInk.js` (needs Pillow).

`shell.qml` copies Theme.font.count / Theme.font.label and Txt's settings: keep them in step.
