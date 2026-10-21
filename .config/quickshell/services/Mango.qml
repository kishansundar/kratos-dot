pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// mango's state for the bar: each monitor's tags, layout and focused window.
// One long-running `mmsg watch all-monitors` prints a JSON line whenever anything changes; nothing polls.
Singleton {
    id: root

    // monitor name -> { tag_num, layout_symbol, tags: [{ index, is_active, is_urgent, client_count }],
    // active_client: { title }, ... }
    property var monitors: ({})
    // The focused monitor's name (mango's "active" one), "" until mango has said.
    readonly property string focused: Object.keys(monitors).find(k => monitors[k].active) ?? ""

    function monitor(name) { return monitors[name] ?? null }
    function dispatch(args) { Quickshell.execDetached(["mmsg", "dispatch", args.join(",")]) }
    function view(tag) { dispatch(["view", tag, 0]) }

    // Decorations programs put in front of their window titles: spinners (◐ ◓ ⠋ …), status marks (✳ • ·),
    // arrows and box drawing. They are noise in the bar, and a spinner would make it redraw several times a second.
    function cleanTitle(t) {
        return (t ?? "").replace(/^[\s·•←-⇿─-➿⠀-⣿⬀-⯿*]+/, "").trim();
    }

    property string lastState: ""

    Process {
        id: watcher
        command: ["mmsg", "watch", "all-monitors"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const byName = {};
                    for (const m of JSON.parse(data).monitors ?? []) {
                        if (m.active_client) m.active_client.title = root.cleanTitle(m.active_client.title);
                        byName[m.name] = m;
                    }
                    // Only hand the bar a change it can see (a spinner frame in a title is not one).
                    const state = JSON.stringify(byName);
                    if (state === root.lastState) return;
                    root.lastState = state;
                    root.monitors = byName;
                } catch (e) {
                    console.warn("Mango: unreadable line from mmsg:", data);
                }
            }
        }
        // mango restarting its IPC ends the stream; start it again after a pause.
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 2000
        onTriggered: {
            watcher.running = true;
            if (Object.keys(root.layoutNames).length === 0) layoutsProc.running = true;
        }
    }

    // ---- Layouts -----------------------------------------------------------------------------------------------
    // A monitor's layout_symbol is its focused tag's layout ("DW"); mango names its symbols once, at start (and again
    // when the watch starts over, if that read failed): `mmsg get layouts` -> { layouts: [{ symbol, name }] }
    // ("DW" -> "dwindle"). "" for a symbol it did not name.
    property var layoutNames: ({})
    function layoutName(symbol) { return layoutNames[symbol] ?? "" }
    // The next layout in config.conf's circle_layout (Super+N's switch_layout).
    function nextLayout() { dispatch(["switch_layout"]) }
    Process {
        id: layoutsProc
        command: ["mmsg", "get", "layouts"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const names = {};
                    for (const l of JSON.parse(text).layouts ?? []) names[l.symbol] = l.name;
                    root.layoutNames = names;
                } catch (e) {
                    console.warn("Mango: unreadable layouts");
                }
            }
        }
    }

    // ---- Windows -----------------------------------------------------------------------------------------------
    // Every window mango manages, from `mmsg get all-clients`: [{ id, pid, appid, title, tags: [n], monitor, is_urgent,
    // is_focused, ... }], newest first, read on demand and only here: readClients(done) hands the list to `done` (null
    // if mango's answer did not parse); one asked for while a read runs gets the read after it, so it is never older
    // than the asking. `clients` is the dock's copy (and Busy's): the dock refreshes it while it is shown (and again
    // whenever the monitors stream changes then), so nothing runs while no dock is showing.
    property var clients: []
    function refreshClients() { readClients(list => { if (list) root.clients = list }) }
    property var reading: []        // waiting for the read under way
    property var queued: []         // waiting for the next one
    function readClients(done) {
        if (clientsProc.running) { queued = queued.concat([done]); return; }
        reading = [done];
        clientsProc.running = true;
    }
    Process {
        id: clientsProc
        command: ["mmsg", "get", "all-clients"]
        stdout: StdioCollector { id: clientsOut }
        onExited: {
            let list = null;
            try { list = JSON.parse(clientsOut.text).clients ?? [] } catch (e) { console.warn("Mango: unreadable all-clients") }
            const done = root.reading;
            root.reading = root.queued;
            root.queued = [];
            if (root.reading.length > 0) running = true;
            for (const f of done) f(list);
        }
    }
    // Focus a window (mango switches to its tag); close one gracefully (the app may ask first).
    function focusClient(id) { Quickshell.execDetached(["mmsg", "dispatch", "focusid", "client," + id]) }
    function closeClient(id) { Quickshell.execDetached(["mmsg", "dispatch", "killclient", "client," + id]) }
}
