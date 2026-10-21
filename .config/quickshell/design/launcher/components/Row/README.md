# Row

One result: number slot (shown only while Alt is held) · the app's icon tinted to `text`, 16px · name in `body` 500 with matched letters underlined (2px ink, offset 3px) · generic name in `textMuted` · "open ↵" on the selected row.

**Consumer provides:** name, generic name, icon, matched character positions, selected state.

- Height `rowH` 40; selected `surfaceAlt`; hover moves the selection.
- Long names never wrap; the generic name truncates first.
- No category labels, no descriptions longer than the generic name, no colour.
