# Parts

The pieces every panel here shares, all on Quickshell Swiss tokens.

- **Switch** (`sw2`) — a word and the on/off circle: "on" with a filled circle, "off" with a ring. `role="switch"`, `aria-checked`. Used for radios, adapters, DND. Never a sliding pill.
- **Row** (`prow`) — circle (filled = selected / connected, ring = not), name (elided, tooltip), trailing glyphs and `mono` metadata in `textMuted`. `hitTarget` high, hover `surfaceAlt`. A row that is working shows "…" after its name and ignores clicks.
- **Detail** — the area a selected row expands into, indented to the text: `mono` facts and text actions, or a form.
- **Text field** — `fieldH`, 1px `line` border, `bg` fill, `mono`, 2px `accent` focus outline inset. Error: `error` border plus a message with the error glyph underneath.
- **Mini meter** — `miniMeter` (32) wide ruler with an ink fill, for device battery.
- **Footer** — a 1px rule, a settings text button at the left, the backend in `mono` `textFaint` at the right.
