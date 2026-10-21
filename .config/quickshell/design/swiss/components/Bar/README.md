# Bar

The top bar: one full-width `PanelWindow` per screen, `barHeight` tall, ending in a 1px `line` rule on which each module's start is marked by a 4px `tick` (8px at the origin) — the bar is a ruler.

**Consumer provides:** the screen (via `Variants { model: Quickshell.screens }`), the Mango service for that monitor's tags, layout and focused window, and the status services.

- Background `bg`; padding `barPadX`; `moduleGap` between modules, `groupGap` between groups.
- Left group: NixOS mark (two-tone, the origin tick under it) · Tags ruler · app id (`mono` `textMuted`) + focused title (`label` `textMuted`, elided at 40% of bar width, full text in a tooltip).
- Right group: NowPlaying (player id, title slot ≤ 192px that scrolls when longer, previous / play-pause / next; progress on the bar rule) · Tray drawer (chevron; icons slide out inside the bar) · status glyphs (agent, awake, network, Bluetooth, audio) · Clock · `power` glyph at the far right. Each status glyph and `power` opens its panel from the separate **Quickshell Panels** system (Wi-Fi, Bluetooth, sound, notifications, power menu).
- All bar text shares one baseline; `count` numerals and `label` text sit on it together.
- Layer-shell namespace `quickshell-swiss-bar`; exclusive zone = `barHeight`.
- The focused tag tick is the bar's one `accent`; the NixOS mark's red is brand colour of a logo, not a state.

**Don't:** draw rules other than the bottom one, add a battery or backlight module (desktop host), put a centred group in the bar.
