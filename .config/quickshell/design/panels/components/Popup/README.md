# Popup

SPopup: the shell every panel in this system is built on — `surface` background, 1px `line` border, `radius` 0, `s5` inner padding, `popupWidth` wide — hung flush from the bar's bottom rule.

**Consumer provides:** the anchor module (popups align left under left modules, right under right modules), the content sections, and the open state.

- No floating gap: its top edge sits on the bar's rule.
- Content on the 6-column grid (`s2` gutter). Each section opens with a `caps` eyebrow in `textMuted` over a 1px `line` rule; sections are `s6` apart. Optional panel title in `h2`.
- Open: opacity 0→1 plus 8px vertical translate, `durMed`, `easeOut`; close `easeIn`. No scale, no bounce.
- Closes on Escape, click outside, or re-clicking its module. Traps focus; Tab follows reading order.
- No shadow, blur or gradient.

- Every panel here (Network, Bluetooth, Sound, Notifications, Date and time, Power) is an SPopup — and so is the Now Playing panel from Quickshell Now Playing; only one is open at a time — opening another closes the first.
