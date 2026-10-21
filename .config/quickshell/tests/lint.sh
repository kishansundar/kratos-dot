#!/bin/sh
# Lint the shell's QML with qmllint, with Quickshell's own types and the qs.* modules resolved (Caelestia's CI does
# the same). Quickshell writes the import paths and a build folder for its modules into a .qmlls.ini it finds in the
# config's folder, so this copies the shell to a scratch root, starts Quickshell there off screen on an empty
# ShellRoot (no services, no bus: nothing is shown or registered) just long enough for that file, and lints the copy.
#   sh tests/lint.sh [--all] [file.qml ...]      (files relative to the shell's folder; default: every QML file)
# By default only what has proved real here is reported; --all prints everything qmllint says. Left out as noise
# (checked 20 October 2026, qmllint 6.12.0, Quickshell 0.3.2):
#   unqualified            ids of outer components used in delegates (no `pragma ComponentBehavior: Bound` here)
#   missing-property       on "QObject" (Theme's grouped tokens are QtObjects) and on the shell's own singletons and
#                          components (Prefs, Mango, Bt, Panels, Glyphs, Tip: qmllint does not read their members)
#                          and through `parent.` (a delegate reading its slot's properties)
#   unresolved-type, missing-type, uncreatable-type, signal-handler-parameters, import, unused-imports,
#   unresolved-alias, incompatible-type "... to QObject" / "QVariantMap to QVariantHash" (a Process's environment
#   from a JS object), required (delegates' modelData): Quickshell types its
#                          qmltypes do not describe fully, and inline components / Repeater delegates qmllint misreads
#   property-override of `enabled`: the controls keep their own enabled (TextButton, Switch, ...), on purpose
#   confusing-expression-statement (new in 6.12): a bare read such as `DesktopEntries.applications.values;` in a
#                          binding, there on purpose so the binding runs again when that value changes
#   missing-property on Quickshell's window types that 6.12's qmltypes leave out: a PanelWindow's `anchors` (top,
#                          right, ...), a PopupWindow's `anchor` (window, edges, gravity, adjustment, rect,
#                          updateAnchor), QuickshellScreenInfo.name, UntypedObjectModel.values; and a member "not found on
#                          type" with no type named (qmllint could not tell the type, e.g. through an alias)
# What is left: syntax errors, a member that shadows one of its base type (a function `move` on a Column hides the
# positioner's move transition; a property `clip` or `state`), an id that shadows a property (id-shadows-member),
# duplicate bindings, read-only assignments, and the like. Also checked: every popover PanelHost loads by name (its
# `files` map) has its file in panels/, since nothing else would notice a typo there before the popover is opened.
# Exit 1 if anything is reported.
dir=$(dirname "$(readlink -f "$0")")/..
lint=$(nix-store -qR "$(readlink -f "$(command -v quickshell)")" 2>/dev/null | grep -E -- '-qtdeclarative-6[^/]*$' | head -1)/bin/qmllint
[ -x "$lint" ] || { echo "lint: no qmllint in Quickshell's qtdeclarative ($lint)"; exit 2; }
all=0; [ "$1" = --all ] && { all=1; shift; }
root=$(mktemp -d)
trap 'kill "$pid" 2>/dev/null; rm -rf "$root"' EXIT
mkdir -p "$root/cfg" "$root/run" && chmod 700 "$root/run"
(cd "$dir" && tar --exclude=./.git --exclude=./design --exclude=./.claude -cf - .) | tar -xf - -C "$root/cfg"
mv "$root/cfg/shell.qml" "$root/cfg/main-shell.qml"
printf 'import Quickshell\nShellRoot {}\n' > "$root/cfg/shell.qml"
: > "$root/cfg/.qmlls.ini"
env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$root/run" DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent \
    quickshell --no-duplicate -p "$root/cfg/shell.qml" > "$root/qs.log" 2>&1 &
pid=$!
i=0
while [ $i -lt 100 ] && ! grep -q '^buildDir=' "$root/cfg/.qmlls.ini"; do sleep 0.1; i=$((i + 1)); done
grep -q '^buildDir=' "$root/cfg/.qmlls.ini" || { echo "lint: Quickshell wrote no .qmlls.ini"; cat "$root/qs.log"; exit 2; }
build=$(sed -n 's/^buildDir="\(.*\)"$/\1/p' "$root/cfg/.qmlls.ini")
set --  "$@"
cd "$root/cfg"
if [ $# -eq 0 ]; then set -- $(find . -name '*.qml' -not -name shell.qml | sort); else
    set -- $(for f in "$@"; do [ "$f" = shell.qml ] && echo main-shell.qml || echo "$f"; done); fi
imports=$(sed -n 's/^importPaths="\(.*\)"$/\1/p' .qmlls.ini | tr ':' '\n' | sed 's/^/-I\n/')
"$lint" $imports -I "$build" --json "$root/out.json" "$@" > /dev/null 2>&1
python3 -I - "$root/out.json" "$all" <<'PY'
import json, sys
data = json.load(open(sys.argv[1])); show_all = sys.argv[2] == "1"
noise_ids = {"unqualified", "unresolved-type", "missing-type", "uncreatable-type", "signal-handler-parameters",
             "import", "unused-imports", "unresolved-alias", "required", "confusing-expression-statement"}
own = ('"QObject"', '"Prefs"', '"Mango"', '"Bt"', '"Panels"', '"Glyphs"', '"Tip"',
       '"PopupAnchor"', '"QuickshellScreenInfo"', '"UntypedObjectModel"')
window_members = ('"top"', '"right"', '"bottom"', '"left"', '"window"', '"edges"', '"gravity"', '"adjustment"')
def line_of(name, n):
    try: return open(name).read().split("\n")[n - 1]
    except Exception: return ""
found = 0
for f in data.get("files", []):
    name = f["filename"].removeprefix("./").replace("main-shell.qml", "shell.qml")
    for w in f.get("warnings", []):
        kind, msg = w.get("id") or w.get("type", ""), w.get("message", "")
        if not show_all:
            if kind in noise_ids: continue
            if kind == "missing-property" and any(f"on type {t}" in msg for t in own): continue
            if kind == "missing-property" and "parent." in line_of(f["filename"], w.get("line")): continue
            if kind == "missing-property" and msg.startswith("Could not find property") and msg.rstrip(".").endswith(window_members): continue
            if kind == "missing-property" and msg.rstrip(".").endswith("on type"): continue   # a type qmllint could not tell
            if kind == "incompatible-type" and (msg.endswith("to QObject") or msg.endswith("QVariantMap to QVariantHash")): continue
            if kind == "property-override" and 'member "enabled"' in msg: continue
        found += 1
        print(f"{name}:{w.get('line', '?')}:{w.get('column', '?')}: {kind}: {msg}")
    if not f.get("success", True) and not f.get("warnings"):
        found += 1; print(f"{name}: qmllint could not read it")
print(f"lint: {found} finding(s)" if found else "lint: clean")
sys.exit(1 if found else 0)
PY
status=$?
# The popovers PanelHost loads by name ("../panels/" + files[name] + ".qml"): each must exist.
for f in $(sed -n '/property var files:/,/})/p' "$dir/overlays/PanelHost.qml" | grep -o '"[A-Za-z]*"' | tr -d '"'); do
    [ -f "$dir/panels/$f.qml" ] || { echo "overlays/PanelHost.qml: files names $f, but there is no panels/$f.qml"; status=1; }
done
exit $status
