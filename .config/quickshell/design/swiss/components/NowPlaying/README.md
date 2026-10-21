# NowPlaying

The bar's media module: the player id in `mono`, a clipped title slot no wider than `npTextMax` (192px), then previous / play-pause / next. The track's progress is drawn on the bar's bottom rule under the module.

**Consumer provides:** the active MPRIS player (`Quickshell.Services.Mpris`): identity, title, artist, playback state, position and length, `canGoPrevious` / `canGoNext` / `canPause`; the list of players.

**Text**
- Content: `Title — Artist` (em dash, spaces). No album. If the player gives no artist, the title alone. Keep the track's own case.
- Slot: `label`, max `npTextMax` = 192px ≈ 31 characters of Geist at 12px. Shorter text shrinks the slot; the transport stays put because it sits at the module's right edge.
- Longer text scrolls inside the slot: hold `marqueeHold` (1.5 s), scroll left at `marqueeSpeed` (32 px/s, linear), the text followed by its repeat `marqueeGap` (48px) later, so it loops seamlessly; hold again at each start.
- Scroll on a track change for **two loops, then rest** at the start with an ellipsis. Hovering the slot scrolls it again; while hovered it pauses where it is. (Moving content must be stoppable — WCAG 2.2.2.)
- `Theme.reduceMotion`: never scroll; elide with an ellipsis; the full text in the tooltip.
- Hard clip at the slot edges — no fades (no gradients in this system).

**Transport**
- Three `hitTarget` (32 × 32) buttons with 16px glyphs: `prev`, `pause` while playing / `play` while paused, `next`. Disabled (`textFaint`, no hover) when the player cannot do it.
- Paused: the title turns `textMuted`.

**Progress**
- A `progressW` (2px) ink line on the bar's bottom rule, from the slot's left edge, width = position / length × slot width. Updated once a second; hidden for streams without a length.

**Players**
- One player: just its id. More: the id plus `+N` in `textFaint`; clicking the id cycles players. Prefer the one playing.
- No player: the module is absent (no empty state in the bar).

**Clicks**
- Title: open the Now Playing panel — specified in **Quickshell Now Playing** (art, seek ruler, transport, shuffle / repeat, player volume, players). Middle-click the title: play / pause.
- Scroll on the module does nothing: scrolling is reserved for volume on the audio glyph.

Total width: id (~48) + slot (≤ 192) + `s2` gaps + 3 × 32 transport ≈ 350px at most.
