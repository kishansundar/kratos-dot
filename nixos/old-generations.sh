#!/bin/sh
# The old generations of every Nix profile (the system's, root's channels): all but a profile's newest 3 (the boot
# menu's three), however young, and never the current one (after a rollback it is kept as well). "old-generations"
# lists them; "old-generations go" removes them, and the next nix-collect-garbage frees their store paths. Run by the
# weekly nix-gc job (modules/maintenance.nix) and sysclean.
go=${1:-}
[ -z "$go" ] || [ "$go" = "go" ] || { echo "usage: old-generations [go]"; exit 1; }

# A profile is a link to one of its own generations (system -> system-51-link), in the folders nix-collect-garbage cleans.
find /nix/var/nix/profiles /root/.local/state/nix/profiles -type l -lname '*-[0-9]*-link' 2>/dev/null | while read -r profile; do
    current=$(readlink "$profile" | sed 's/.*-\([0-9]*\)-link$/\1/')
    # Generation numbers, newest first.
    gens=$(for link in "$profile"-*-link; do
        n=${link#"$profile"-}; n=${n%-link}
        case $n in ''|*[!0-9]*) continue;; esac
        echo "$n"
    done | sort -rn)
    third=$(echo "$gens" | sed -n 3p)
    [ -n "$third" ] || continue
    old=$(echo "$gens" | awk -v k="$third" -v cur="$current" '$1 < k && $1 != cur { print $1 }' | sort -n | tr '\n' ' ')
    [ -n "$old" ] || continue
    # shellcheck disable=SC2086 # one argument per generation
    if [ "$go" ]; then nix-env -p "$profile" --delete-generations $old; else echo "$profile: would remove $old"; fi
done
