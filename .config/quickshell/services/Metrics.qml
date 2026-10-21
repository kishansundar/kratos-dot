pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The machine, live, for the dashboard (design/dashboard v2, the instrument sheet).
//   always, every refreshFast (1 s)   cpu (all threads, %) and each thread's, memory, the default route's interface
//                             (bytes/s down and up), the cpu package's temperature and an AIO's fan and pump (the
//                             sensors found once at start): file reads only, by one long-lived reader (scripts/metrics.pl, below), recorded in
//                             `history` even while the dashboard is closed (the owner's choice over the package's
//                             "measure only while visible": its ten-minute sparklines are full when it opens)
//   while `watching` (open)   the GPU (one `nvidia-smi -lms` reporting each refreshFast, stopped when it closes: the GPU
//                             columns of the history are gaps while closed); every refreshSlow the uptime and the average
//                             clock; every refreshIdle the filesystems (df)
// `history` holds the last historyWindow of samples {t, cpu, gpu, down, up, mem, vram, cpuTemp, gpuTemp}, oldest first;
// `stats(key)` gives its min, max and mean. Read once: host, os, the cpu's model, the GPU's name.
Singleton {
    id: root

    property bool watching: false

    property real cpu: -1                 // %
    property var threads: []              // % per thread
    property real ghz: 0
    property real memUsed: 0              // bytes
    property real memTotal: 0
    property bool hasGpu: false
    property string gpuName: ""
    property real gpu: -1                 // %
    property real vramUsed: 0             // bytes
    property real vramTotal: 0
    property real gpuTemp: -1
    property real gpuGhz: 0
    property real gpuFan: -1              // %, -1 when the card does not say
    property string iface: ""
    property real down: -1                // bytes per second
    property real up: -1
    property real cpuTemp: -1             // °C
    property real fan: -1                 // rpm
    property real pump: -1
    property var disks: []                // {mount, name, fstype, used, size}, bytes
    property real uptime: 0               // seconds
    property var history: []
    property int historyTick: 0

    property string host: ""
    property string os: ""
    property string cpuModel: ""

    // ---- Sampling -------------------------------------------------------------------------------------------
    // Every refreshFast, always: one long-lived reader (scripts/metrics.pl) reads /proc/stat, /proc/meminfo,
    // /proc/net/route and /proc/net/dev and the sensors' files and prints one JSON line (sample()). A FileView reloaded
    // each second wrote three debug lines per file per read to the shell's detailed log in /run (31-37 KB a minute, all
    // in RAM). The reader starts once the sensors are found; it ends with the shell (its next line meets a closed
    // pipe).
    property bool sensorsFound: false
    Process {
        running: root.sensorsFound
        command: ["perl", Quickshell.shellDir + "/scripts/metrics.pl", String(Theme.motion.refreshFast)]
            .concat(root.sensors.map(s => s.path))
        stdout: SplitParser { onRead: line => root.sample(line) }
    }
    Timer {
        running: root.watching
        interval: Theme.motion.refreshSlow
        repeat: true
        triggeredOnStart: true
        onTriggered: { uptimeFile.reload(); cpuinfo.reload(); }     // the clock: one decimal of GHz
    }
    Timer {
        running: root.watching
        interval: Theme.motion.refreshIdle
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!df.running) df.running = true
    }
    // The GPU is read only while open: closed, its last values are no sample.
    onWatchingChanged: if (!watching) { gpu = -1; vramUsed = 0; gpuTemp = -1; gpuFan = -1; }

    // The newest sample goes on the end and those older than the window come off the front, in place (no copy of the
    // ten minutes each second). The array stays the same object, so a change is told by `historyTick`: what draws the
    // history follows that, not `history` itself.
    function record() {
        const now = Date.now(), from = now - Theme.motion.historyWindow;
        const open = watching && hasGpu;
        history.push({ t: now, cpu: cpu, gpu: open ? gpu : -1, down: down, up: up,
                       mem: memTotal > 0 ? memUsed : -1, vram: open && vramTotal > 0 ? vramUsed : -1,
                       cpuTemp: cpuTemp, gpuTemp: open ? gpuTemp : -1 });
        let old = 0;
        while (old < history.length && history[old].t < from) old++;
        if (old > 0) history.splice(0, old);
        historyTick++;
    }

    // ---- A sample from the reader: memory, the network, the sensors, then the cpu (which records them) -------------
    function sample(line) {
        let d;
        try { d = JSON.parse(line); } catch (e) { return; }
        memTotal = d.mem[0] * 1024;
        memUsed = memTotal - d.mem[1] * 1024;
        netSample(d.iface, d.net);
        sensors.forEach((s, i) => {
            const v = d.sensors[i];                                  // null: unreadable this time, the last value stays
            if (typeof v === "number") root[s.key] = s.key.endsWith("Temp") ? v / 1000 : v;
        });
        cpuSample(d.stat);
    }

    // ---- cpu, per thread ---------------------------------------------------------------------------------------
    property var previousStat: null       // [[idle, total] per line: all, then each thread]
    function cpuSample(rows) {
        const p = previousStat;
        if (p && p.length === rows.length) {
            const busy = (r, q) => r[1] > q[1] ? 100 * (1 - (r[0] - q[0]) / (r[1] - q[1])) : 0;
            cpu = busy(rows[0], p[0]);
            threads = rows.slice(1).map((r, i) => busy(r, p[i + 1]));
        }
        previousStat = rows;
        if (p) record();
    }
    FileView {
        id: cpuinfo
        path: "/proc/cpuinfo"
        onLoaded: {
            const mhz = (text().match(/^cpu MHz\s*:\s*[\d.]+/gm) ?? []).map(l => Number(l.split(":")[1]));
            if (mhz.length > 0) root.ghz = mhz.reduce((a, b) => a + b, 0) / mhz.length / 1000;
            if (root.cpuModel === "") {
                const model = (text().match(/^model name\s*:\s*(.*)$/m) ?? ["", ""])[1];
                root.cpuModel = (model.match(/\b(i[3579]-\w+|Ryzen \d+ \w+|Xeon\S* \S+)/) ?? [model])[0];
            }
        }
    }
    // ---- Network: the interface of the default route -------------------------------------------------------------
    property var previousNet: null        // [t, rx, tx]
    function netSample(name, bytes) {     // bytes: [rx, tx] so far, or null
        iface = name;
        if (name === "" || !bytes) return;
        const now = Date.now(), p = previousNet;
        if (p && now > p[0]) {
            down = Math.max(0, (bytes[0] - p[1]) / ((now - p[0]) / 1000));
            up = Math.max(0, (bytes[1] - p[2]) / ((now - p[0]) / 1000));
        }
        previousNet = [now, bytes[0], bytes[1]];
    }

    // ---- Temperatures and fans (hwmon), found once by their names and labels ------------------------------------
    property var sensors: []              // {key, path}
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); "
                            + "for i in $h/temp*_input $h/fan*_input; do [ -e \"$i\" ] || continue; "
                            + "l=$(cat ${i%_input}_label 2>/dev/null || basename ${i%_input}); echo \"$n|$l|$i\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.trim().split("\n").map(l => l.split("|")).filter(r => r.length === 3);
                // The first row that passes a test, the tests tried in order.
                const pick = (key, ...tests) => {
                    for (const test of tests) { const r = rows.find(test); if (r) return [{ key: key, path: r[2] }]; }
                    return [];
                };
                const fan = r => /^fan/i.test(r[1]) && r[2].includes("/fan");
                root.sensors = [].concat(
                    pick("cpuTemp", r => (r[0] === "coretemp" && /^Package/.test(r[1])) || (r[0] === "k10temp" && r[1] === "Tctl")),
                    // A fan its driver names (the cooler's "Fan") before a bare header named by its file: the board's
                    // nct6793 headers (fan1..fan6, mostly empty) come first in hwmon order.
                    pick("fan", r => fan(r) && !/^fan\d+$/.test(r[1]), fan),
                    pick("pump", r => /pump/i.test(r[1]) && r[2].includes("/fan")));
                root.sensorsFound = true;                    // the reader starts, with their files (sample())
            }
        }
    }

    // ---- GPU: nvidia-smi, reporting each refreshFast while the overlay is open --------------------------------
    Process {
        running: true
        command: ["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"]
        stdout: StdioCollector { id: gpuNameOut }
        onExited: code => {
            root.hasGpu = code === 0 && gpuNameOut.text.trim() !== "";
            root.gpuName = gpuNameOut.text.trim().split("\n")[0].replace(/^NVIDIA (GeForce )?/, "");
        }
    }
    Process {
        running: root.watching && root.hasGpu
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,clocks.gr,fan.speed",
                  "--format=csv,noheader,nounits", "-lms", String(Theme.motion.refreshFast)]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split(",").map(s => Number(s.trim()));
                if (f.length < 6 || isNaN(f[0])) return;
                root.gpu = f[0];
                root.vramUsed = f[1] * 1048576;
                root.vramTotal = f[2] * 1048576;
                root.gpuTemp = f[3];
                root.gpuGhz = f[4] / 1000;
                root.gpuFan = isNaN(f[5]) ? -1 : f[5];
            }
        }
    }

    // ---- Filesystems ------------------------------------------------------------------------------------------
    Process {
        id: df
        command: ["df", "-B1", "--output=target,fstype,used,size", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs",
                  "-x", "overlay", "-x", "squashfs", "-x", "ramfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.disks = text.trim().split("\n").slice(1).map(l => {
                    const f = l.trim().split(/\s+/);
                    const mount = f.slice(0, f.length - 3).join(" ");
                    return {
                        mount: mount,
                        // Removable drives under /run/media/<user>/ by their label; one without a label (its UUID) by the
                        // UUID's first block.
                        name: !mount.startsWith("/run/media/") ? mount
                            : mount.split("/").pop().replace(/^([0-9a-f]{8})-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, "$1"),
                        fstype: f[f.length - 3], used: Number(f[f.length - 2]), size: Number(f[f.length - 1])
                    };
                }).filter(d => d.size > 0);
            }
        }
    }

    // ---- Read once (and the uptime) ----------------------------------------------------------------------------
    FileView { id: uptimeFile; path: "/proc/uptime"; onLoaded: root.uptime = Number(text().split(" ")[0]) || 0 }
    FileView { path: "/proc/sys/kernel/hostname"; onLoaded: root.host = text().trim().toLowerCase() }
    FileView {
        path: "/etc/os-release"
        onLoaded: {
            const v = key => (text().match(new RegExp("^" + key + "=\"?([^\"\\n]*)\"?", "m")) ?? ["", ""])[1];
            root.os = (v("NAME") + " " + v("VERSION_ID")).trim();
        }
    }

    // The history's min, max and mean of one key (samples < 0 left out), for the sheet's table view and the network
    // rows' full scale (the ten-minute peak).
    function stats(key) {
        let min = Infinity, max = -Infinity, sum = 0, n = 0;
        for (const s of history) { const v = s[key]; if (v === undefined || v < 0) continue; min = Math.min(min, v); max = Math.max(max, v); sum += v; n++; }
        return n > 0 ? { min: min, max: max, mean: sum / n } : { min: -1, max: -1, mean: -1 };
    }

    // ---- Formats ---------------------------------------------------------------------------------------------
    // One decimal under 100, none above (the system's rule for numbers).
    function num(v) { return v < 100 ? (Math.round(v * 10) / 10).toFixed(1) : String(Math.round(v)) }
    // Bytes in GiB or MiB: [value, unit].
    function bytes(b) { return b >= 1073741824 ? [num(b / 1073741824), "GiB"] : [num(b / 1048576), "MiB"] }
    // Throughput in MB/s (decimal, like transferred data): the value only.
    function mbps(b) { return b < 0 ? "–" : num(b / 1e6) }
}
