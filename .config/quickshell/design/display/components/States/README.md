# States

The four non-ideal cases, each with its exact wording.

- **Sending** (47 → 70): fill and value in `textMuted`, a faint tick at 47, eyebrow state "setting…". Ends in ink when the read-back says 70.
- **Failed**: after `ddcTimeout` with no matching read-back the slider returns to the last confirmed value; under it, the `error` glyph, "PG279Q didn't answer" in mono, and a "retry" button that resends the last target. Not a toast.
- **No DDC/CI**: "This monitor doesn't answer DDC/CI. Use its own buttons for brightness." Night light stays.
- **Two monitors**: one block per monitor, eyebrow = model, connector at the right; `s6` apart.
