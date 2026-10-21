# Cell

One app: its own icon at 48px, full colour, and a state mark beneath.

**Consumer provides:** desktop entry (name, icon), running windows with their tags, urgency.

| State | Mark under the icon |
|---|---|
| not running | nothing |
| running | 2px × 16px ink bar (`dockMark`) |
| needs attention | ink triangle |

- Hover: `surfaceAlt` cell; after 150 ms the name label rises above the dock with the detail in mono ("tags 1, 4 · 2 windows", or "not running").
- Keyboard focus: 2px `text` outline inset.
- Never tint, outline, badge or scale the icon; no hover magnification.
