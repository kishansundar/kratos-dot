#!/bin/sh
# Run the shell's tests in Quickshell's own JavaScript engine, off screen (no display needed, nothing shown).
# Each tests/*Test.qml is a Scope that logs its checks and ends with a line "PASS" or "FAIL: n". Quickshell refuses
# imports from outside the config's folder, so each runs in a scratch root (services/, tests/ and a shell.qml holding
# the test) with its own runtime folder, so no `qs ipc` reaches it; Qt.quit() does nothing in Quickshell, so the
# runner stops it, by its pid, once that last line is out.
dir=$(dirname "$(readlink -f "$0")")
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
cp -r "$dir/../services" "$dir" "$root/"
mkdir -m 700 "$root/run"
status=0
for t in "$dir"/*Test.qml; do
    name=$(basename "$t" .qml)
    echo "== $name"
    printf 'import Quickshell\nimport qs.tests\nShellRoot { %s {} }\n' "$name" > "$root/shell.qml"
    log="$root/$name.log"
    env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$root/run" \
        quickshell --no-duplicate -p "$root/shell.qml" > "$log" 2>&1 &
    pid=$!
    i=0
    while [ $i -lt 200 ] && ! grep -qE ': (PASS|FAIL: [0-9]+)$' "$log"; do sleep 0.1; i=$((i + 1)); done
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    sed 's/\x1b\[[0-9;]*m//g' "$log" | sed -n '/ qml: /,$p' | grep -v '^ *INFO: ' | sed 's/^ *[A-Z]* qml: //'
    sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^ *(ERROR|WARN)' | grep -v ' qml: ' | head -5
    grep -qE ': PASS$' "$log" || { [ $i -ge 200 ] && echo "no result in 20 s"; status=1; }
done
exit $status
