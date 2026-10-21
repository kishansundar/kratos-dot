import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import "../services/Format.js" as Format

// Date and time (design/panels DateTimePanel; click the clock, or Super+Ctrl+C), hung under the clock's stroke:
//   Date and time ··········· Asia/Kolkata · UTC+05:30     h2 and its ruler; the zone and its offset in mono
//   14:21 :07                                              display (tabular), the seconds in h2 faint (ticking only
//   Thursday, 15 October 2026                              while open); the date written out; ISO week and day of the
//   week 42 · day 288 of 365                               year in mono
//   October 2026                        today  ‹  ›        the month (body 600), "today" while away from it, the arrows
//   wk Mo Tu We Th Fr Sa Su                                components/CalendarGrid: today the accent fill (the one
//   ...                                                    red); the selected day a 2 px ink outline
//   WORLD CLOCKS                                   3       Prefs.clocks: the city, its offset from here (mono), its
//   Berlin                               −3:30  10:51      time (label 600); 22:00-06:59 faint with "(night)"
//   ────────────────────────────── ntp · synced 4 min ago  the clock's sync state (▲ "not synced" when it is not)
// Read only: no events (no calendar source is wired in). Opens on today every time.
// Departures: no "date & time settings" link (there is no such tool here; the zone is set in NixOS, time.timeZone).
// World clocks are zone names in ~/.local/state/swiss/shell.json ("clocks": ["UTC", "Europe/Berlin"], at most
// Theme.panel.clocksMax); add one there, remove one with a right click on its row.
// Keys: ← → a day, ↑ ↓ a week, Page Up / Page Down a month, Home today, Enter selects, Esc close.
Column {
    id: panel
    width: Theme.panel.column
    focus: true

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    readonly property int localOffset: -now.getTimezoneOffset()     // minutes east of UTC

    // ---- The zone, the sync state and the world clocks' offsets, read once on open (and when the clocks change) ----
    readonly property var clocks: Prefs.clocks.slice(0, Theme.panel.clocksMax)
    property string zone: ""
    property string ntp: ""            // "yes" / "no": NTP is in use
    property string synced: ""         // "yes" / "no"
    property real lastSync: 0          // ms since the epoch, 0 = unknown
    property var offsets: ({})         // zone -> minutes east of UTC; missing = an unknown zone

    onClocksChanged: probe.running = true
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "zi=${TZDIR:-/etc/zoneinfo}; echo \"zone $(timedatectl show -p Timezone --value)\"; "
            + "echo \"ntp $(timedatectl show -p NTP --value)\"; echo \"synced $(timedatectl show -p NTPSynchronized --value)\"; "
            + "m=$(timedatectl show-timesync -p NTPMessage --value 2>/dev/null | sed -n 's/.*DestinationTimestamp=[A-Za-z]* \\([0-9-]* [0-9:]*\\).*/\\1/p'); "
            + "[ -n \"$m\" ] && echo \"last $(date -d \"$m\" +%s)\"; "
            + "for c in \"$@\"; do if [ \"$c\" = UTC ] || [ -e \"$zi/$c\" ]; then echo \"clock $c $(TZ=$c date +%z)\"; fi; done", "sh"].concat(panel.clocks)
        stdout: StdioCollector {
            onStreamFinished: {
                const off = {};
                for (const line of text.split("\n")) {
                    const f = line.split(" ");
                    if (f[0] === "zone") panel.zone = f[1] ?? "";
                    else if (f[0] === "ntp") panel.ntp = f[1] ?? "";
                    else if (f[0] === "synced") panel.synced = f[1] ?? "";
                    else if (f[0] === "last") panel.lastSync = (parseInt(f[1]) || 0) * 1000;
                    else if (f[0] === "clock" && f.length >= 3) off[f[1]] = panel.minutes(f[2]);
                }
                panel.offsets = off;
            }
        }
    }

    function minutes(z) {            // "+0530" -> 330
        const sign = z.charAt(0) === "-" ? -1 : 1;
        return sign * (parseInt(z.substr(1, 2), 10) * 60 + parseInt(z.substr(3, 2), 10));
    }
    function hm(m, plus, pad) {      // 330 -> "5:30", -330 -> "−5:30" (a true minus), plus: "+5:30", pad: "+05:30"
        const a = Math.abs(m);
        const s = String(Math.floor(a / 60)).padStart(pad ? 2 : 1, "0") + ":" + String(a % 60).padStart(2, "0");
        return m < 0 ? "−" + s : plus ? "+" + s : s;
    }
    function city(z) { return z === "UTC" ? "UTC" : z.split("/").pop().replace(/_/g, " ") }
    function dayOfYear(d) { return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 1)) / 86400000) + 1 }
    function daysInYear(y) { return new Date(y, 1, 29).getMonth() === 1 ? 366 : 365 }
    readonly property string syncText: {
        if (ntp === "no") return "ntp off";
        if (synced !== "yes") return "not synced";
        if (lastSync <= 0) return "ntp · synced";
        const min = Math.floor((now.getTime() - lastSync) / 60000);
        return "ntp · synced " + (min < 1 ? "just now" : min < 60 ? min + " min ago" : Math.floor(min / 60) + " h ago");
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) grid.moveDays(-1);
        else if (event.key === Qt.Key_Right) grid.moveDays(1);
        else if (event.key === Qt.Key_Up) grid.moveDays(-7);
        else if (event.key === Qt.Key_Down) grid.moveDays(7);
        else if (event.key === Qt.Key_PageUp) grid.moveMonths(-1);
        else if (event.key === Qt.Key_PageDown) grid.moveMonths(1);
        else if (event.key === Qt.Key_Home) grid.home();
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (grid.selected) grid.picked(grid.selected) }
        else return;
        event.accepted = true;
    }

    Heading {
        title: "Date and time"
        annotation: panel.zone === "" ? "" : panel.zone + " · UTC" + panel.hm(panel.localOffset, true, true)
    }
    Item { width: 1; height: Theme.space.s5 }

    // ---- Now --------------------------------------------------------------------------------------------------
    Item {
        width: parent.width
        height: Theme.font.display.lineHeight
        Txt {
            id: hhmm
            variant: Theme.font.display
            height: Theme.font.display.lineHeight
            text: Qt.formatTime(panel.now, "HH:mm")
        }
        Txt {
            anchors { left: hhmm.right; leftMargin: Theme.space.s2; baseline: hhmm.baseline }
            variant: Theme.font.h2
            text: ":" + Qt.formatTime(panel.now, "ss")
            color: Theme.colors.textFaint
        }
    }
    Txt {
        width: parent.width
        height: Theme.font.body.lineHeight
        text: Qt.formatDate(panel.now, "dddd, d MMMM yyyy")
    }
    Annot {
        width: parent.width
        text: "week " + Format.isoWeek(panel.now) + " · day " + panel.dayOfYear(panel.now) + " of " + panel.daysInYear(panel.now.getFullYear())
    }

    // ---- Calendar ---------------------------------------------------------------------------------------------
    Item { width: 1; height: Theme.panel.sectionGap }
    Item {
        width: parent.width
        height: Theme.size.hitTarget
        Txt {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: grid.title + " " + grid.year
            variant: Theme.font.bodyStrong
        }
        Row {
            // The chevrons' glyphs end on the column's edge; their 32 px targets reach into the padding.
            anchors { right: parent.right; rightMargin: -(Theme.size.hitTarget - Theme.size.icon) / 2; verticalCenter: parent.verticalCenter }
            TextButton {
                visible: !grid.thisMonth || grid.selected !== null
                anchors.verticalCenter: parent.verticalCenter
                text: "today"
                onClicked: grid.home()
            }
            Item { visible: !grid.thisMonth || grid.selected !== null; width: Theme.space.s4; height: 1 }
            GlyphButton { name: Theme.icons.chevronLeft; onClicked: grid.shift(-1) }
            GlyphButton { name: Theme.icons.chevronRight; onClicked: grid.shift(1) }
        }
    }
    CalendarGrid {
        id: grid
        cell: Math.floor(panel.width / 8)
    }

    // ---- World clocks -------------------------------------------------------------------------------------------
    Item { width: 1; height: Theme.panel.sectionGap }
    SectionHead { title: "World clocks"; annotation: panel.clocks.length }
    Repeater {
        model: panel.clocks
        Item {
            id: zoneRow
            required property string modelData
            readonly property bool known: panel.offsets[modelData] !== undefined
            readonly property int offset: panel.offsets[modelData] ?? 0
            readonly property date there: new Date(panel.now.getTime() + (offset - panel.localOffset) * 60000)
            readonly property bool night: there.getHours() >= Theme.panel.nightFrom || there.getHours() < Theme.panel.nightTo
            width: panel.width
            height: Theme.size.hitTarget

            Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
            Txt {
                anchors { left: parent.left; right: timeRow.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: panel.city(zoneRow.modelData)
            }
            Row {
                id: timeRow
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s3
                Annot {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !zoneRow.known ? (Object.keys(panel.offsets).length > 0 || !probe.running ? "unknown zone" : "") : panel.hm(zoneRow.offset - panel.localOffset, true)
                }
                Txt {
                    visible: zoneRow.known
                    anchors.verticalCenter: parent.verticalCenter
                    variant: Theme.font.labelStrong
                    text: Qt.formatTime(zoneRow.there, "HH:mm") + (zoneRow.night ? " (night)" : "")
                    color: zoneRow.night ? Theme.colors.textFaint : Theme.colors.text
                }
            }
            // A right click removes the clock.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: Prefs.set("clocks", Prefs.clocks.filter(z => z !== zoneRow.modelData))
            }
        }
    }
    Txt {
        visible: panel.clocks.length === 0
        height: Theme.size.hitTarget
        text: "No world clocks."
        color: Theme.colors.textMuted
    }

    // ---- Footer: the sync state ---------------------------------------------------------------------------------
    Item { width: 1; height: Theme.space.s5 }
    Item {
        width: parent.width
        height: Theme.space.s3 + Theme.size.hitTarget
        Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; bottomMargin: (Theme.size.hitTarget - height) / 2 }
            spacing: Theme.space.s2
            Mark {
                visible: panel.synced === "no" && panel.ntp !== "no"
                anchors.verticalCenter: parent.verticalCenter
                kind: "triangle"
            }
            Annot {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.syncText
                color: Theme.colors.textFaint
            }
        }
    }
}
