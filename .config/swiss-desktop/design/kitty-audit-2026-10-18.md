# Kitty light / dark audit, 18 October 2026

kitty 0.49.2 (nixpkgs), Geist Mono 11, NixOS + mango + Quickshell. Configs are ordinary user files: `~/.config/kitty`
(the theme files link into `build/` here), with no Home Manager. Colours come from `tokens/*.env` → `swiss-build`.

**Method.** Everything was rendered in a headless rig, not just read from config files:
- The rig (`~/.cache/swiss-desktop-work/kitty-rig`) is a headless mango at 2560 × 1440. It runs the live mango config
  with blur and opacity rules, the live wallpaper layer and the real kitty binary, config and fonts. Each page puts
  four tiles side by side, as on the desktop.
- A stand-in desktop portal on a private bus switches Light / Dark, so kitty's own switching path was exercised.
- `play/suite.sh` prints the test pages: ANSI 0-15, text on coloured grounds, attributes, 256 / truecolour, and logs.
- Real programs ran on top of that: fish + starship, git, eza, GNU ls, bat, fzf, lazygit, btop, Neovim (LazyVim) and
  Claude Code's first screen.
- Colour maths is in `tools/colour.py`: WCAG 2.x, APCA-W3 0.0.98G, CIEDE2000, Machado CVD.
- Composite grounds were computed from the blurred wallpaper actually captured behind a clear kitty, for 8 posters.
- Screenshots are in `kitty-rig/shots/`. The key ones:
  - `before-*-shell.png` / `final-*-shell.png`, also `before-after-shell.png`
  - `opacity-compare.png`
  - `sel-both.png`, `url-both.png`, `sw-all.png` (live switching), `tabs-full.png`

The live screen was not captured: the owner was playing, then locked. Everything visual comes from the rig.

## A. Executive assessment

The ink and paper (`#111111` on `#F4F4F1`, 17.1:1) and chalk and graphite (`#F2F2EE` on `#0D0D0D`, 17.3:1) were sound.
So were colours 1-6 and 9-14 as text, at 5.4-11.6:1. The weaknesses were in how the palette meets real programs:

1. **Light Mode had no light colour among 0-15.** White (7) was a dark grey and bright white (15) black. Every
   "white text on a coloured ground" pair a program prints was invisible, at 1.05-1.3:1. That covers fish's
   history-search match, ls setuid and sticky entries, and FAIL badges.
2. **Transparency did the most damage.** Kitty's 80 % background and mango's 82 % unfocused windows let the poster
   through: the headline was readable through the terminal and the paper turned grey or pink. Worst-case quiet text
   was 3.0-3.3:1 focused and 2.9-3.2:1 unfocused.
3. **Faint text (SGR 2) on paper was 1.6:1.** Kitty blends faint text in linear light with `dim_opacity 0.4`. Claude
   Code uses faint text about 1,860 times in its UI code.
4. **Some programs' own defaults clashed with the palette in one mode.**
   - fish: its default highlight pairs failed in both modes (see B4), and it set comments in red beside its bright-red
     errors.
   - lazygit: its dark selected line was 2.2:1.
   - fzf: its 256-colour scheme drew a dark bar on paper.

All four are fixed and re-verified. The fix for item 2 was the owner's choice from rendered options.

## B. Light theme

| ID | Problem (measured) | Cause | Fix | After |
|---|---|---|---|---|
| L1 | White on colours 1-6 / bright black: 1.05-1.27:1 | `ansi7` was 595650, a dark grey | `ansi7` = E6E6E1 (the surface2 token) | 4.59-5.55:1 |
| L2 | starship / fastfetch used white as their quiet grey | they matched the old white | `bright-black` / `90` | 5.2:1 |
| L3 | Faint text 1.6:1 (APCA 26) | `dim_opacity 0.4`, linear-light blend | `dim_opacity 0.7` | 2.9:1 (APCA 53) |
| L4 | Paper went to L* 66-76 grey (black poster), pink over the red disc; headline legible | 80 % background × 82 % unfocused | 94 % + terminals solid when unfocused | L* 91-93 in the same spot |
| L5 | White (L* 37) darker than bright black (L* 43); ΔE 6.8 | as L1 | as L1 | white is now the light ground |
| L6 | fzf: a dark bar on paper; info in khaki 144 | fzf's 256-colour dark scheme | the Swiss 16-colour scheme | follows the palette |

