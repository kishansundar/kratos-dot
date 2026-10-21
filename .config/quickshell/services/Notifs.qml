pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import Quickshell.Services.Notifications

// The notification server. New notifications become pop-ups (unless do-not-disturb is on; critical ones always show)
// and stay in the history until dismissed or cleared.
// Do not disturb is Prefs.dnd, switched through setDnd (the bar, the notifications popover, the dashboard, the key):
// on, it holds for Prefs.dndHold ("30m" "1h" "2h", or "off": until switched off) and ends by itself at
// Prefs.dndUntil; `held` counts the notifications it kept from popping up since it went on.
// While the focused window is fullscreen (a game, a film) new notifications do not pop up either, as under do not
// disturb, and the toasts already up are hidden (Toasts.qml); they still reach the history and the unread count, and
// critical ones still show. Not counted in `held`, which is do not disturb's. mango reports fullscreen through
// wlr-foreign-toplevel (ToplevelManager), so nothing polls. (From Caelestia, whose pop-ups keep quiet the same way.)
//
// History that survives a restart (design/panels NotificationsPanel): the server keeps live notifications across a
// reload (keepOnReload), not across a restart. So every notification is also a record { key, id, session, app,
// summary, body, image, time, urgency } in $XDG_STATE_HOME/swiss/notifications.json, written atomically, newest
// last, at most Theme.panel.historyMax. A record of this run (`session`) still has its live notification (`live(r)`:
// actions, the default action); after a restart it is a record only. Dismissing either removes both. The image is
// kept only when it is a file (an image the sender handed over the bus does not outlive the run).
// clearLater() hides everything for Theme.panel.undo and then clears it; undoClear() brings it back. clearAll()
// clears at once (Ctrl+Alt+Backspace).
Singleton {
    id: root

    readonly property var history: server.trackedNotifications.values
    readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false
    property var popups: []      // shown as pop-ups, newest first
    property alias unread: persist.unread     // the counts outlive a reload, as the notifications they count do
    property alias held: persist.held

    function setDnd(on) {
        const min = Theme.control.holdMinutes[Prefs.dndHold] ?? 0;
        Prefs.set("dndUntil", on && min > 0 ? Date.now() + min * 60000 : 0);
        if (on && !Prefs.dnd) held = 0;
        Prefs.set("dnd", on);
    }
    // A new hold while on starts counting from now.
    function setDndHold(h) { Prefs.set("dndHold", h); if (Prefs.dnd) setDnd(true) }
    Timer {
        running: Prefs.dnd && Prefs.dndUntil > 0
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= Prefs.dndUntil) root.setDnd(false)
    }
    // Notifications that arrived today (the dashboard says how many while do not disturb is off).
    function today() {
        const start = new Date(); start.setHours(0, 0, 0, 0);
        return Object.values(received).filter(t => t >= start.getTime()).length;
    }
    // Arrival times (the protocol carries none), kept across shell reloads like the notifications themselves.
    // Stored as a JSON string: only plain values survive a shell reload. `session` names this run (kept across reloads,
    // new after a restart), so a record knows whether its live notification can still exist.
    readonly property var received: JSON.parse(persist.times)
    PersistentProperties {
        id: persist
        reloadableId: "notification-times"
        property string times: "{}"
        property string senders: "{}"
        property string session: ""
        property int unread: 0
        property int held: 0
        onLoaded: if (session === "") session = String(Date.now())
    }
    function stamp(id, time) {
        const m = JSON.parse(persist.times);
        if (time === undefined) delete m[id]; else m[id] = time;
        persist.times = JSON.stringify(m);
    }

    function unpop(n) { popups = popups.filter(p => p !== n) }
    function markRead() { unread = 0 }
    function clearAll() {
        pendingClear = [];
        for (const n of server.trackedNotifications.values.slice())
            if (!closedIds[n.id]) n.dismiss();
        setRecords([]);
        popups = [];
        unread = 0;
    }
    function isCritical(n) { return n.urgency === NotificationUrgency.Critical }
    // A progress the sender reports with the "value" hint (0-100: a download, a copy), as 0-1; -1 without one.
    function progress(n) {
        const v = n && n.hints ? n.hints["value"] : undefined;
        return typeof v === "number" && v >= 0 ? Math.min(100, v) / 100 : -1;
    }

    // ---- Records -----------------------------------------------------------------------------------------------
    property var records: []
    readonly property string session: persist.session
    property var pendingClear: []           // keys hidden by clear all, until the undo window ends
    readonly property var shown: records.filter(r => !pendingClear.includes(r.key))

    // The live notification of a record of this run, or null. Reads `history`, so a binding follows it.
    // A notification that has said it closed can stay in the tracked list a moment longer; closing it again logs
    // "Cannot close destroyed notification" (seen once in the live log), so one known to be closed is not live.
    function live(r) {
        if (!r || r.session !== session) return null;
        return history.find(n => n.id === r.id && !closedIds[n.id]) ?? null;
    }
    function setRecords(list) {
        records = list.slice(-Theme.panel.historyMax);
        store.setText(JSON.stringify(records) + "\n");
    }
    function record(n) {
        // The image survives a restart only when the sender named a file (the image-path hint).
        const hint = n.hints ? (n.hints["image-path"] ?? n.hints["image_path"] ?? "") : "";
        const file = typeof hint === "string" ? (hint.startsWith("/") ? "file://" + hint : hint.startsWith("file:") ? hint : "") : "";
        setRecords(records.filter(r => !(r.session === session && r.id === n.id)).concat([{
            key: session + "-" + n.id, id: n.id, session: session,
            app: n.appName || "", summary: n.summary || "", body: n.body || "",
            image: file,
            time: received[n.id] ?? Date.now(),
            urgency: n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1
        }]));
    }
    function drop(key) {
        if (records.some(r => r.key === key)) setRecords(records.filter(r => r.key !== key));
    }

    // The record of a live notification (the toast's), or one made up for it: what invoke and dismiss take.
    function recordOf(n) {
        return records.find(r => r.session === session && r.id === n.id) ?? { key: session + "-" + n.id, id: n.id, session: session };
    }
    // Click: the sender's window (goToSender), the default action (if the sender is still there), then dismiss.
    // Middle click or ×: dismiss. The toast and the centre both come here.
    function invoke(r) {
        const n = live(r);
        if (n) {
            goToSender(n);
            const def = n.actions.find(a => a.identifier === "default");
            if (def) def.invoke();
        }
        dismiss(r);
    }
    // One of the sender's own actions; the notification goes unless it says it stays (resident).
    function act(r, action) {
        const n = live(r);
        action.invoke();
        if (!n || !n.resident) dismiss(r);
    }
    function dismiss(r) {
        const n = live(r);
        if (n) n.dismiss();
        drop(r.key);
    }

    function clearLater() {
        pendingClear = records.map(r => r.key);
        popups = [];
        unread = 0;
        clearTimer.restart();
    }
    function undoClear() { clearTimer.stop(); pendingClear = [] }
    Timer {
        id: clearTimer
        interval: Theme.panel.undo
        onTriggered: {
            const keys = root.pendingClear;
            root.pendingClear = [];
            for (const r of root.records.filter(r => keys.includes(r.key))) {
                const n = root.live(r);
                if (n) n.dismiss();
            }
            root.setRecords(root.records.filter(r => !keys.includes(r.key)));
        }
    }

    // ---- The sender's window -----------------------------------------------------------------------------------
    // A click on a notification also brings the window that sent it. The protocol names no sender, so one `busctl
    // monitor` watches the Notify calls and this server's replies: the reply carries the id, its call the sender's bus
    // name (`senders`, id -> name, kept across a reload). The click asks the bus for that name's process and focuses
    // its mango window, or that of its nearest parent with one (a program running in a terminal: the terminal); a
    // sender that has gone (a notify-send) has no process left to ask, and a process with several windows (a browser)
    // is left to its own default action. kitty needs this: on the default action it shows the tab that sent it but
    // cannot raise its window without an activation token, which Quickshell's server does not send (0.3.2), and mango
    // lets only the browsers take the focus without one (mango rule.conf).
    property var calls: ({})            // "<sender> <cookie>" of Notify calls waiting for their reply
    // Only a message's header is parsed, and a reply's payload (the id): a call's payload can carry an image's pixels
    // (image-data, one number per byte), and Qt's JSON.parse takes a slot of its JavaScript stack for each element of
    // an array, so CoolerControl's 1 MiB icon overflowed it and crashed the shell (18 October 2026). busctl prints
    // every header field before the payload.
    readonly property string payloadKey: ',"payload":'
    function sent(id, sender) {
        const m = JSON.parse(persist.senders);
        if (sender) m[id] = sender; else delete m[id];
        persist.senders = JSON.stringify(m);
    }
    Process {
        id: busWatch
        running: true
        command: ["busctl", "--user", "monitor", "--json=short",
            "--match", "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
            "--match", "type='method_return',sender='org.freedesktop.Notifications'"]
        stdout: SplitParser {
            onRead: line => {
                const at = line.indexOf(root.payloadKey);
                if (at < 0) return;
                let m;
                try { m = JSON.parse(line.slice(0, at) + "}") } catch (e) { return }
                if (m.type === "method_call") { root.calls[m.sender + " " + m.cookie] = true; return; }
                const key = m.destination + " " + m.reply_cookie;
                if (!root.calls[key]) return;
                delete root.calls[key];
                let id;
                try { id = JSON.parse(line.slice(at + root.payloadKey.length, -1)).data[0] } catch (e) { return }
                root.sent(id, m.destination);
            }
        }
        onExited: busRestart.start()
    }
    Timer { id: busRestart; interval: 5000; onTriggered: busWatch.running = true }

    function goToSender(n) {
        const sender = JSON.parse(persist.senders)[n.id];
        if (!sender || senderProc.running) return;
        senderProc.command = ["sh", "-c",
            'p=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ' +
            'GetConnectionUnixProcessID s "$1" | cut -d" " -f2); ' +
            'while [ -n "$p" ] && [ "$p" -gt 1 ]; do echo "$p"; p=$(sed "s/.*) //" "/proc/$p/stat" | cut -d" " -f2); done',
            "sh", sender];
        senderProc.running = true;
    }
    Process {
        id: senderProc
        stdout: StdioCollector {
            onStreamFinished: {
                const pids = text.split("\n").filter(s => s).map(Number);
                if (pids.length === 0) return;
                Mango.readClients(clients => {
                    if (!clients) return;
                    for (const pid of pids) {
                        const own = clients.filter(c => c.pid === pid);
                        if (own.length === 0) continue;
                        if (own.length === 1) Mango.focusClient(own[0].id);
                        return;
                    }
                });
            }
        }
    }

    FileView {
        id: store
        path: Theme.stateDir + "/notifications.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false          // no file yet on a first start: an empty history, nothing to say
        onLoaded: {
            try {
                const list = JSON.parse(text());
                root.records = Array.isArray(list) ? list.filter(r => r && typeof r.key === "string" && typeof r.summary === "string") : [];
            } catch (e) {
                console.warn("Notifs: notifications.json is not valid JSON; starting with an empty history");
            }
        }
    }

    // Every tracked notification, also those restored by a reload, gets its close handler once per run of this file.
    // A notification closed by the user, by its sender or by expiry leaves the history; its record goes with it.
    property var watched: ({})
    property var closedIds: ({})          // ids whose closed signal has come, this run (see live())
    onHistoryChanged: {
        for (const n of history) {
            if (watched[n.id]) continue;
            watched[n.id] = true;
            if (!records.some(r => r.session === session && r.id === n.id)) record(n);
            // A sender that replaces its notification (a download's progress, the next track) changes this object in
            // place, and the server announces nothing new: the centre's record follows the new text.
            const follow = () => { if (root.records.some(r => r.session === root.session && r.id === n.id)) root.record(n) };
            n.summaryChanged.connect(follow);
            n.bodyChanged.connect(follow);
            n.closed.connect(reason => {
                root.unpop(n);
                root.stamp(n.id);
                root.sent(n.id);
                root.drop(root.session + "-" + n.id);
                delete root.watched[n.id];
                root.closedIds[n.id] = true;
            });
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        // A reload hands every notification it kept over again (keepOnReload): those are not new, so they keep their
        // arrival time and neither pop up again nor count as unread a second time.
        onNotification: n => {
            if (n.lastGeneration) { n.tracked = true; return; }
            delete root.closedIds[n.id];
            root.stamp(n.id, Date.now());
            n.tracked = true;
            root.unread++;
            if (root.isCritical(n) || (!Prefs.dnd && !root.fullscreen))
                root.popups = [n].concat(root.popups).slice(0, 5);
            else if (Prefs.dnd)
                root.held++;
        }
    }
}
