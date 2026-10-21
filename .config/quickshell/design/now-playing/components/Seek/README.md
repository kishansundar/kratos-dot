# Seek

The time row. Its form comes from what the player reports, not from guesses.

**Consumer provides:** length and whether it's supported, position and whether it's supported, `canSeek`, a seek action.

| Form | When | Looks like |
|---|---|---|
| Seekable | length > 0, position reported, can seek | ruler (4px ticks every 10 %, 8px at 0 / 50 / 100 %), 3px ink fill, 2 × 16 ink handle; elapsed left, "−remaining" right, `mono` `textMuted`, `s1` below |
| Read-only | length > 0, position reported, can't seek | same ruler and times, no handle, default cursor, no hover tooltip |
| Live | position advances for `liveProbe` (3 s) with no length | no ruler: a 1px `line` rule above, then ink circle + "live" and the time listened at the right, `mono` `textMuted` |
| Untimed | no usable position | no ruler: a 1px `line` rule above, then "zen doesn't report position" in `mono` `textFaint`, using the player id |

- Seekable: click anywhere to jump, drag the handle to scrub, hover shows the time under the pointer. Hit area is `hitTarget` tall, ruler at its bottom; top margin `s2` so the visible gap above is `s5`.
- Times: m:ss under an hour, h:mm:ss over; minus sign is U+2212.
- Untimed is the default until `liveProbe` has passed. Never show "live" for a track that merely lacks a length.
