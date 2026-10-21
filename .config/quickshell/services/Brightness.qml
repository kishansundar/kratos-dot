pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The monitors' brightness and contrast over DDC/CI (design/display): the monitor's own backlight, the setting its
// buttons change, not a dimming filter. This is the one writer to the I²C bus; the bar, the Display panel, the keys
// (IPC) and anything later (the dashboard) go through it. ddcutil, one process at a time:
//   detect   at start: `ddcutil detect --brief` gives each display's bus, connector and model (cached, so no bus
//            number is ever written down here); again while no monitor answers, on events only (redetectDue())
//   read     `ddcutil --bus N getvcp 10 --brief` -> "VCP 10 C 47 100" (value, max), and 12 for contrast; at start,
//            when the Display panel opens and after every write. Nothing reads the bus on a timer.
//   write    `ddcutil --bus N setvcp 10 <v> --noverify`, then our read-back (the one verify per step; ddcutil's own
//            verify would read the bus a second time). A newer target replaces one still waiting (latest wins): the
//            bus never gets a queue of writes.
// Every call passes --skip-ddc-checks: on the NVIDIA driver an I²C transfer holds a driver lock mango's page flips
// also need, so the whole desktop stalls while ddcutil talks to the monitor (measured 15 October 2026: up to ~150 ms
// per call). Skipping ddcutil's start-up probe cut a read from ~250 to ~140 ms and a write from ~320 to ~170 ms.
// Until the read-back agrees, a control is "sending" (drawn muted, with a faint tick at the confirmed value). No
// agreement within Theme.display.timeout: "failed", the control returns to the confirmed value, and retry() resends.
// The keys and the bar's wheel step by Theme.display.step %: the first press of a burst is written at once (the
// monitor answers the press, not 300 ms after it), and the presses after it within Theme.display.settle merge into
// one more write.
//
//   state      "unknown" (not detected yet) | "missing" (no ddcutil) | "none" (no monitor answers DDC/CI) | "ready"
//   monitors   per DDC monitor: { bus, connector, model, read (its brightness has been read once), b: control, c:
//              control or null (no contrast) }, where a control is { value, max, target (-1: none pending), state
//              "idle" | "sending" | "failed", failed (the target that failed) }
//   silent     connectors of monitors that don't answer DDC/CI
//   ready      the focused monitor's brightness has been read: before that its value is a placeholder 0, never a
//              starting point for a step
Singleton {
    id: root

    property string state: "unknown"
    property var monitors: []
    property var silent: []
    readonly property bool ready: state === "ready" && revision >= 0 && current !== null && current.read

    // Brightness changed by a key or the bar's wheel, or a write from one of them was read back: the OSD shows.
    signal stepped(int index)

    // The monitor the keys and the bar act on: the one on the bar's screen, else the first.
    readonly property int focused: {
        const name = Panels.screen?.name ?? "";
        const i = monitors.findIndex(m => m.connector === name);
        return i >= 0 ? i : 0;
    }
    readonly property var current: monitors[focused] ?? null
    function percent(ctl, raw) { revision; return ctl && ctl.max > 0 ? Math.round((raw ?? ctl.value) / ctl.max * 100) : 0 }
    // What a control shows: the pending target while sending, else the confirmed value.
    function shown(ctl) { revision; return ctl && ctl.target >= 0 ? ctl.target : ctl ? ctl.value : 0 }

    // ---- Actions -------------------------------------------------------------------------------------------
    // Read every value once (the panel opens).
    function refresh() {
        if (state === "unknown" || state === "missing" || state === "none" && redetectDue()) { detect(); return; }
        for (const m of monitors) { enqueue({ kind: "read", bus: m.bus, vcp: "10" }); if (m.c) enqueue({ kind: "read", bus: m.bus, vcp: "12" }); }
    }
    // Set brightness ("10") or contrast ("12") of monitor i to a raw value: one write now (a slider's release, a preset).
    function set(i, vcp, raw) {
        const m = monitors[i], ctl = m ? (vcp === "10" ? m.b : m.c) : null;
        if (!ctl) return;
        ctl.target = Math.max(0, Math.min(ctl.max, Math.round(raw)));
        ctl.state = "sending";
        ctl.unsent = false;
        ctl.deadline = Date.now() + Theme.display.timeout;
        changed();
        enqueue({ kind: "write", bus: m.bus, vcp: vcp, value: ctl.target });
    }
    function setPercent(i, vcp, pct) { const m = monitors[i]; const ctl = m ? (vcp === "10" ? m.b : m.c) : null; if (ctl) set(i, vcp, pct / 100 * ctl.max) }
    function retry(i, vcp) { const m = monitors[i]; const ctl = m ? (vcp === "10" ? m.b : m.c) : null; if (ctl && ctl.failed >= 0) set(i, vcp, ctl.failed) }
    // A key or a wheel notch on the bar: ±step % of the focused monitor's brightness; the OSD shows. `limit` says "max" or
    // "min" when the press could not move it.
    property string limit: ""
    // Before a monitor is known (ddcutil missing at start, installed since; or detection still running) the presses are
    // kept, detection runs again, and they apply once the monitor's brightness has been read. So with a monitor detected
    // but not read (its first read failed: asleep, or the bus busy): each press is kept and reads it again (no timer),
    // and they apply when a read succeeds within `timeout` of the last press; later than that they are dropped. Nothing
    // steps from the unread 0.
    property int pendingSteps: 0
    property real pendingUntil: 0         // 0: the kept presses wait for detection, which has no deadline
    function step(steps) {
        if (!current || !current.read) {
            if (current) {
                if (pendingUntil > 0 && Date.now() > pendingUntil) pendingSteps = 0;
                pendingSteps += steps;
                pendingUntil = Date.now() + Theme.display.timeout;
                enqueue({ kind: "read", bus: current.bus, vcp: "10" });
            } else if (state === "missing" || state === "unknown" || state === "none" && redetectDue()) {
                pendingSteps += steps;
                detect();
            }
            limit = ""; stepped(-1); return;
        }
        limit = nudge(focused, "10", steps);
        stepped(focused);
    }
    // ±steps x step % of a control, merged with the presses before it within `settle` into one write. A monitor not
    // read yet has no value to step from: it is read instead.
    function nudge(i, vcp, steps) {
        const m = monitors[i], c = m ? (vcp === "10" ? m.b : m.c) : null;
        if (!c) return "";
        if (!m.read) { enqueue({ kind: "read", bus: m.bus, vcp: "10" }); return ""; }
        const from = shown(c);
        const lo = vcp === "10" ? Math.round(Theme.display.floor / 100 * c.max) : 0;
        const to = Math.max(lo, Math.min(c.max, from + Math.round(steps * Theme.display.step / 100 * c.max)));
        if (to === from) return steps > 0 ? "max" : "min";
        // The first press of a burst goes at once; the ones within `settle` after it wait and merge.
        if (!settle.running) { set(i, vcp, to); settle.restart(); return ""; }
        c.target = to;
        c.state = "sending";
        c.unsent = true;
        c.deadline = Date.now() + Theme.display.settle + Theme.display.timeout;
        changed();
        settle.restart();
        return "";
    }
    Timer {
        id: settle
        interval: Theme.display.settle
        onTriggered: root.monitors.forEach((m, i) => { if (m.b.unsent) root.set(i, "10", m.b.target); if (m.c && m.c.unsent) root.set(i, "12", m.c.target) })
    }

    // ---- The bus: one ddcutil at a time -------------------------------------------------------------------
    property var queue: []
    function enqueue(job) {
        // Latest wins: a write replaces a waiting write (and its read-back) for the same control.
        if (job.kind === "write") queue = queue.filter(j => !(j.bus === job.bus && j.vcp === job.vcp && j.kind !== "detect"));
        else {
            // A read already waiting for the same control serves this one too, keeping a read-back's `after` flag (a
            // plain read queued first, the Display panel opening mid-step, would otherwise drop it).
            const waiting = queue.find(j => j.kind === job.kind && j.bus === job.bus && j.vcp === job.vcp);
            if (waiting) { if (job.after) waiting.after = true; return; }
        }
        queue = queue.concat([job]);
        next();
    }
    function next() {
        if (proc.running || queue.length === 0) return;
        const job = queue[0];
        queue = queue.slice(1);
        proc.job = job;
        proc.command = job.kind === "detect" ? ["sh", "-c", "command -v ddcutil >/dev/null || exit 127; exec ddcutil detect --brief --skip-ddc-checks"]
            : job.kind === "read" ? ["ddcutil", "--bus", String(job.bus), "--skip-ddc-checks", "getvcp", job.vcp, "--brief"]
            : ["ddcutil", "--bus", String(job.bus), "--skip-ddc-checks", "--noverify", "setvcp", job.vcp, String(job.value)];
        proc.running = true;
    }
    function detect() { if (!queue.some(j => j.kind === "detect") && !(proc.job && proc.job.kind === "detect")) enqueue({ kind: "detect" }) }
    // "none" is not final: a monitor off or asleep at detection answers later. While none answers, a key press, the
    // Display panel opening or a screen being plugged in detects again, but no sooner than Theme.display.redetect after
    // the last detection (5 s, then 30 s, then 5 min: detection probes every I²C bus, the slowest call, and every call
    // stalls the desktop on this driver). A detection that finds a monitor, or a screen plugged in, starts the backoff
    // over. Never on a timer.
    property real detectedAt: 0
    property int misses: 0                // detections in a row that found no monitor
    function redetectDue() {
        const wait = Theme.display.redetect;
        return Date.now() - detectedAt >= wait[Math.max(0, Math.min(misses, wait.length) - 1)];
    }
    Connections {
        target: Quickshell
        function onScreensChanged() { if (root.state === "none") { root.misses = 0; root.detect(); } }
    }
    Component.onCompleted: detect()

    Process {
        id: proc
        property var job: null
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: code => {
            const job = proc.job;
            proc.job = null;
            if (job.kind === "detect") root.detected(code, out.text);
            else if (job.kind === "read") root.readDone(job, code, out.text);
            else root.wrote(job, code, err.text);
            root.next();
        }
    }

    function control(bus, vcp) { const m = monitors.find(x => x.bus === bus); return m ? (vcp === "10" ? m.b : m.c) : null }
    function ctl(value, max) { return { value: value, max: max, target: -1, state: "idle", failed: -1, deadline: 0, unsent: false } }

    function detected(code, text) {
        detectedAt = Date.now();
        if (code === 127) { state = "missing"; pendingSteps = 0; return; }
        const found = [], quiet = [];
        // Blocks: "Display 1" (answers DDC/CI) or "Invalid display" (doesn't), each with its bus, connector, monitor.
        for (const block of text.split(/\n(?=\S)/)) {
            const bus = /I2C bus:\s*\/dev\/i2c-(\d+)/.exec(block);
            const conn = /DRM connector:\s*card\d+-(\S+)/.exec(block);
            const mon = /Monitor:\s*[^:\n]*:([^:\n]*):/.exec(block);
            if (/^Display \d+/.test(block) && bus)
                found.push({ bus: parseInt(bus[1]), connector: conn ? conn[1] : "", model: mon ? mon[1].trim().split(/\s+/).pop() : "monitor",
                             b: ctl(0, 100), c: null, read: false });
            else if (/^Invalid display/.test(block) && conn) quiet.push(conn[1]);
        }
        monitors = found;
        silent = quiet;
        state = found.length > 0 ? "ready" : "none";
        misses = found.length > 0 ? 0 : misses + 1;
        if (found.length === 0) pendingSteps = 0;
        for (const m of found) { enqueue({ kind: "read", bus: m.bus, vcp: "10" }); enqueue({ kind: "read", bus: m.bus, vcp: "12" }); }
        if (found.length > 0 && pendingSteps !== 0) pendingUntil = Date.now() + Theme.display.timeout;   // and wait for a read
    }

    function readDone(job, code, text) {
        const m = monitors.find(x => x.bus === job.bus);
        if (!m) return;
        const r = /VCP\s+([0-9A-Fa-f]{2})\s+C\s+(\d+)\s+(\d+)/.exec(text);
        if (job.vcp === "12") {
            // Contrast is optional: a monitor that doesn't offer VCP 0x12 has no contrast block.
            if (r) { if (!m.c) m.c = ctl(0, 0); m.c.value = parseInt(r[2]); m.c.max = parseInt(r[3]); }
            if (m.c) root.settleControl(m.c, job);
        } else if (r) {
            m.b.value = parseInt(r[2]);
            m.b.max = parseInt(r[3]);
            const first = !m.read;
            m.read = true;
            root.settleControl(m.b, job);
            if (first && pendingSteps !== 0 && m === current) {
                const s = pendingSteps, late = pendingUntil > 0 && Date.now() > pendingUntil;
                pendingSteps = 0; pendingUntil = 0;
                if (!late) Qt.callLater(() => root.step(s));
            }
            if (job.after) root.stepped(monitors.indexOf(m));
        }
        changed();
    }
    // After a read: a pending target the monitor now reports is confirmed; one it doesn't report is read again until
    // its deadline (the check below fails it then).
    function settleControl(c, job) {
        if (c.target < 0) return;
        if (c.value === c.target) { c.target = -1; c.state = "idle"; c.failed = -1; }
        else if (job.after) retryRead.restart();
    }
    function wrote(job, code, errText) {
        const c = control(job.bus, job.vcp);
        if (!c || c.target !== job.value) return;          // a newer target is already on its way
        if (code !== 0) console.warn("Brightness: setvcp", job.vcp, "on bus", job.bus, "failed:", errText.trim().split("\n").pop());
        enqueue({ kind: "read", bus: job.bus, vcp: job.vcp, after: true });
    }
    Timer { id: retryRead; interval: Theme.display.settle; onTriggered: { for (const m of root.monitors) for (const c of [m.b, m.c]) if (c && c.state === "sending" && !c.unsent) root.enqueue({ kind: "read", bus: m.bus, vcp: c === m.b ? "10" : "12", after: true }) } }

    // Deadlines: a target not read back in time has failed; the control shows the confirmed value again. Runs only
    // while something is sending, and reads nothing.
    Timer {
        running: root.revision >= 0 && root.monitors.some(m => (m.b && m.b.state === "sending") || (m.c && m.c.state === "sending"))
        interval: 250
        repeat: true
        onTriggered: {
            const now = Date.now();
            let hit = false;
            for (const m of root.monitors) for (const c of [m.b, m.c]) {
                if (c && c.state === "sending" && !c.unsent && now > c.deadline) {
                    c.failed = c.target; c.target = -1; c.state = "failed"; hit = true;
                }
            }
            if (hit) { root.changed(); root.stepped(root.focused); }
        }
    }
    // Monitors' inner values change in place: `revision` counts the changes, and every reader binds to it (through
    // shown() / percent() or directly). `monitors` itself changes only on detection, so a panel's delegates (and a
    // slider being dragged) are never rebuilt by a read.
    property int revision: 0
    function changed() { revision++ }
}
