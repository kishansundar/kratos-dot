# Button

SButton: a text button, at least `hitTarget` square, `radius` 0, label in `body`, flush-left.

**Consumer provides:** the label text (a word, not an icon, unless the icon disambiguates), an `onClicked` handler, and `enabled`.

- Default: transparent with a 1px `line` border. Text variant: no border — for notification actions and "Clear all".
- Primary: `accent` fill, `onAccent` label. At most **one** primary per view; it is that view's single use of `accent`.
- States: hover `surfaceAlt` fill · pressed `line` fill · keyboard focus 2px `accent` outline inset · disabled `textFaint`, no hover. Colour transitions `durFast`.
- Cursor: pointing hand.
