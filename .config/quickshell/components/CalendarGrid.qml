import QtQuick
import Quickshell
import qs
import "../services/Format.js" as Format

// A month (design/panels DateTimePanel "Calendar"): an ISO week-number column and seven days from Monday, eight
// columns of `cell` x hitTarget cells (32 px, or as wide as the column allows: `cell`). Numbers in label, tabular,
// centred in their cells (the one place text is centred). Today: the accent fill with the number in onAccent, the
// view's one red. The selected day (a click, or the keys while browsing): a 2 px ink outline, never colour. Weekends
// muted; week numbers and the days of the neighbouring months faint.
// `shift(n)` moves by n months; `home()` returns to today; `moveDays(days)` moves the selection (and the month with it).
Column {
    id: cal
    property int cell: Theme.size.hitTarget
    readonly property int rowH: Theme.size.hitTarget

    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property date today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()      // 0-11
    property var selected: null               // a Date, or null: nothing outlined
    readonly property bool thisMonth: year === today.getFullYear() && month === today.getMonth()
    readonly property string title: Qt.formatDate(new Date(year, month, 1), "MMMM")
    signal picked(date day)

    function shift(months) {
        const m = month + months;
        year += Math.floor(m / 12);
        month = ((m % 12) + 12) % 12;
    }
    function home() { year = today.getFullYear(); month = today.getMonth(); selected = null }
    function show(d) { year = d.getFullYear(); month = d.getMonth() }
    function moveDays(days) {
        const from = selected ?? today;
        const d = new Date(from.getFullYear(), from.getMonth(), from.getDate() + days);
        selected = sameDay(d, today) ? null : d;
        show(d);
    }
    function moveMonths(n) {
        const from = selected ?? today;
        const d = new Date(from.getFullYear(), from.getMonth() + n, 1);
        d.setDate(Math.min(from.getDate(), new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()));
        selected = sameDay(d, today) ? null : d;
        show(d);
    }
    function sameDay(a, b) { return !!a && !!b && a.toDateString() === b.toDateString() }
    // Six weeks (42 days) from the Monday on or before the 1st: every month the same height, so browsing never moves
    // the panel's edge.
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(year, month, 1 - offset + i));
        return out;
    }

    width: 8 * cell

    Row {
        Repeater {
            model: ["wk", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Txt {
                required property string modelData
                required property int index
                width: cal.cell
                height: cal.rowH
                horizontalAlignment: Text.AlignHCenter
                variant: Theme.font.label
                text: modelData
                color: index === 0 ? Theme.colors.textFaint : Theme.colors.textMuted
            }
        }
    }
    Repeater {
        model: cal.days.length / 7
        Row {
            id: week
            required property int index
            Txt {
                width: cal.cell
                height: cal.rowH
                horizontalAlignment: Text.AlignHCenter
                variant: Theme.font.label
                text: Format.isoWeek(cal.days[week.index * 7])
                color: Theme.colors.textFaint
            }
            Repeater {
                model: 7
                Item {
                    id: dayCell
                    required property int index
                    readonly property date day: cal.days[week.index * 7 + index]
                    readonly property bool inMonth: day.getMonth() === cal.month
                    readonly property bool isToday: cal.sameDay(day, cal.today)
                    readonly property bool isSelected: cal.sameDay(day, cal.selected)
                    width: cal.cell
                    height: cal.rowH
                    Rectangle {
                        anchors.fill: parent
                        color: dayCell.isToday ? Theme.colors.accent : mouse.containsMouse ? Theme.states.hover : "transparent"
                        Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
                        border.width: dayCell.isSelected ? Theme.size.marker : 0
                        border.color: Theme.colors.text
                    }
                    Txt {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        variant: Theme.font.label
                        text: dayCell.day.getDate()
                        color: dayCell.isToday ? Theme.colors.textOnAccent
                             : !dayCell.inMonth ? Theme.colors.textFaint
                             : dayCell.index >= 5 ? Theme.colors.textMuted : Theme.colors.text
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cal.selected = dayCell.isToday ? null : dayCell.day;
                            if (!dayCell.inMonth) cal.show(dayCell.day);
                            cal.picked(dayCell.day);
                        }
                    }
                }
            }
        }
    }
}
