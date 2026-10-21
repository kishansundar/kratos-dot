# Ruler

SRuler: a 1px `tick` baseline with an 8px origin tick and 4px ticks every `rulerPitch` (8px) — the grid unit made visible. It is the system's signature mark.

**Consumer provides:** a length — `rulerShort` (32px, four pitches) under a heading, or the container's full width.

- Under a heading or eyebrow: `rulerShort`, starting at the text's left edge, `s1` below it. This replaces a full-width rule above sections.
- Full width: only where a scale is meaningful (a meter's track, the bar's bottom rule). Elsewhere separate with whitespace.
- Ticks are `tick` colour (≥ 3:1 on every ground); never `accent`.
- Tick heights come only from `tickMinor` (4), `tickMajor` (8), `tickValue` (16). Pixel-aligned: whole-pixel x positions, 1px wide (`tickW`).
- A heading with a ruler may carry `mono` `textMuted` metadata at its right ("2 active sessions").
