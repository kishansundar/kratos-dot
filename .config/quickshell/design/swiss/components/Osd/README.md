# Osd

The volume on-screen display: `osdWidth` × `osdHeight`, `surface` with a 1px `line` border, placed right-aligned directly under the bar — never bottom-centre.

**Consumer provides:** the label ("Volume"), the value (0–100) and muted state from the Audio service.

- Label and tabular `NN %` in `label`, on one line; a 2px (`marker`) bar beneath, `line` track with `accent` fill.
- Muted: the word "Muted" in `textMuted` beside the label — not colour alone.
- Fades out after 1.2 s over `durSlow`.
