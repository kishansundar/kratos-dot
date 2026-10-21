# Tags

The tag ruler: the focused tag's number in `count`, the total as `/N` in `label` `textMuted`, then one 2px tick per tag at `tagPitch` (12px), bottom-aligned.

**Consumer provides:** per-monitor `tags[]` from the Mango service (`{ index, occupied, focused, urgent, clientCount }`), the visible tag count, and the dispatch functions.

| State | Tick | Colour |
|---|---|---|
| Empty | `tagTickEmpty` (4px) | `tick` |
| Occupied | `tagTickOccupied` (12px) | `text` |
| Focused | `tagTickActive` (16px) | `accent` — the bar's one accent |
| Urgent | 12px `text` + ink triangle cap (`markTriangle`) | ink — the triangle is the signal, not colour |

- State reads by height and shape first, colour second: red is reserved for the focused tag; urgency is the triangle.
- Hover raises a tick to 16px to show which tag a click will hit; a tooltip names the tag.
- Click = view tag; middle-click = toggle tag view; right-click = move focused client to tag; scroll anywhere on the ruler = next / previous tag.
- Each tick's hit column is `tagPitch` × `barHeight` (12 × 32), under the 32 × 32 `hitTarget`. Scroll and the keyboard are the primary ways to switch; the ticks are a precise pointer shortcut.
- Show the configured tags only (mango's count; `/5` for five). The number updates instantly; only colour animates.
