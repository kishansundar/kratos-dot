# IconTint

How any app icon in the tray row is made to match the glyphs: keep its shape, take the bar's ink.

- Use the icon as a mask; fill with `text`. Colour is dropped by design.
- Size 16px (request 16, or 32 and downscale ×0.5 for HiDPI); position on whole pixels.
- Don't add outlines, backgrounds or badges. Attention is the ink triangle, not a dot or colour.
