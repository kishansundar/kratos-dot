pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Night light: a warm screen through wlsunset (mango has wlr gamma-control, checked 15 October 2026). One state for
// Super+Alt+N and the dashboard's switch, kept in Prefs so it comes back after a restart:
//   on         Prefs.nightOn: wlsunset runs while it is on
//   temp       Prefs.nightTemp, 2500-6500 K; changing it restarts wlsunset at the new temperature
//   schedule   Prefs.nightSchedule: warm from sunset to sunrise only, at the time zone's reference city (zone1970.tab:
//              Asia/Kolkata -> Kolkata, 22.5 N 88.4 E; no location service is asked). Off: warm all day (the day and
//              night temperatures 1 K apart, so the hour makes no visible difference)
// If wlsunset stops by itself, the switch goes back to off: `error` keeps its last words and `unsupported` is set
// when it says the compositor has no gamma control.
Singleton {
    id: root

    readonly property bool on: Prefs.nightOn
    readonly property int temp: Prefs.nightTemp
    readonly property bool schedule: Prefs.nightSchedule
    property bool unsupported: false
    property string error: ""
    property string place: ""           // the reference city's name, lower case ("kolkata")
    property real lat: NaN
    property real lon: NaN

    function toggle() { setOn(!Prefs.nightOn) }
    function setOn(v) { error = ""; Prefs.set("nightOn", v && !unsupported) }
    function setTemp(k) {
        const c = Theme.control;
        Prefs.set("nightTemp", Math.max(c.nightTempMin, Math.min(c.nightTempMax, Math.round(k / c.nightTempStep) * c.nightTempStep)));
    }
    function setSchedule(v) { Prefs.set("nightSchedule", v) }

    readonly property var args: {
        const t = String(temp), day = String(Math.max(Theme.control.nightTempMax, temp + 1));
        if (schedule && !isNaN(lat)) return ["-t", t, "-T", day, "-l", lat.toFixed(2), "-L", lon.toFixed(2)];
        return ["-t", t, "-T", String(temp + 1), "-S", "06:00", "-s", "18:00"];
    }
    // wlsunset outlives a shell that is killed (it is not this process's to take along), and a second one on the same
    // display fails for want of gamma control. So it is started through a pid file per display: a wlsunset left by an
    // earlier shell is stopped first, then this one takes its place (exec: the pid in the file is wlsunset's).
    readonly property string launcher: "f=\"${XDG_RUNTIME_DIR:-/tmp}/swiss-wlsunset-${WAYLAND_DISPLAY:-wayland}.pid\"; "
        + "p=$(cat \"$f\" 2>/dev/null); [ -n \"$p\" ] && [ \"$(cat /proc/$p/comm 2>/dev/null)\" = wlsunset ] && kill \"$p\" && sleep 0.2; "
        + "echo $$ > \"$f\"; exec wlsunset \"$@\""
    readonly property var command: ["sh", "-c", launcher, "sh"].concat(args)
    // On, off, or a new temperature or mode (a running Process keeps its command line): stop, then start if on.
    property bool stopping: false
    function apply() {
        if (sunset.running) { stopping = true; sunset.running = false; }
        else sunset.running = on;
    }
    onOnChanged: apply()
    onCommandChanged: if (sunset.running) apply()

    Process {
        id: sunset
        command: root.command
        stderr: StdioCollector { id: errText }
        onExited: (code, status) => {
            // Stopped by us (switched off, or restarting): start again if it should run.
            if (root.stopping) { root.stopping = false; if (root.on) sunset.running = true; return; }
            if (!root.on) return;
            const words = errText.text.trim().split("\n").pop() ?? "";
            root.unsupported = /gamma/i.test(words);
            root.error = words || "wlsunset exited with " + code;
            Prefs.set("nightOn", false);
        }
    }

    // The reference city of the time zone, for the schedule: /etc/localtime -> Asia/Kolkata -> zone1970.tab. A night light
    // left on starts once this is read (a few ms), so a scheduled one starts at its place's times instead of starting
    // on 06:00 / 18:00 and restarting a moment later.
    Process {
        running: true
        onExited: if (!sunset.running) sunset.running = root.on
        command: ["sh", "-c", "z=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||'); awk -v z=\"$z\" '$3 == z { print $2, $3 }' /etc/zoneinfo/zone1970.tab | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "+2232+08822 Asia/Kolkata": degrees and minutes (and sometimes seconds), signed.
                const m = text.trim().match(/^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})? (\S+)/);
                if (!m) return;
                root.lat = (m[1] === "-" ? -1 : 1) * (Number(m[2]) + Number(m[3]) / 60 + Number(m[4] ?? 0) / 3600);
                root.lon = (m[5] === "-" ? -1 : 1) * (Number(m[6]) + Number(m[7]) / 60 + Number(m[8] ?? 0) / 3600);
                root.place = m[9].split("/").pop().replace(/_/g, " ").toLowerCase();
            }
        }
    }
}
