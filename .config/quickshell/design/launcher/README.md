The app launcher for the Quickshell Swiss desktop shell, as its own system. It covers only the launcher: opening, the query, matching, the result list and its keys. It uses Quickshell Swiss's tokens unchanged (Geist, Swiss Glyphs, light and dark, the 8px grid, the ruler, the ink marks) and adds only launcher geometry and matching rules.

## What was wrong with the old one

- **It didn't filter.** "f" listed all 14 apps (kitty, btop++, Piper…), so the list read as random.
- **The highlight sat on row 2** while row 1 was the best match. Enter must open the best match.
- **Full-colour app icons** in a dozen styles fought each other and the ink of the shell.
- **Noise:** a 1–9 column on every row, bold first letters, descriptions on some rows only.

## Principles

1. **Hung from the bar.** Super (or a click on the NixOS mark) opens it flush under the bar rule, left-aligned with the mark. Never centred, never floating.
2. **Only real matches, best first.** Ranking: name starts with the query › a word in the name starts with it › initials ("fm" → Yazi **F**ile **M**anager) › anywhere in the name › generic name or keywords. One letter matches only name and word starts (`fuzzyMin` 2). Ties: recently opened first, then alphabetical.
3. **The first row is selected.** Enter always opens the top result. ↑↓ (and Ctrl+N / Ctrl+P) move the selection; the mouse moves it too.
4. **Words over pictures.** The name carries the row. Icons are the app's own, tinted to `text` at 16px (as in the tray row), so their shapes help but their colours don't shout.
5. **Matched letters are underlined** with a 2px ink line, not bolded, so the name keeps one weight.
6. **The ruler measures the result.** The query sits on a ruler the width of the launcher; its ink fill is the share of your apps that still match (3 of 41 ≈ 7 %). Typing narrows the fill.

## Layout

`launcherWidth` 576, `surface`, 1px `line` border, no top border (it hangs from the bar rule), radius 0.

| Part | Size | Notes |
|---|---|---|
| Query | `fieldH` 56 | search glyph, query in `h2`, ink caret 2px; "3 of 41" in mono at the right |
| Ruler | `tickMajor` 8 | full width inside `s5` margins, ticks every `rulerPitch`, ink fill = matches ÷ apps |
| Results | `rowH` 40 × up to `maxRows` 8 | then the list scrolls |
| Footer | 1px rule above | "↑↓ select · ↵ open · hold alt for numbers · esc close", mono `textFaint` |

Row: number slot (hidden) · 16px tinted icon · name (`body` 500) · generic name (`body` `textMuted`, from the desktop file's GenericName, else nothing) · "open ↵" in mono at the right of the selected row only.

## States

- **Empty query:** "RECENT" eyebrow and the last `recentCount` (6) apps opened, first selected. The count says "41 apps".
- **Typing:** matches only, best first, first selected; count "3 of 41".
- **Alt held** (`altReveal` 250 ms): row numbers 1–9 appear in `textFaint`; Alt+n opens row n. A quick Alt+n works without waiting.
- **No match:** "No app matches “qzx”." in `textMuted`; ruler without fill; Enter does nothing.

## Colour

Swiss's tokens, nothing added: `surface`, `line`, `text` for names, underlines, caret and ruler fill, `textMuted` for generic names and the count, `textFaint` for placeholder, numbers and footer, `surfaceAlt` for the selected row. No `accent` in the launcher.

## Behaviour

- Opens with the query empty and focused; Esc or a click outside closes; opening an app closes it.
- Opening: opacity + 8px slide over `durMed`; instant under reduceMotion.
- Index from the XDG desktop entries (`DesktopEntries` in Quickshell); hide entries with `NoDisplay=true` or `Hidden=true`; refresh when a desktop file changes, not on every open.
- Recents: stored in the shell's state file, most recent first.
- Previews use a plain square where each app's tinted icon goes.

## Relationship to the other systems

The launcher only. The bar, panels and everything else stay as their systems specify.
