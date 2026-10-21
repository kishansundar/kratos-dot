pragma Singleton
import QtQuick
import Quickshell
import qs
import Quickshell.Io

// Small preferences that survive a restart, stored as JSON in ~/.local/state/swiss/shell.json, written only when a
// value changes:
//   dnd, dndHold, dndUntil      do not disturb; how long the dashboard holds it ("30m" "1h" "2h" "off" = until
//                               switched off) and when it ends (ms since the epoch, 0 = no end)
//   caffeineHold                how long keep awake holds when switched on (the same choices)
//   nightOn, nightTemp, nightSchedule   night light: on, its temperature (K), sunset -> sunrise instead of always
//   tailscaleDns                use Tailscale's DNS when Tailscale is brought up (off: the system's resolver answers)
//   pinned                      the tray items pinned to the bar (their ids)
//   clocks                      the date and time panel's world clocks: zone names ("UTC", "Europe/Berlin"), at most
//                               Theme.panel.clocksMax; add one by editing this file, remove one with a right click
//   recent                      the launcher's apps, the last opened first (desktop ids): an empty query shows the
//                               first Theme.launcher.recentCount, and ties in a search go to the more recent
//   dockPinned                  the dock's pinned apps (desktop ids), in their order
//   wallFavourites              the wallpaper picker's favourite pictures (absolute paths; F in the picker)
//   wallLayout                  the wallpaper picker's arrangement: "slices" or "wall" (M in the picker)
//
// The file is the owner's as much as the shell's (clocks are added by hand), so nothing in it is lost to a save:
// - It is watched: a hand edit is read at once, so the next save carries it instead of writing over it (the shell's
//   own writes coming back through the watch are recognised and skipped).
// - A file that is not valid JSON is never written over. Changes then stay in memory, the shell says so once in a
//   notification, and saving starts again as soon as the file reads cleanly (an editor's half-written file reads
//   again on its next write, and once more 200 ms after a failure).
// - A key the shell does not know, or a known key whose value has the wrong type, is written back as it was found;
//   a wrong value gives way only when that setting is changed from the shell.
// - Nothing is saved before the file has been read (a change made earlier is kept and saved after it), and a change
//   made while the file is broken is saved once it reads again. The file is written whole through a rename, so a
//   crash mid-write leaves the old one.
Singleton {
    id: root

    property bool dnd: false
    property string dndHold: "off"
    property real dndUntil: 0
    property string caffeineHold: "off"
    property bool nightOn: false
    property int nightTemp: Theme.control.nightTempDefault
    property bool nightSchedule: false
    property bool tailscaleDns: false
    property var pinned: []
    property var clocks: ["UTC"]
    property var recent: []
    // The dock's pinned apps (desktop ids), in order. Seeded with the owner's most used apps (the launcher's recent
    // list and the two always open); pin, unpin and reorder from the dock (right click, drag).
    property var dockPinned: ["kitty", "zen", "helium", "org.gnome.Nautilus", "yazi", "spotify"]
    property var wallFavourites: []
    property string wallLayout: "slices"

    readonly property var keys: ["dnd", "dndHold", "dndUntil", "caffeineHold", "nightOn", "nightTemp", "nightSchedule",
                                 "tailscaleDns", "pinned", "clocks", "recent", "dockPinned", "wallFavourites", "wallLayout"]

    function set(key, value) {
        if (JSON.stringify(root[key]) === JSON.stringify(value)) return;
        root[key] = value;
        changed[key] = true;
        save();
    }
    function togglePin(id) { set("pinned", pinned.includes(id) ? pinned.filter(p => p !== id) : pinned.concat([id])) }
    function opened(id) { set("recent", [id].concat(recent.filter(r => r !== id))) }
    function toggleWallFavourite(path) { set("wallFavourites", wallFavourites.includes(path) ? wallFavourites.filter(p => p !== path) : wallFavourites.concat([path])) }
    function toggleDockPin(id) { set("dockPinned", dockPinned.includes(id) ? dockPinned.filter(p => p !== id) : dockPinned.concat([id])) }
    // Move a pinned app to position `to` (dragged in the dock).
    function moveDockPin(id, to) { const l = dockPinned.filter(p => p !== id); l.splice(Math.max(0, Math.min(to, l.length)), 0, id); set("dockPinned", l) }
    property var found: ({})        // the file as last read: every key, known or not, valid or not
    property var changed: ({})      // keys set from the shell and not saved yet; they win over the file
    property var ownWrites: []      // the last texts this shell wrote: their echo through the watch is not a hand edit
    property bool ready: false      // the file has been read (or there is none yet)
    property bool broken: false     // the file is not valid JSON: never written over
    property bool warned: false
    property bool retried: false    // one more read 200 ms after a failure, not a poll

    function save() {
        if (!ready) return;          // the first read saves what was changed before it
        if (broken) { console.warn("Prefs: shell.json is not valid JSON; not saving over it"); return; }
        const o = Object.assign({}, found);
        for (const k of keys) if (valid(k, found[k]) || changed[k]) o[k] = root[k];
        const text = JSON.stringify(o, null, 2) + "\n";
        ownWrites = ownWrites.slice(-3).concat([text]);
        found = o;
        changed = ({});
        file.setText(text);
    }
    // A known key only with the type of its default; a missing one counts as valid (its value is written).
    function valid(k, v) {
        if (v === undefined) return true;
        const d = root[k];
        return Array.isArray(d) ? Array.isArray(v) && v.every(x => typeof x === "string") : typeof v === typeof d;
    }
    function read(text) {
        if (ownWrites.includes(text)) return;
        let s;
        try {
            s = JSON.parse(text);
            if (s === null || typeof s !== "object" || Array.isArray(s)) throw new Error("not an object");
        } catch (e) {
            broken = true;
            if (!retried) { retried = true; retry.restart(); }
            if (!warned) {
                warned = true;
                console.warn("Prefs: shell.json is not valid JSON; keeping it, changes stay in memory until it is fixed");
                Quickshell.execDetached(["busctl", "--user", "--", "call", "org.freedesktop.Notifications",
                    "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "Notify", "susssasa{sv}i",
                    "Shell", "0", "", "Settings file unreadable",
                    "~/.local/state/swiss/shell.json is not valid JSON. It is kept as it is; changes stay in memory until it reads again.",
                    "0", "0", "-1"]);
            }
            return;
        }
        retry.stop();
        retried = false;
        broken = false;
        warned = false;
        found = s;
        for (const k of keys)
            if (!changed[k] && s[k] !== undefined && valid(k, s[k])) root[k] = s[k];
        const first = !ready;
        ready = true;
        // Save what changed while the file could not be read, and on the first read a missing key's default.
        if (Object.keys(changed).length > 0 || (first && keys.some(k => s[k] === undefined))) save();
    }

    // A half-written file (an editor's) is read once more 200 ms later; its next write triggers a read too.
    Timer { id: retry; interval: 200; onTriggered: file.reload() }

    FileView {
        id: file
        path: Theme.stateDir + "/shell.json"
        watchChanges: true
        atomicWrites: true
        onFileChanged: { root.retried = false; reload(); }
        // First start: write the defaults so the file exists. Any other failure (permissions, a folder in its
        // place) leaves it alone and saves nothing.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) { root.ready = true; root.save(); }
            else console.warn("Prefs: cannot read shell.json, error", error);
        }
        onLoaded: root.read(text())
    }
}