What is left in Light Mode:
- **Black on colours** (ls tw/sg, PASS badges, tmux's status bar) is about 3.0:1. Colours dark enough to be text on
  paper cannot also carry black text; the same is true of every light theme compared (see D).
- **White as text on paper** is now 1.1:1. Configs here use 8 or 39 instead.

## C. Dark theme

| ID | Problem (measured) | Cause | Fix | After |
|---|---|---|---|---|
| D1 | Grey text 4.0:1 over the poster's white words; ground varied 13 L* (22 over all posters) | as L4 | as L4 | ≥ 4.5:1, ground within ~2 L* |
| D2 | lazygit selected line 2.2:1 (blue under near-white) | lazygit's dark default | `darkTheme` selection token | 12:1 |
| D3 | fish search match / selection 1.5:1; pager progress 1.8:1 | fish defaults (white on bright black, bright white on cyan) | fish theme `swiss` | 12:1 / 5.3:1 |
| D4 | Faint bright black 2.7:1 | as L3 | as L3 | 4.0:1 (faint text: L* 83 against normal text's 95, still quieter) |

What is left in Dark Mode:
- **White on colours** is 1.0-1.8:1 (ls setuid and sticky, white-on-red badges). The colours are light, so black on
  them is the working pair (4.5-7.1:1, now tested). Making white legible would need darker colours, which would fail
  as text on graphite. This affects GNU ls and fd special-permission entries only; the owner's `l` / `ll` use eza.
- **Black text** (0) on graphite is 1.3:1, which is the convention.

## D. Palette

Measured on opaque grounds:

| | Light | Dark |
|---|---|---|
| default text | 17.1:1, APCA 99 | 17.3:1, APCA -99 |
| colours 1-6 as text | 5.4-6.3:1 (L* 38-42, equal weight) | 5.8-9.1:1 |
| bright 9-14 | deeper: 7.3-8.4:1 | lighter: 7.0-11.6:1 |
| quiet grey (8) | 5.2:1 | 5.3:1 |
| faint default (0.7) | 2.9:1 | 12.4:1 (quieter by 12 L*) |
| selection (text on it) | 13.6:1, ΔE 13 from the paper | 12:1, ΔE 23 from the graphite |
| cursor / text under cursor | 17.1 / 17.1:1 | 17.3 / 17.3:1 |
| active tab / inactive tab | 15.1 / 5.3:1 | 14.2 / 5.9:1 |

Separation (CIEDE2000): error and success are 64 apart, and every pair of meanings is at least 20 apart. Under simulated
colour blindness, two pairs are hue-only:
- red / yellow in Light Mode (deuteranopia, 3.5);
- blue / magenta (protanopia and deuteranopia, 4.5-8.3).

Programs label errors and warnings in words. Within the contrast limits, separating red and yellow by lightness would
only reach ΔE ≈ 6, so it was not changed.

Colours 16-255 are kitty's fixed xterm values: the 232-255 grey ramp is dark to light in both modes. `palette_generate`
(kitty 0.47+) was considered and not enabled:
- the configs here no longer use 16-255;
- `semantic` would reverse the meaning of absolute picks like 16 / 231 in Light Mode;
- 0.49.2 has a bug with unset 16-255 in the ssh kitten (#10661).

For comparison, these are the published themes considered:
- **Modus Operandi:** keeps 7 light (a6a6a6) and 15 dark, much as now.
- **Alabaster:** sets 7 and 15 to the background (white text is invisible).
- **GitHub Light:** 7 and 15 are mid greys.

The Swiss pair was kept and refined rather than replaced. Its ink, paper and red are the desktop's tokens; its
defects were in the white slot, faint text and transparency, not in the hues.

## E. Programs tested

| Program | Colours from | Result |
|---|---|---|
| fish 4.9 | was fish's default theme | fixed: theme `swiss`, follows kitty live (`fish_terminal_color_theme`) |
| starship 1.26 | ANSI names (palette `wallpaper`) | white → bright-black; prompt verified in both modes |
| fastfetch 2.69 | 39 / ANSI | white → 90 |
| git 2.55 (no user config), eza 0.23, GNU ls | ANSI defaults | readable; ls special-permission entries as in B and C |
| bat 0.26 | detects light / dark itself | readable in both |
| fzf 0.74 | was 256-colour dark | `FZF_DEFAULT_OPTS` in config.fish: the 16-colour Swiss scheme (red ▌ pointer = "here") |
| lazygit 0.66 | asks the terminal for its background | `~/.config/lazygit/config.yml` (generated); follows live |
| btop 1.4.7 | its own truecolour swiss theme (`build/current`) | fine; switches at its next start |
| Neovim 0.12 (LazyVim) | its own swiss scheme, follows the mode file | fine; its `:terminal` palette takes the new white |
| Zed | its own theme | terminal white updated (not rendered) |
| Claude Code 2.1.296 | theme `auto` (truecolour) | picks light / dark correctly; quiet text readable in both |
| tmux, delta, yazi | — | tmux and delta are not installed; yazi was not exercised |

## F. Switching and NixOS

- **How it switches.** `swiss-mode` (Super+Shift+T) writes the mode file, the `build/current` link and dconf
  `color-scheme`. xdg-desktop-portal-gtk (portals.conf `default=gtk`) publishes that to kitty, which loads
  `light-` / `dark-theme.auto.conf` (links into `build/`).
- **No preference** falls back to dark.
- **What the rig verified**, with the stand-in portal:
  - open kitty windows switch live;
  - fish's variable flips light → dark → light, and the theme follows;
  - lazygit's selected line follows.
- **Persistence.** dconf keeps the mode, and kitty reads the portal at start.
- **Config reload.** Ctrl+Shift+F5 re-reads the theme files: verified, colour 7 updated in an open window.
- **Not managed by Nix.** The configs are user files, so no Home Manager files were involved and no theme kitten
  wrote anything.

## G. Before and after

Measured, in the rig, over the live poster:
- Light ground in an unfocused window: L* 66-76 → 91-93.
- Dark ground: L* 2-14 → 3-5.
- Worst-case quiet text: 3.25:1 → 4.55:1 (light) and 4.0:1 → 4.95:1 (dark).
- Pairs, faint text and selection: as in tables B-D.

Judged by eye (subjective): the light page now reads as paper rather than frosted grey, the poster is a faint hint,
and the fzf and lazygit selections look like the rest of the desktop.

## H. Files

| File | Change |
|---|---|
| `tokens/light.env` | `ansi7` E6E6E1 (commit 2f02524), so `build/light/kitty-theme.conf`, `build/nvim-swiss.lua`, `build/zed-theme.json` |
| `templates/both/fish-swiss.theme` → `build/` ← `~/.config/fish/themes/swiss.theme` | new |
| `templates/both/lazygit-config.yml` → `build/` ← `~/.config/lazygit/config.yml` | new |
| `tests/contrast.sh`, `tests/lint.sh` | per-mode text-on-colour pairs; new links |
| `README.md` | Terminal colours section, mode table (2f02524), translucency (af1cc0b) |
| `~/.config/kitty/kitty.conf` | `dim_opacity 0.7`, `background_opacity 0.94`, tab comment corrected |
| `~/.config/mango/rule.conf` | kitty solid when unfocused (mango bf33c2b) |
| `~/.config/fish/config.fish` | `fish_config theme choose swiss`, `FZF_DEFAULT_OPTS` |
| `~/.config/starship.toml`, `~/.config/fastfetch/config.jsonc` | white → bright-black / 90 |

Nothing was removed. The owner's uncommitted wallpaper edits in `tokens/` and `build/` were left as they were.

## I. Not verified or left open

- **The live screen** was never captured; the rig used mango's gles2 renderer headless, not the NVIDIA output.
- **The live portal path** after these changes was not exercised: toggling would have changed the owner's desktop.
- **Open kitty windows** keep 80 % until reopened. Ctrl+Shift+F5 applies the palette and faint text.
- **Program gaps:** yazi, Zed's terminal and Doom Emacs' vterm were not rendered.
- **Remaining limits:** the Dark Mode white-on-colour and Light Mode black-on-colour limits (B, C), and ls `ow`
  (blue on green, both modes).
- **Reddit:** no community evidence was gathered (not reachable from the research tools); the kitty issues cited came
  from GitHub.

## J. Undo

Originals are in `backups/kitty-audit-20261018/`, with SHA256SUMS. Commit or stash any uncommitted token edits
first (git will not revert over them), then undo the repos and copy the user files back:

```
git -C ~/.config/swiss-desktop revert af1cc0b 2f02524 && ~/.config/swiss-desktop/bin/swiss-build
git -C ~/.config/mango revert bf33c2b && mmsg dispatch reload_config
cd ~/.config/swiss-desktop/backups/kitty-audit-20261018
cp kitty.conf ~/.config/kitty/kitty.conf; cp config.fish ~/.config/fish/config.fish
cp starship.toml ~/.config/starship.toml; cp fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
rm ~/.config/fish/themes/swiss.theme ~/.config/lazygit/config.yml
```

Then open new kitty windows.
