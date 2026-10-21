import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Power (design/panels PowerMenu; the power glyph at the bar's far right, or Super+Esc), powerWidth wide:
//   Power ········· up 3d 4h      h2 and its ruler; the uptime in mono
//   Lock                    [L]   acts at once
//   ───────────────────────────
//   Log out                 [E]   these three start a countdown in the same panel (powerCountdown, 5 s):
//   Reboot                  [R]     Shutting down in 3 s           body 600
//   Shut down               [P]     ━━━━━━━━━━┃──────────           an accent ruler draining to zero (the panel's
//                                   2 apps still open: zen, kitty   only red while it runs; the menu has none)
//                                   [shut down]  [cancel]           now, or stop (Esc too)
// Words, no icons; each row's key drawn as a key (the owner's choice: four bare letters read as a word). The countdown
// runs under reduceMotion too, only its fill moves in whole seconds. Nothing acts unless this panel is open and has
// the keyboard (keys reach it only then).
// Departure: no Suspend row. Kratos never sleeps (~/nixos/modules/hardware.nix: AllowSuspend = "no"; it is reached
// from afar through Tailscale and RustDesk), so suspend would only fail.
// Keys: ↑ ↓ choose, Enter or the letter acts, Esc stops the countdown, then closes.
Column {
    id: menu
    width: Theme.panel.powerColumn
    focus: true

    readonly property var actions: [
        { label: "Lock", key: "l", countdown: false, command: ["loginctl", "lock-session"] },
        { label: "Log out", key: "e", countdown: true, doing: "Logging out", now: "log out", command: ["mmsg", "dispatch", "quit"] },
        { label: "Reboot", key: "r", countdown: true, doing: "Rebooting", now: "reboot", command: ["systemctl", "reboot"] },
        { label: "Shut down", key: "p", countdown: true, doing: "Shutting down", now: "shut down", command: ["systemctl", "poweroff"] }
    ]
    property int current: 0
    property var pending: null          // the action counting down
    property real started: 0
    property real elapsed: 0
    readonly property real total: Theme.panel.powerCountdown
    readonly property real remaining: Math.max(0, total - elapsed)

    // The one place an action runs. A test shell (Theme.dryRun) only says what it would do: it shares this session.
    function act(a) {
        if (Theme.dryRun) console.log("PowerPanel: DRYRUN", a.command.join(" "));
        else Quickshell.execDetached(a.command);
    }
    function run(a) {
        if (!a.countdown) { Panels.close(); act(a); return; }
        pending = a;
        started = Date.now();
        elapsed = 0;
        Mango.readClients(list => {
            const ids = (list ?? []).map(c => (c.appid || "").split(".").pop().toLowerCase()).filter(s => s !== "");
            menu.openApps = ids.filter((s, i) => ids.indexOf(s) === i);
        });
        tick.restart();
    }
    function now() {
        const a = pending;
        tick.stop();
        pending = null;
        Panels.close();
        act(a);
    }
    function cancel() { tick.stop(); pending = null; elapsed = 0 }

    Timer {
        id: tick
        interval: Theme.reduceMotion ? 1000 : Theme.panel.countdownStep
        repeat: true
        onTriggered: {
            menu.elapsed = Date.now() - menu.started;
            if (menu.elapsed >= menu.total) menu.now();
        }
    }

    // Uptime, read once when the menu opens.
    FileView { id: uptimeFile; path: "/proc/uptime" }
    readonly property string uptime: {
        const s = parseFloat(uptimeFile.text());
        if (isNaN(s)) return "";
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return ("up " + (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + (d === 0 ? m + "m" : "")).trim();
    }

    // The open windows' apps, read when a countdown starts (mango's clients; the app id's last word, once each).
    property var openApps: []

    Keys.onPressed: event => {
        if (menu.pending) {
            if (event.key === Qt.Key_Escape) { menu.cancel(); event.accepted = true; }
            return;
        }
        const byLetter = actions.findIndex(a => a.key === event.text.toLowerCase());
        if (event.key === Qt.Key_Down) current = (current + 1) % actions.length;
        else if (event.key === Qt.Key_Up) current = (current + actions.length - 1) % actions.length;
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) run(actions[current]);
        else if (byLetter >= 0 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) { current = byLetter; run(actions[byLetter]); }
        else return;
        event.accepted = true;
    }

    Heading { title: "Power"; annotation: menu.uptime }
    Item { width: 1; height: Theme.space.s4 }

    // ---- The menu ---------------------------------------------------------------------------------------------
    Column {
        visible: !menu.pending
        width: parent.width
        Repeater {
            model: menu.actions
            Column {
                id: entry
                required property var modelData
                required property int index
                width: menu.width
                // The rule between acting at once (lock) and ending the session.
                MenuRule { visible: entry.index === 1 }
                RowItem {
                    selected: menu.current === entry.index
                    onHoveredIn: menu.current = entry.index
                    onActivated: menu.run(entry.modelData)

                    Txt {
                        anchors { left: parent.left; right: key.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                        text: entry.modelData.label
                    }
                    // The key that runs this row, drawn as a key: a hairline square, its letter in capitals.
                    Rectangle {
                        id: key
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: Theme.panel.keyCap
                        height: Theme.panel.keyCap
                        color: "transparent"
                        border.width: Theme.size.rule
                        border.color: Theme.colors.tick
                        Txt {
                            anchors.centerIn: parent
                            variant: Theme.font.label
                            text: entry.modelData.key.toUpperCase()
                            color: Theme.colors.textMuted
                        }
                    }
                }
            }
        }
    }

    // ---- The countdown ----------------------------------------------------------------------------------------
    Column {
        visible: menu.pending !== null
        width: parent.width
        spacing: Theme.space.s2

        Txt {
            width: parent.width
            height: Theme.size.hitTarget
            text: menu.pending ? menu.pending.doing + " in " + Math.ceil(menu.remaining / 1000) + " s" : ""
            variant: Theme.font.bodyStrong
        }
        // The ruler draining to zero: the baseline, the accent fill and its value tick (the panel's one red).
        Item {
            id: drain
            width: parent.width
            height: Theme.ruler.tickValue
            readonly property real v: Theme.reduceMotion ? Math.ceil(menu.remaining / 1000) * 1000 / menu.total : menu.remaining / menu.total
            readonly property int base: height - Theme.space.s1
            Rectangle { y: drain.base; width: parent.width; height: Theme.ruler.tickW; color: Theme.colors.tick }
            Rectangle { y: drain.base - Theme.ruler.tickMajor + 1; width: Theme.ruler.tickW; height: Theme.ruler.tickMajor; color: Theme.colors.tick }
            Rectangle {
                y: drain.base - 1
                width: Math.round(drain.v * (drain.width - Theme.size.marker))
                height: Theme.ruler.fill
                color: Theme.colors.accent
            }
            Rectangle {
                x: Math.round(drain.v * (drain.width - Theme.size.marker))
                y: drain.base + 2 - height
                width: Theme.size.marker
                height: Theme.ruler.tickValue
                color: Theme.colors.accent
            }
        }
        Annot {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            lineHeightMode: Text.FixedHeight
            lineHeight: Theme.font.mono.lineHeight
            height: implicitHeight
            text: menu.openApps.length === 0 ? "no apps open"
                : menu.openApps.length + (menu.openApps.length === 1 ? " app still open: " : " apps still open: ") + menu.openApps.join(", ")
        }
        Row {
            spacing: Theme.space.s2
            TextButton { kind: "primary"; text: menu.pending ? menu.pending.now : ""; onClicked: menu.now() }
            TextButton { kind: "framed"; text: "cancel"; onClicked: menu.cancel() }
        }
    }
}
