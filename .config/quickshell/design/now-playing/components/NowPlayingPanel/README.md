# NowPlayingPanel

The whole panel: what is playing and every control the bar has no room for. It opens from the title in the bar's Now Playing module, hangs from the bar rule right-aligned under it, `popupWidth` (384) on `surface`, 1px `line` border, `s5` padding. Esc, a click outside or another click on the title closes it.

**Consumer provides:** the active MPRIS player (`Quickshell.Services.Mpris`): identity, title, artist, album, art URL, position, length, playback state, the capability flags (seek, raise, previous / next, shuffle, loop, volume, length / position support) and the list of players.

**Order:** Header → Track → time row → Transport → Volume → Players. See Layouts and States for every combination.

- Header: h2 "Now playing", heading ruler; at the right the player id in `mono` `textMuted`, then `+N` in `textFaint` when other players exist, then a chevron when the player can be raised. The whole group is one button that raises the player.
- One `accent`: the play / pause square. No border on it, ever; the focus ring is an ink outline outside it, keyboard only.
- Opening: opacity + 8px slide down over `durMed`; instant under reduceMotion.
- Keys: Space · ← / → · ↑ / ↓ · N / P · Esc. Focus starts on play / pause; Tab follows reading order.
- Updates: position every `positionTick` while open; everything else on player signals. Nothing polls while closed.
- No queue and no lyrics: MPRIS doesn't provide them.
