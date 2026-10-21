# Query

The search line: search glyph, the query in `h2` with a 2px ink caret, the count at the right in mono, and below it a ruler whose ink fill is the share of apps still matching.

**Consumer provides:** query text, match count, total app count.

- Placeholder "Search apps" in `textFaint`.
- Ruler: 1px baseline, 8px ticks at both ends, 4px ticks every `rulerPitch`; fill `rulerFill` (3px) ink, width = matches ÷ total. No match: no fill.
