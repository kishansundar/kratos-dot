pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Claude Code usage for its popover, from separate sources that must not be confused:
//
//   report  What Claude Code itself reports through its status line (documented): the model, the context window,
//           the session's cost estimate and, on Pro/Max plans, the five-hour and weekly limits with reset times.
//           ~/.config/quickshell/scripts/claude-statusline.sh saves it after each assistant message, so it is as
//           fresh as the last message of any running session; `reportAge` says how old it is.
//   local   Today's token counts from the local session logs (scripts/claude-usage.sh), an estimate: the log
//           format is internal to Claude Code. Read when the Claude popover opens and every 60 s while it is open.
//
// Nothing here is invented: a missing value stays missing and the popover says so.
Singleton {
    id: root

    property bool watching: false
    property bool installed: false

    // ---- Claude Code's report ------------------------------------------------------------------------
    property var report: null              // the status line JSON
    property real reportAt: 0              // epoch seconds when it was written
    readonly property real reportAge: reportAt > 0 ? now / 1000 - reportAt : -1
    readonly property var limits: report?.rate_limits ?? null
    // A plan limit's window as of now: null once it has reset since the report (it then says nothing about now). Near
    // its end past 80 %: the bar (amber mark) and the popover (the meter's triangle) both ask here, so they agree.
    function current(w) { return w && w.resets_at > now / 1000 ? w : null }
    function near(w) { const c = current(w); return !!c && (c.used_percentage ?? 0) >= 80 }

    FileView {
        path: Theme.cacheDir + "/claude/status.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.report = j.status ?? null;
                root.reportAt = j.written_at ?? 0;
            } catch (e) { /* half-written: keep the last good report */ }
        }
    }

    // ---- Local log estimate --------------------------------------------------------------------------
    property var local: null
    property string localError: ""
    property real localAt: 0

    function refresh() { if (!usage.running) usage.running = true }
    onWatchingChanged: if (watching) { refresh(); readSessions(); check.running = true; }
    Component.onCompleted: check.running = true
    Timer { running: root.watching; repeat: true; interval: 60000; onTriggered: root.refresh() }

    Process {
        id: usage
        command: ["timeout", "10", Quickshell.shellDir + "/scripts/claude-usage.sh"]
        stdout: StdioCollector { id: usageOut }
        onExited: code => {
            root.localAt = Date.now() / 1000;
            try {
                const j = JSON.parse(usageOut.text);
                root.local = j;
                root.localError = j.ok ? "" : (j.reason || "Could not read the session logs");
            } catch (e) {
                root.localError = code === 124 ? "Reading the logs took too long" : "Could not read the session logs";
            }
        }
    }
    Process {
        id: check
        command: ["sh", "-c", "command -v claude"]
        onExited: code => root.installed = code === 0
    }

    // ---- Sessions: each running session's own report (context, cost), newest first ----------------------
    // The status line keeps one report per session_id (sessions/<id>.json), so concurrent sessions are never
    // mixed. Read while a view of them is open, every 30 s; at most 8, heard from within a day.
    property var sessions: []
    readonly property string sessionsDir: Theme.cacheDir + "/claude/sessions"
    function readSessions() { if (!sessionsProc.running) sessionsProc.running = true }
    Timer { running: root.watching; repeat: true; interval: 30000; onTriggered: root.readSessions() }
    Process {
        id: sessionsProc
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; ls -t -- *.json 2>/dev/null | head -n 8 | while read -r f; do cat -- \"$f\"; echo; done", "sh", root.sessionsDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue;
                    try {
                        const j = JSON.parse(line), s = j.status ?? {};
                        const dir = s.workspace?.current_dir ?? s.cwd ?? "";
                        out.push({
                            id: s.session_id ?? "",
                            name: s.session_name || dir.replace(/\/+$/, "").split("/").pop() || "session",
                            model: s.model?.display_name ?? "",
                            context: s.context_window?.used_percentage ?? null,
                            cost: s.cost?.total_cost_usd ?? null,
                            at: j.written_at ?? 0
                        });
                    } catch (e) { /* a report being rewritten: skip it this time */ }
                }
                root.sessions = out.sort((a, b) => b.at - a.at);
            }
        }
    }

    // A clock for ages and countdowns: every 30 s while a view of it is open, every minute otherwise (the bar).
    property real now: Date.now()
    Timer { running: true; repeat: true; interval: root.watching ? 30000 : 60000; triggeredOnStart: true; onTriggered: root.now = Date.now() }

    // 1234567 -> "1.2M", 85320 -> "85.3k"
    function tokens(n) {
        if (n === undefined || n === null) return "–";
        return n >= 1e6 ? (n / 1e6).toFixed(1) + "M" : n >= 1e3 ? (n / 1e3).toFixed(1) + "k" : String(n);
    }
}
