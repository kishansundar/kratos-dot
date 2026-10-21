# Dock

The whole dock on an empty workspace: the NixOS mark (launcher), pinned apps, running-only apps; centred, hung from the bottom edge.

**Consumer provides:** the pinned list, desktop entries with their icons, toplevels with their tags, and the focused tag's window count (from mango).

- Groups in order: NixOS · pinned · running-but-not-pinned, split by 1px `line` rules.
- `surface`, 1px `line` border on three sides, none at the bottom. Icons are the apps' own, full colour, 48px.
- The preview's coloured tiles are placeholders for each app's real icon.
