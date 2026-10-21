# Launcher

The whole launcher: query on a ruler, matching results, footer. Opens flush under the bar rule, left-aligned with the NixOS mark, `launcherWidth` 576.

**Consumer provides:** the desktop entries (name, generic name, keywords, icon, exec, NoDisplay), the recent list, and a launch action.

- First row always selected; Enter opens it.
- Ranking and highlighting: see the README's Principles.
- Esc, click outside or launching closes it.
