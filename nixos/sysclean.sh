#!/bin/sh
# Cleans this machine: old NixOS generations, unused store paths, old logs, old trash, Zen's cache. "sysclean" only shows what it would do; "sysclean go" does it.
go=${1:-}
[ -z "$go" ] || [ "$go" = "go" ] || { echo "usage: sysclean [go]"; exit 1; }
used() { df -B1 --output=used / | tail -1 | tr -d ' '; }
before=$(used)

echo "== NixOS generations (the newest 3 stay, the boot menu's, and any from the last 14 days)"
nixos-rebuild list-generations
# The weekly nix-gc job's own rule (old-generations.sh), so "sysclean go" never removes more than it would.
if [ "$go" ]; then sudo @oldGenerations@ go
else old=$(@oldGenerations@); echo "${old:-nothing to remove}"; fi

echo "== Nix store: paths nothing uses any more (and the old generations above)"
if [ "$go" ]; then sudo nix-collect-garbage | tail -1
else echo "unused right now: $(nix-store --gc --print-dead 2>/dev/null | wc -l) paths (more once old generations are gone)"; fi

echo "== Development shells (kept on purpose; delete a folder below and run this again to free its tools)"
find "$HOME/Developer" -maxdepth 4 -type d -name .direnv 2>/dev/null | while read -r dir; do echo "last built $(stat -c %y "$dir" | cut -c1-10)  $dir"; done

echo "== Logs (two weeks stay)"
journalctl --disk-usage
[ "$go" ] && sudo journalctl --vacuum-time=2weeks 2>&1 | tail -1

echo "== Trash (the last 30 days stay)"
if [ "$go" ]; then trash-empty -f 30
else echo "would remove: $(trash-empty --dry-run 30 2>/dev/null | wc -l) items"; fi

echo "== Zen's cache ($(du -sh "$HOME/.cache/zen" 2>/dev/null | cut -f1); Zen fills it again as you browse)"
if pgrep -x .zen-wrapped > /dev/null || pgrep -x zen > /dev/null; then echo "skipped: Zen is open, close it first"
elif [ "$go" ]; then rm -rf -- "${HOME:?}/.cache/zen"
else echo "would remove it"; fi

echo "== Downloads: over 30 days old or over 200 MB (never removed here, look for yourself)"
find "$HOME/Downloads" -type f \( -mtime +30 -o -size +200M \) -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null | numfmt -d "$(printf '\t')" --field=1 --to=iec

if [ "$go" ]; then
    echo "== Freed: $(( (before - $(used)) / 1048576 )) MB"
else
    echo "== Nothing was changed. Run \"sysclean go\" to do it."
fi
