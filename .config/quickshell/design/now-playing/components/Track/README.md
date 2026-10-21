# Track

The art and the words, in one of three layouts chosen from the art's aspect ratio (width / height of the loaded image).

**Consumer provides:** art URL, title, artist(s), album, year, the track URL (for the site's host).

- **Album** (aspect `artSquareMin` 0.8 to `artSquareMax` 1.25): `artSize` 128 square on the left, words on the right, top-aligned, `s4` apart. Centre crop is allowed only here. Title up to `titleLines` (3) lines.
- **Video** (aspect > 1.25): a full-width frame at `artWideRatio` 16 : 9 (336 × 189), words below it, `s3` apart. The image is fitted, never cropped: a 4:3 thumbnail gets `surfaceAlt` sides. Title up to `titleLinesWide` (2) lines.
- **Bare** (no art, or it failed to load): no frame and no placeholder glyph; words run full width. Also shown while art is loading, so the panel changes layout at most once.
- Posters (aspect < 0.8): album layout, fitted, `surfaceAlt` sides.
- Words: title `body` 600 (full title in the tooltip); artist `body` `textMuted`, several joined with ", "; source line `mono` `textFaint`, at most 2 lines: "album · year" for music, the site's host for browser media ("youtube.com"), "format · rate" for local files. Missing fields are omitted, never "Unknown".
- Keep the track's own case and language; Tamil and other scripts fall back to Noto.
