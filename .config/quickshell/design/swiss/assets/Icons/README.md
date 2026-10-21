# Icons

Swiss Glyphs as 16×16 SVGs, one per glyph, for documentation and anywhere a font cannot be used. The shell itself uses the font (`fonts/SwissGlyphs.woff2`, `SwissGlyphs.ttf` in the repo) through `Glyphs.qml`.

- Ink: every SVG is filled `#111111` — the light theme's `text`. An `<img>` cannot inherit colour; recolour by editing the fill or use the font.
- Grid: 16px, solid geometry, 2px features, square ends, `shape-rendering: crispEdges`. Render at exactly 16px on whole pixels.
- Names match the font's glyph names and the `Glyphs.qml` keys (kebab-case here, camelCase in QML: `wifi-3` → `Glyphs.wifi3`).
- `nixos`, `nixos-a`, `nixos-b`: the official NixOS snowflake from NixOS/nixos-artwork (CC-BY 4.0), fitted to the 16px grid. `-a` and `-b` are the two alternating sets of three lambdas, for two-tone use.
