# Players

Shown only when more than one player is running: a `caps` eyebrow "PLAYERS" with its heading ruler, then a row per player — circle, identity, its state in `mono` `textMuted`.

**Consumer provides:** the MPRIS players and the active one.

- Filled ink circle = the player the bar and this panel show; ring = the others. Clicking a row makes it active (the bar follows).
- Order: playing first, then paused, then stopped; ties by most recent activity.
- Identity as the player reports it, lowercase app id when that is all there is ("zen", "spotify").
