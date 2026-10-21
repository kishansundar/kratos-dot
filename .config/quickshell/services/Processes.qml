pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The processes, for the dashboard's table: every refreshSlow while `watching`, from /proc/<pid>/stat. The cpu share
// is what each used since the previous read (ps would give the average over its whole life): % of one thread, as top
// shows it. rss in bytes. NixOS wrappers keep their real name (".zen-wrapped" -> "zen").
// Grouped by app (the owner's choice): a process counts toward its highest ancestor that something launched (the
// compositor, a shell, systemd, a terminal multiplexer, login), so a browser's tab and helper processes ("Isolated Web
// Co", "Web Content", "RDD Process" under zen's forkserver) are one "zen", and a program run from a shell is its own
// app; a shell script (run-shell.sh) launches too. Then the apps of one name are one row: five Claude Code sessions are
// one "claude", five kitty windows one "kitty". Kernel threads are left out: they are no app.
// Memory is each process's proportional share (Pss, /proc/<pid>/smaps_rollup: shared pages split among their users,
// so a browser's 20 processes do not count its libraries 20 times), read every refreshIdle (it costs the kernel about
// 0.15 s); a process whose share cannot be read (another user's) counts its resident set.
//   list    {pid (the app's own; the first of several), pids (each instance's own), name, cpu, rss, count (processes),
//            instances}, every app (the table sorts and takes its eight)
//   terminate(pids)   SIGTERM to each instance's own process (the table asks first); their children go with them
Singleton {
    id: root

    property bool watching: false
    property var list: []
    property var previous: ({})           // pid -> cpu ticks at `previousAt`
    property real previousAt: 0
    readonly property int ticksPerSecond: 100     // USER_HZ on Linux
    readonly property int pageSize: 4096

    Timer {
        running: root.watching
        interval: Theme.motion.refreshSlow
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!read.running) read.running = true
    }
    Timer {
        id: baseline
        interval: Theme.motion.refreshFast
        onTriggered: if (root.watching && !read.running) read.running = true
    }
    onWatchingChanged: if (!watching) { previous = {}; previousAt = 0; }

    // What launches apps rather than being one: a process whose parent is one of these is an app of its own.
    readonly property var launchers: ["systemd", "init", "mango", "login", "greetd", "sshd", "sudo", "doas", "bash", "fish",
                                      "zsh", "sh", "dash", "tmux: server", "screen", "dbus-daemon", "dbus-broker-launch"]
    function launches(name) { return launchers.includes(name) || name.endsWith(".sh") }

    function cleanName(comm) {
        return comm.startsWith(".") ? comm.slice(1).replace(/-(w(r(a(p(p(e(d)?)?)?)?)?)?)?$/, "") : comm;
    }

    Process {
        id: read
        command: ["sh", "-c", "cd /proc && cat [0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now(), seen = {}, procs = {};
                const dt = root.previousAt > 0 ? (now - root.previousAt) / 1000 : 0;
                for (const line of text.split("\n")) {
                    const open = line.indexOf("("), close = line.lastIndexOf(")");
                    if (open < 0 || close < 0) continue;
                    const pid = Number(line.slice(0, open));
                    const f = line.slice(close + 2).split(" ");     // from field 3 (state) on
                    const ticks = Number(f[11]) + Number(f[12]);  // utime + stime
                    seen[pid] = ticks;
                    const before = root.previous[pid];
                    procs[pid] = {
                        name: root.cleanName(line.slice(open + 1, close)),
                        ppid: Number(f[1]),
                        cpu: dt > 0 && before !== undefined ? Math.max(0, (ticks - before) / root.ticksPerSecond / dt * 100) : 0,
                        rss: root.pss[pid] ?? Number(f[21]) * root.pageSize
                    };
                }
                root.previous = seen;
                root.previousAt = now;
                // The first read after opening has nothing to compare with (every cpu 0, the order arbitrary for a whole
                // refreshSlow): it is only the baseline; read again after refreshFast. The table keeps its rows meanwhile.
                if (dt === 0) { baseline.restart(); return; }
                // Each process's app: walk up while the parent is not a launcher.
                const appOf = {};
                const find = pid => {
                    if (appOf[pid] !== undefined) return appOf[pid];
                    const pr = procs[pid];
                    let app = pid;
                    if (pr && (pid === 2 || pr.ppid === 2)) app = 2;                     // kernel threads
                    else if (pr && pr.ppid > 1 && procs[pr.ppid] && !root.launches(procs[pr.ppid].name))
                        app = find(pr.ppid);
                    appOf[pid] = app;
                    return app;
                };
                // Each app's processes, then the apps of one name together.
                const apps = {};
                for (const key in procs) {
                    const pid = Number(key), a = find(pid), pr = procs[pid];
                    if (a === 2) continue;                                              // kernel threads: no app
                    const name = procs[a]?.name ?? pr.name;
                    if (!apps[name]) apps[name] = { pid: a, pids: [], name: name, cpu: 0, rss: 0, count: 0, instances: 0 };
                    const app = apps[name];
                    if (!app.pids.includes(a)) { app.pids.push(a); app.instances++; app.pid = Math.min(app.pid, a); }
                    app.cpu += pr.cpu;
                    app.rss += pr.rss;
                    app.count++;
                }
                root.list = Object.values(apps);
            }
        }
    }

    // A test shell (Theme.dryRun) shares this machine's processes: it only says what it would end.
    function terminate(pids) {
        const command = ["kill", "-TERM"].concat(pids.map(String));
        if (Theme.dryRun) console.log("Processes: DRYRUN", command.join(" "));
        else Quickshell.execDetached(command);
    }

    // Proportional memory, every refreshIdle: "<pid>/smaps_rollup:Pss: <kB> kB".
    property var pss: ({})
    Timer {
        running: root.watching
        interval: Theme.motion.refreshIdle
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!pssRead.running) pssRead.running = true
    }
    Process {
        id: pssRead
        command: ["sh", "-c", "cd /proc && grep -H '^Pss:' [0-9]*/smaps_rollup 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const line of text.split("\n")) {
                    const r = line.match(/^(\d+)\/smaps_rollup:Pss:\s+(\d+)/);
                    if (r) m[Number(r[1])] = Number(r[2]) * 1024;
                }
                root.pss = m;
            }
        }
    }
}
