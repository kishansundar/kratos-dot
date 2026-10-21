# DeviceRow

A full-width radio row for choosing one item — audio devices, Wi-Fi networks, Bluetooth devices: a circle, then the name. Selected = filled ink circle (`markCircle`); not selected = 2px ink ring.

**Consumer provides:** the item name (elided with a tooltip if long), an optional trailing glyph or `mono` detail, `selected`, `onClicked`.

- Height `hitTarget`, padding `s3`, gap `s3`, text `body`, flush-left. Hover `surfaceAlt`, pressed `line`.
- The circle is ink, not accent: selection is an on-state, and red stays reserved for the view's one active thing.
- Network rows: strength from `wifi-0`…`wifi-4`; secured networks add `lock`; a weak network may add an ink triangle with the word "weak".
