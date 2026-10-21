# Swiss icons

26 single-colour pictograms: your 24 apps plus the trash, empty and full. They install as an icon theme under the icon names your apps already use, so the dock, the launcher and the tray pick them up with no per-app changes. The shell paints them in its text colour, so they follow your light/dark toggle at once.

Preview: `preview/swiss-icons.png` (dock, all icons at 48 and 16 px, launcher rows, tray next to your bar glyphs, light and dark). `preview/pixels-48.png` and `preview/pixels-16.png` show the true pixels.

## The system

```
two drawings   48 px master  scalable, used from 17 px up (dock 48, launcher 24)
               16 px drawing  tray and anything smaller
48 grid        live area 4–44 · 4 px strokes · gaps of 4 px or more, so it stays crisp at 24 px
16 grid        Swiss Glyphs rules: 2 px minimum feature, 1 px only for gaps and rails
colour         one colour, no red. Raw fill #76766f: anything that shows them unpainted
               still reads on light (4.2:1 on #f4f4f1) and dark (4.3:1 on #0d0d0d)
```

How similar apps stay apart:
- **Terminal window.** A frame with a thick title band means kitty or an app that runs inside it: Neovim, Yazi, btop.
- **Outline or solid.** Zen is an outline globe, Helium a solid one. Trash is an outline bin, Trash full a solid one.
- **Editors.** Zed is `</>`, Emacs is `(≡)` (Lisp parentheses round text), Neovim is text lines with a block cursor inside a terminal window.

Every icon shows what the app does. None of them draws the app's logo.

| Icon name | App | Pictogram |
|---|---|---|
| kitty | kitty | terminal window with a prompt `>_` |
| zen | Zen Browser | globe, outline |
| helium | Helium | globe, solid |
| org.gnome.Nautilus | Files | folder |
| spotify-client | Spotify | two beamed notes |
| user-trash | Trash | bin, outline |
| user-trash-full | Trash, full | bin, solid |
| 1password | 1Password | key |
| rustdesk | RustDesk | two screens |
| zed | Zed | `</>` |
| nvim | Neovim | terminal window, text lines and a block cursor |
| emacs | Emacs, Emacs Client | `(≡)` |
| obsidian | Obsidian | page with text lines |
| yazi | Yazi | terminal window with a folder |
| btop | btop | terminal window with a pulse line |
| mpv | mpv | film frame with a play triangle |
| qimgv | qimgv | picture: mountain and sun |
| org.openrgb.OpenRGB | OpenRGB | three overlapping rings (light mixing) |
| polychromatic | Polychromatic | keyboard |
| org.freedesktop.Piper | Piper | mouse |
| org.coolercontrol.CoolerControl | CoolerControl | fan |
| nvidia-settings | NVIDIA X Server Settings | chip |
| org.pulseaudio.pavucontrol | Volume Control | three faders |
| preferences-system-network | Advanced Network Configuration | network tree |
| nix-snowflake | NixOS Manual | open book |
| steam | Steam (planned) | gamepad |

## Files

```
Swiss/index.theme           theme definition (set Inherits before installing)
Swiss/scalable/…            48 px masters
Swiss/16x16/…               16 px drawings
qml/AppIcon.qml             paints an icon in one colour; leaves icons the theme doesn't draw in full colour
icons.json                  the 26 names the theme draws
preview/                    previews
```

## How it should be wired

- **Where they apply.** I recommend the shell only: put `//@ pragma IconTheme Swiss` at the top of the root Quickshell config, or set `QS_ICON_THEME=Swiss`. Then the dock, the launcher and the tray use Swiss, and every other app keeps its own icons. Making Swiss the GTK/Qt icon theme also works, but then apps outside the shell show the raw grey.
- **Inherits.** `Inherits=` must list your current icon theme first, then hicolor, so icons this theme doesn't draw still resolve.
- **Painting.** Use `AppIcon.qml`. It fills a rectangle of `color` through the icon's shape. Don't use MultiEffect's colorization: I tested it and it gives the wrong shade, and the mask's default thresholds cut off the smooth edges (`AppIcon` sets them).
  - Dock: `AppIcon { icon: …; size: 48; color: Theme.text }`. This replaces the Dock system's rule "full colour, never tinted". Running bar, hover label and layout stay as they are.
  - Launcher: `size: 24`; the selected row passes `color: Theme.bg`.
  - Tray: 16 px, `color: Theme.text`. Some tray items send pixels instead of an icon name; map those items' ids to the icon names above.

## Known unknowns

- `nix-snowflake` and `preferences-system-network` are shared names. With the shell-only setup only the shell's uses change, so check the shell doesn't show `nix-snowflake` anywhere as the OS mark (the bar uses the glyph font, which is unaffected).
- Some apps may ask for a different icon name than the one listed. Steam's tray and the 1Password and RustDesk trays are the likely ones.
- The painting method was tested on Qt 6.12 with software OpenGL, not on your Qt.

Tested here:
- all 26 names match your list, and all 52 SVGs parse;
- Qt's icon lookup returns the 16 px drawing at 16 px for all 26, and the 48 px master at 24 and 48;
- `AppIcon` paints in the colour it is given, with edges within 0.1 of the original's coverage, and shows an icon the theme doesn't draw in its own colours.

Not tested: GTK, or Quickshell itself.

## Prompt for your agent

```
Install the Swiss icon theme from swiss-icons/ (README.md is the spec) for my Quickshell shell. Don't redraw or rename any icon.

1. Read README.md, Swiss/index.theme, qml/AppIcon.qml, icons.json.
2. Verify first and tell me what you found:
   - My current icon theme (GTK and Qt) and how icons are configured on this NixOS / home-manager setup.
   - Quickshell's IconImage (Quickshell.Widgets), Quickshell.iconPath(name, fallback), the `//@ pragma IconTheme` pragma or QS_ICON_THEME, and MultiEffect's maskThresholdMin / maskSpreadAtMin on my installed versions.
   - The icon names my dock, launcher and tray actually request, for every app in icons.json. List any app whose name differs from icons.json, and any tray item that sends pixels instead of a name (check Steam, 1Password, RustDesk).
3. Install:
   - Set Inherits=<my current theme>,hicolor in index.theme. Install Swiss/ as an icon theme (declaratively through Nix or home-manager if that's how my icons are managed).
   - Scope it to the shell only with `//@ pragma IconTheme Swiss` in the root config (or QS_ICON_THEME=Swiss). Don't change the GTK/Qt icon theme.
   - Add AppIcon.qml beside my components; map Theme.text and Theme.bg to my names.
   - Dock: AppIcon at 48, color Theme.text. Update the dock's rule from "full colour, never tinted" to "painted in text colour". Keep everything else.
   - Launcher: AppIcon at 24; the selected row uses Theme.bg. Remove the old tint.
   - Tray: paint 16 px icons with AppIcon (Theme.text); map pixel-only tray items by id to the names in icons.json.
4. Test and report each with yes/no and a screenshot:
   - Dock and launcher in light and dark: every icon is the Swiss one, in the text colour, with smooth edges.
   - The launcher's selected row shows the icon in the background colour.
   - The tray: the 1Password and RustDesk icons are the Swiss ones at 16 px.
   - Trash shows empty and full correctly.
   - An app not in icons.json still shows its normal full-colour icon.
   - Other apps outside the shell are unchanged.
5. Show me the diff and stop.
```
