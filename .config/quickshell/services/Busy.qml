pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import "Format.js" as Format

// What the focused kitty window is doing, for the mark after "kitty" in the bar's title (components/BusyMark): the
// owner's busy-indicator package (16 October 2026), its BusyStore, ported. Fed through `qs ipc call busy ...`
// by ~/.config/kitty/busy_watcher.py (commands, kitty's own focus, closes) and by Claude Code's hooks in
// ~/.claude/settings.json. A window is "<kitty pid>:<window id>" ($KITTY_PID:$KITTY_WINDOW_ID: kitty sets both for
// everything inside, hooks inherit them): every kitty started from Super+Return is its own process, each numbering its
// windows from 1, so the package's bare window id mixed one terminal's marks into another's.
//   status        "idle" | "working" | "needs" | "done" | "failed"     for the focused kitty window
//   detail        the tooltip: "nixos-rebuild switch · 1:12", "cargo build · exit 101", "Claude · needs you"
// And any app just started, from the launcher or the dock (Busy.start(entry), which starts it through scripts/launch)
// or a keybind (scripts/busy-launch):
//   launching     true while it has no window yet (from launchShowAfter to launchTimeout)
//   launchId      for the app id's place ("zen"); launchName the entry's name ("Zen Browser")
//   launchDetail  the tooltip: "Zen Browser · starting · 0:03"
// A launch ends when a matching window opens (ToplevelManager.toplevels), or one takes the focus (single-window apps
// raise instead of opening), or scripts/launch says it quit with an error (its notification says why); by
// launchTimeout it goes quietly, since a slow app and a tray app look like a failed one.
// Rules (README "States"): a command shows only past showAfter; Ctrl-C (130) leaves no mark; done and failed hold
// their time only once you can see them (kitty focused, and that kitty window), so a build that ends while you are in
// the browser keeps its mark until you come back; Claude outranks the shell in the same window.
// Departures: the pid in the key, and the kitty in front known from its window's pid; the focus comes from mango (the
// focused monitor's active client, as the bar's title reads it), not ToplevelManager.activeToplevel, and counts only
// when the window changes (not its title); "done in" rounds to the second; a window id is also matched as the bar
// shows it (".piper-wrapped" is piper).
Singleton {
    id: root

    // ---- Inputs -----------------------------------------------------------------------------------------------
    readonly property var activeClient: { const m = Mango.monitor(Mango.focused); return m ? m.active_client : null }
    readonly property bool kittyActive: !!activeClient && activeClient.appid === "kitty"
    property string focused: ""           // the kitty window ("pid:id") that last said it has the focus
    // The kitty process in front, from mango (its window's pid; mango's list is read again at each focus change to
    // kitty). Every terminal being its own process, this says which one has the focus even without its watcher's word:
    // a kitty opened before the watcher line, or a shell restarted since.
    readonly property int activePid: {
        if (!root.kittyActive) return 0;
        const c = Mango.clients.find(x => x.id === root.activeClient.id);
        return c ? c.pid : 0;
    }
    // The kitty window in front: the watcher's word when it is about this process (it tells a tab or split apart),
    // else the process's one window that has said anything.
    readonly property string current: {
        root.keysRev;
        if (root.activePid <= 0) return root.focused;
        const pid = String(root.activePid);
        if (root.focused.split(":")[0] === pid) return root.focused;
        const keys = Object.keys(root.wins).filter(k => k.split(":")[0] === pid);
        return keys.length === 1 ? keys[0] : "";
    }

    // ---- Outputs ----------------------------------------------------------------------------------------------
    readonly property string status: { root.rev; root.now; return root.resolve().st; }
    readonly property string detail: { root.rev; root.now; return root.resolve().text; }
    readonly property var currentLaunch: { root.rev; root.now; return root.pickLaunch(); }
    readonly property bool launching: root.currentLaunch !== null
    readonly property string launchId: root.currentLaunch ? root.currentLaunch.id : ""
    readonly property string launchName: root.currentLaunch ? root.currentLaunch.name : ""
    readonly property string launchDetail: root.currentLaunch
        ? root.currentLaunch.name + " · starting · " + Format.mmss((root.now - root.currentLaunch.t0) / 1000) : ""

    // ---- State ------------------------------------------------------------------------------------------------
    property var wins: ({})               // "pid:id" -> { cmd: entry | null, claude: entry | null }
    property var launches: []             // { id, name, match: [lowercase ids], t0, wasActive }
    property var lastClientId: null       // mango's focused window, to tell a focus change from a title change
    property int rev: 0
    property int keysRev: 0               // windows added or dropped (current follows these, not every state change)
    property real now: Date.now()

    onCurrentChanged: root.touch(root.current)
    onKittyActiveChanged: root.touch(root.current)
    onActiveClientChanged: {
        const c = root.activeClient;
        const id = c && c.id != null ? c.id : null;          // null: nothing focused (an empty tag)
        if (id === root.lastClientId) return;
        root.lastClientId = id;
        if (id === null) return;
        // its pid, for activePid: read once per window (a pid never changes), not on every focus
        if (c.appid === "kitty" && !Mango.clients.some(w => w.id === id)) Mango.refreshClients();
        root.windowOpened(c.appid, true);
    }
    // A launched app counts as open when a matching window appears (its app id may come a moment later).
    Connections {
        target: ToplevelManager.toplevels
        function onObjectInsertedPost(object, index) {
            if (object.appId !== "") root.windowOpened(object.appId, false);
            else object.appIdChanged.connect(() => root.windowOpened(object.appId, false));
        }
    }

    // Runs only while something depends on the time (a command running, a hold counting down).
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

    IpcHandler {
        target: "busy"
        // qs ipc call busy cmd <win> start|end <exit code or ?> <command line>
        function cmd(win: string, phase: string, code: string, text: string): void { root.setCmd(win, phase, code, text); }
        // qs ipc call busy claude <win> working|needs|done|failed|clear
        function claude(win: string, st: string): void { root.setClaude(win, st); }
        // qs ipc call busy focus <win>
        function focus(win: string): void { root.focused = win; }
        // qs ipc call busy drop <win>
        function drop(win: string): void { delete root.wins[win]; root.keysRev++; root.touch(win); }
        // qs ipc call busy launch <app id> <name>     (scripts/busy-launch, for keybinds). Given only the id (name ==
        // id), its desktop entry gives the name and the other ids its window may carry.
        function launch(id: string, name: string): void {
            const e = name === id ? DesktopEntries.heuristicLookup(id) : null;
            if (e) root.launchApp(id, e.name || id, [id, e.id, e.startupClass]);
            else root.launchApp(id, name, [id]);
        }
        // qs ipc call busy launchFailed <app id>     (scripts/launch: it quit with an error before a window opened)
        function launchFailed(id: string): void { root.launches = root.launches.filter(l => l.id !== id); root.touch(""); }
        // qs ipc call busy dump      every window's state and the pending launches, for checking the feeds
        function dump(): string {
            return JSON.stringify({ current: root.current, focused: root.focused, activePid: root.activePid,
                                    wins: root.wins, launches: root.launches });
        }
        // qs ipc call busy get
        function get(): string {
            if (root.launching) return "launching · " + root.launchDetail;
            return root.status + (root.detail !== "" ? " · " + root.detail : "");
        }
    }

    function slot(win) {
        if (!root.wins[win]) { root.wins[win] = { cmd: null, claude: null }; root.keysRev++; }
        return root.wins[win];
    }

    function setCmd(win, phase, code, text) {
        const w = root.slot(win);
        const t = Date.now();
        if (phase === "start") {
            w.cmd = { src: "cmd", st: "working", t0: t, seen: 0, text: text, code: 0, ran: 0 };
            clock.restart();              // the ticks line up with this start, so showAfter means showAfter
        } else {
            const prev = w.cmd;
            const ran = prev && prev.st === "working" ? t - prev.t0 : 0;
            const n = parseInt(code, 10);
            // Short commands, Ctrl-C (130) and an unknown status leave no mark.
            if (ran < Theme.busy.showAfter || isNaN(n) || n === 130) w.cmd = null;
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
            // A turn keeps its start while it runs, so the tooltip's clock does not reset at a permission prompt.
            const keep = prev && (prev.st === "working" || prev.st === "needs") && (st === "working" || st === "needs");
            const t0 = keep ? prev.t0 : Date.now();
            w.claude = { src: "claude", st: st, t0: t0, seen: 0, text: "Claude", code: 0, ran: Date.now() - t0 };
        }
        root.touch(win);
    }

    function touch(win) {
        if (win === root.current && root.kittyActive) root.markSeen(win);
        root.now = Date.now();
        root.rev++;
        clock.running = root.timed();
    }

    // Done and failed start their hold only once you can see them.
    function markSeen(win) {
        const w = root.wins[win];
        if (!w) return;
        const t = Date.now();
        for (const e of [w.cmd, w.claude])
            if (e && (e.st === "done" || e.st === "failed") && e.seen === 0) e.seen = t;
    }

    function live(e) {
        if (!e) return "idle";
        if (e.st === "working") return (e.src === "claude" || root.now - e.t0 >= Theme.busy.showAfter) ? "working" : "idle";
        if (e.st === "done") return e.seen > 0 && root.now - e.seen > Theme.busy.doneHold ? "idle" : "done";
        if (e.st === "failed") return e.seen > 0 && root.now - e.seen > Theme.busy.failHold ? "idle" : "failed";
        return e.st;                      // "needs"
    }

    // Claude outranks the shell: while claude runs, its own hooks are the truth.
    function resolve() {
        const w = root.wins[root.current];
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
        if (st === "working") return (claude ? "Claude · working" : e.text) + " · " + Format.mmss((root.now - e.t0) / 1000);
        if (st === "needs") return "Claude · needs you";
        if (st === "done") return claude ? "Claude · done" : e.text + " · done in " + Format.mmss((e.ran + 500) / 1000);  // rounded
        return claude ? "Claude · stopped on an error" : e.text + " · exit " + e.code;
    }

    // ---- Launches ---------------------------------------------------------------------------------------------
    // The launcher's and the dock's one way to start an entry, or one of its desktop actions ("New Window"): a terminal
    // entry in kitty, in its Path= folder as execute() does for the others; through scripts/launch, so its output goes
    // to the journal under the launch's id and a start that fails says so. Then marked starting.
    function start(entry, action) {
        const id = root.launchKey(entry), dir = entry.workingDirectory || "";
        const cmd = (action || entry).command;
        const run = entry.runInTerminal ? ["kitty"].concat(dir ? ["--directory", dir] : [], ["-e"], cmd) : cmd;
        const command = [Quickshell.shellDir + "/scripts/launch", id, entry.name || id].concat(run);
        Quickshell.execDetached(dir ? { command: command, workingDirectory: dir } : command);
        root.launch(entry);
    }
    function commandName(entry) { return entry.command && entry.command.length > 0 ? String(entry.command[0]).split("/").pop() : "" }
    function launchKey(entry) { return String(entry.startupClass || entry.id || root.commandName(entry)).replace(/\.desktop$/, "") }

    // Right after an entry starts. A window matches by its app id (lowercase, or its last dot part) against the
    // entry's id, StartupWMClass, command's file name, or kitty for a terminal entry.
    function launch(entry) {
        const id = root.launchKey(entry);
        const ids = [entry.id, entry.startupClass, root.commandName(entry)];
        if (entry.runInTerminal) ids.push("kitty");
        root.launchApp(id, entry.name || id, ids);
    }

    function launchApp(id, name, ids) {
        const match = [];
        for (const raw of ids.concat([id])) {
            if (!raw) continue;
            const s = String(raw).toLowerCase().replace(/\.desktop$/, "");
            match.push(s, s.split(".").pop());     // org.gnome.Nautilus also matches nautilus
        }
        // The app already in front: its window taking the focus back as the launcher closes is not the new window.
        const was = root.activeClient ? String(root.activeClient.appid).toLowerCase() : "";
        const wasActive = was !== "" && (match.indexOf(was) >= 0 || match.indexOf(was.split(".").pop()) >= 0);
        // One pending launch per app: launching it again restarts its clock.
        root.launches = root.launches.filter(l => l.id !== id)
            .concat([{ id: id, name: name, match: match, t0: Date.now(), wasActive: wasActive }]);
        root.touch("");
        clock.restart();                          // the ticks line up with this launch
    }

    // viaFocus: an existing window took the focus (single-window apps raise instead of opening).
    function windowOpened(appId, viaFocus) {
        if (!appId || root.launches.length === 0) return;
        const a = String(appId).toLowerCase();
        // A Nix wrapper's id read as the bar shows it: Piper's window is ".piper-wrapped", its entry says piper.
        const n = a.replace(/^\./, "").replace(/-wrapped$/, "");
        const ids = [a, a.split(".").pop(), n, n.split(".").pop()];
        const t = Date.now();
        const opened = l => ids.some(i => l.match.indexOf(i) >= 0)
            && (!viaFocus || !l.wasActive || t - l.t0 >= Theme.busy.launchRefocus);
        const left = root.launches.filter(l => !opened(l));
        if (left.length !== root.launches.length) { root.launches = left; root.touch(""); }
    }

    // The newest launch that has waited long enough to show.
    function pickLaunch() {
        for (let i = root.launches.length - 1; i >= 0; i--) {
            const age = root.now - root.launches[i].t0;
            if (age >= Theme.busy.launchShowAfter && age < Theme.busy.launchTimeout) return root.launches[i];
        }
        return null;
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
        const left = root.launches.filter(l => root.now - l.t0 < Theme.busy.launchTimeout);
        if (left.length !== root.launches.length) { root.launches = left; changed = true; }
        if (changed) root.rev++;
    }
}
