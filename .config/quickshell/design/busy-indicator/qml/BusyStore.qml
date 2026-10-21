pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Busy state for the title module.
//
// 1. kitty windows, fed by kitty/busy_watcher.py (commands, focus, close) and Claude Code hooks.
//      status        "idle" | "working" | "needs" | "done" | "failed"   (focused kitty window)
//      detail        tooltip, e.g. "nixos-rebuild switch · 1:12"
// 2. app launches, fed by the launcher and dock (BusyStore.launch(entry)) or bin/busy-launch.
//      launching     true while a launched app has no window yet (after 0.4 s, up to 15 s)
//      launchId      what goes in the app id slot, e.g. "zen"
//      launchName    the entry's name, e.g. "Zen Browser"
//      launchDetail  tooltip, e.g. "Zen Browser · starting · 0:03"
Singleton {
    id: root

    // ── tunables ──────────────────────────────────────────────────
    readonly property int showAfter: 800        // ms; shorter commands never show anything
    readonly property int doneHold: 3000        // ms; check mark stays this long once you have seen it
    readonly property int failHold: 8000        // ms; error mark stays this long once you have seen it
    readonly property int launchShowAfter: 400  // ms; apps that open faster never show anything
    readonly property int launchTimeout: 15000  // ms; give up quietly after this
    readonly property string terminalAppId: "kitty"   // runInTerminal entries open in this

    // ── inputs ────────────────────────────────────────────────────
    // A kitty toplevel has compositor focus. Match the appId your title module shows.
    readonly property bool kittyActive: ToplevelManager.activeToplevel !== null
        && ToplevelManager.activeToplevel.appId === root.terminalAppId
    // kitty window id (same as $KITTY_WINDOW_ID) that has focus inside kitty.
    property string focused: ""

    // ── outputs ───────────────────────────────────────────────────
    readonly property string status: { root.rev; root.now; return root.resolve().st; }
    readonly property string detail: { root.rev; root.now; return root.resolve().text; }

    readonly property var currentLaunch: { root.rev; root.now; return root.pickLaunch(); }
    readonly property bool launching: root.currentLaunch !== null
    readonly property string launchId: root.currentLaunch ? root.currentLaunch.id : ""
    readonly property string launchName: root.currentLaunch ? root.currentLaunch.name : ""
    readonly property string launchDetail: root.currentLaunch
        ? root.currentLaunch.name + " · starting · " + root.mmss(root.now - root.currentLaunch.t0) : ""

    // ── internals ─────────────────────────────────────────────────
    property var wins: ({})        // kitty window id → { cmd: entry|null, claude: entry|null }
    property var launches: []      // { id, name, match: [lowercase ids], t0 }
    property string lastActive: ""   // app id of the last focused window (layer shells like the launcher can blank it)
    property int rev: 0
    property real now: Date.now()

    onFocusedChanged: root.touch(root.focused)
    onKittyActiveChanged: root.touch(root.focused)

    Timer {
        id: clock
        interval: 200
        repeat: true
        onTriggered: {
            root.now = Date.now();
            root.prune();
            running = root.timed();
        }
    }

    // A launched app counts as open when a matching window appears, or an existing one takes focus.
    Connections {
        target: ToplevelManager.toplevels
        function onObjectInsertedPost(object, index) {
            if (object.appId !== "") root.windowOpened(object.appId, false);
            else object.appIdChanged.connect(() => root.windowOpened(object.appId, false));
        }
    }
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            const t = ToplevelManager.activeToplevel;
            if (t === null) return;
            root.windowOpened(t.appId, true);
            root.lastActive = t.appId;
        }
    }

    IpcHandler {
        target: "busy"
        // qs ipc call busy cmd <win> start|end <exit code or ?> <command line>
        function cmd(win: string, phase: string, code: string, text: string): void { root.setCmd(win, phase, code, text); }
        // qs ipc call busy claude <win> working|needs|done|failed|clear
        function claude(win: string, st: string): void { root.setClaude(win, st); }
        // qs ipc call busy focus <win>
        function focus(win: string): void { root.focused = win; }
        // qs ipc call busy drop <win>
        function drop(win: string): void { delete root.wins[win]; root.touch(win); }
        // qs ipc call busy launch <app id> <name>      (bin/busy-launch does this for keybinds)
        function launch(id: string, name: string): void { root.launchApp(id, name, [id]); }
        // qs ipc call busy get
        function get(): string {
            if (root.launching) return "launching · " + root.launchDetail;
            return root.status + (root.detail !== "" ? " · " + root.detail : "");
        }
    }

    // ── kitty ─────────────────────────────────────────────────────
    function slot(win) {
        if (!root.wins[win]) root.wins[win] = { cmd: null, claude: null };
        return root.wins[win];
    }

    function setCmd(win, phase, code, text) {
        const w = root.slot(win);
        const t = Date.now();
        if (phase === "start") {
            w.cmd = { src: "cmd", st: "working", t0: t, seen: 0, text: text, code: 0, ran: 0 };
            clock.restart();                  // ticks line up with this start, so 0.8 s means 0.8 s
        } else {
            const prev = w.cmd;
            const ran = prev && prev.st === "working" ? t - prev.t0 : 0;
            const n = parseInt(code, 10);
            // Short commands, Ctrl-C (130) and unknown status leave no mark.
            if (ran < root.showAfter || isNaN(n) || n === 130) w.cmd = null;
            else w.cmd = { src: "cmd", st: n === 0 ? "done" : "failed", t0: t, seen: 0, text: text, code: n, ran: ran };
        }
        root.touch(win);
    }

    function setClaude(win, st) {
        const w = root.slot(win);
        const prev = w.claude;
        if (st === "clear") {
            w.claude = null;
        } else {
            // Keep the turn's start time while it is still running, so the tooltip clock does not reset.
            const keep = prev && (prev.st === "working" || prev.st === "needs") && (st === "working" || st === "needs");
            const t0 = keep ? prev.t0 : Date.now();
            w.claude = { src: "claude", st: st, t0: t0, seen: 0, text: "Claude", code: 0, ran: Date.now() - t0 };
        }
        root.touch(win);
    }

    function touch(win) {
        if (win === root.focused && root.kittyActive) root.markSeen(win);
        root.now = Date.now();
        root.rev++;
        clock.running = root.timed();
    }

    // done and failed marks start their hold only once you can see them
    function markSeen(win) {
        const w = root.wins[win];
        if (!w) return;
        const t = Date.now();
        for (const e of [w.cmd, w.claude])
            if (e && (e.st === "done" || e.st === "failed") && e.seen === 0) e.seen = t;
    }

    function live(e) {
        if (!e) return "idle";
        if (e.st === "working") return (e.src === "claude" || root.now - e.t0 >= root.showAfter) ? "working" : "idle";
        if (e.st === "done") return e.seen > 0 && root.now - e.seen > root.doneHold ? "idle" : "done";
        if (e.st === "failed") return e.seen > 0 && root.now - e.seen > root.failHold ? "idle" : "failed";
        return e.st; // "needs"
    }

    // Claude outranks the shell: while claude runs, its own hooks are the truth.
    function resolve() {
        const w = root.wins[root.focused];
        if (w) {
            for (const e of [w.claude, w.cmd]) {
                const st = root.live(e);
                if (st !== "idle") return { st: st, text: root.describe(e, st) };
            }
        }
        return { st: "idle", text: "" };
    }

    function describe(e, st) {
        const claude = e.src === "claude";
        if (st === "working") return (claude ? "Claude · working" : e.text) + " · " + root.mmss(root.now - e.t0);
        if (st === "needs") return "Claude · needs you";
        if (st === "done") return claude ? "Claude · done" : e.text + " · done in " + root.mmss(e.ran);
        return claude ? "Claude · stopped on an error" : e.text + " · exit " + e.code;
    }

    // ── launches ──────────────────────────────────────────────────
    // Call right after entry.execute() in the launcher and the dock.
    function launch(entry) {
        const cmd = entry.command && entry.command.length > 0 ? String(entry.command[0]).split("/").pop() : "";
        const id = String(entry.startupClass || entry.id || cmd).replace(/\.desktop$/, "");
        const ids = [entry.id, entry.startupClass, cmd];
        if (entry.runInTerminal) ids.push(root.terminalAppId);
        root.launchApp(id, entry.name || id, ids);
    }

    function launchApp(id, name, ids) {
        const match = [];
        for (const raw of ids.concat([id])) {
            if (!raw) continue;
            const s = String(raw).toLowerCase().replace(/\.desktop$/, "");
            match.push(s, s.split(".").pop());     // org.gnome.Nautilus also matches nautilus
        }
        // If this app already had focus, its window taking focus back as the launcher closes is not the new window.
        const was = String(root.lastActive).toLowerCase();
        const wasActive = was !== "" && (match.indexOf(was) >= 0 || match.indexOf(was.split(".").pop()) >= 0);
        // One pending launch per app: launching it again restarts its clock.
        root.launches = root.launches.filter(l => l.id !== id)
            .concat([{ id: id, name: name, match: match, t0: Date.now(), wasActive: wasActive }]);
        root.touch("");
        clock.restart();                      // ticks line up with this launch
    }

    // viaFocus: an existing window took focus (single-window apps raise instead of opening).
    function windowOpened(appId, viaFocus) {
        if (!appId || root.launches.length === 0) return;
        const a = String(appId).toLowerCase();
        const last = a.split(".").pop();
        const t = Date.now();
        const opened = l => (l.match.indexOf(a) >= 0 || l.match.indexOf(last) >= 0)
            && (!viaFocus || !l.wasActive || t - l.t0 >= 500);
        const left = root.launches.filter(l => !opened(l));
        if (left.length !== root.launches.length) { root.launches = left; root.touch(""); }
    }

    // The most recent launch that has waited long enough to show.
    function pickLaunch() {
        for (let i = root.launches.length - 1; i >= 0; i--) {
            const age = root.now - root.launches[i].t0;
            if (age >= root.launchShowAfter && age < root.launchTimeout) return root.launches[i];
        }
        return null;
    }

    // ── clock ─────────────────────────────────────────────────────
    function mmss(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // Does anything still depend on the clock?
    function timed() {
        if (root.launches.length > 0) return true;
        for (const id in root.wins) {
            const w = root.wins[id];
            for (const e of [w.cmd, w.claude]) {
                if (!e) continue;
                if (e.st === "working") return true;
                if ((e.st === "done" || e.st === "failed") && e.seen > 0 && root.live(e) !== "idle") return true;
            }
        }
        return false;
    }

    // Forget marks whose hold has run out, and launches that never opened a window.
    function prune() {
        let changed = false;
        for (const id in root.wins) {
            const w = root.wins[id];
            for (const k of ["cmd", "claude"]) {
                const e = w[k];
                if (e && e.st !== "working" && e.st !== "needs" && root.live(e) === "idle") { w[k] = null; changed = true; }
            }
        }
        const left = root.launches.filter(l => root.now - l.t0 < root.launchTimeout);
        if (left.length !== root.launches.length) { root.launches = left; changed = true; }
        if (changed) root.rev++;
    }
}
