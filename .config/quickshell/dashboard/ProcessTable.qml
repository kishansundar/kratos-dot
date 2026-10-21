import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// The top apps (design/dashboard ProcessTable, grouped by app: services/Processes): eight rows of 32 px on 1 px rules,
// no zebra, no boxes. An app of several processes shows how many after its name (×18); one of several instances
// (five Claude Code sessions) has no single pid ("–"), and its tooltip counts them.
//   app                                    pid      cpu ▾       mem     the header (label, muted; the sorted one in ink
//   zen                                  24816       18.2     1.9 GiB    with ▾ / ▴: a click sorts, again reverses)
// Name in body (cut names in the tooltip), pid in mono muted, numbers in label, tabular, right-aligned. A right click
// on a row offers "copy pid" and "terminate", and terminate asks once more before it sends SIGTERM.
Column {
    id: table
    property var processes: []
    property string sortKey: "cpu"          // cpu | rss | pid | name
    property bool descending: true
    property int count: 8
    property int actionsFor: -1             // the pid whose row shows its actions
    property bool confirming: false

    readonly property int pidW: 64
    readonly property int numW: 72
    readonly property var rows: {
        const k = sortKey, d = descending ? -1 : 1;
        return processes.slice().sort((a, b) => (a[k] < b[k] ? -1 : a[k] > b[k] ? 1 : 0) * d || b.cpu - a.cpu).slice(0, count);
    }
    // The rows are new objects at every refresh: the list is keyed by app name (ScriptModel; an app is one row), and each
    // row looks its numbers up here, so a refresh or a re-sort moves rows instead of rebuilding them (a tooltip and a
    // row's actions stay put).
    readonly property var names: rows.map(r => r.name)
    readonly property var byName: { const m = {}; for (const r of rows) m[r.name] = r; return m }
    function sortBy(k) {
        if (sortKey === k) descending = !descending;
        else { sortKey = k; descending = k !== "name"; }
    }
    function memory(b) { const m = Metrics.bytes(b); return m[0] + " " + m[1] }

    // ---- The header ------------------------------------------------------------------------------------------
    component Head: Item {
        id: head
        property string key: ""
        property string word: ""
        property bool alignRight: true
        readonly property bool sorted: table.sortKey === key
        height: Theme.dash.listRow
        Txt {
            anchors { verticalCenter: parent.verticalCenter; left: head.alignRight ? undefined : parent.left; right: head.alignRight ? parent.right : undefined }
            variant: Theme.font.label
            text: head.word + (head.sorted ? (table.descending ? " ▾" : " ▴") : "")
            color: head.sorted ? Theme.colors.text : Theme.colors.textMuted
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: table.sortBy(head.key) }
    }
    Row {
        width: table.width
        Head { width: table.width - table.pidW - 2 * table.numW; key: "name"; word: "app"; alignRight: false }
        Head { width: table.pidW; key: "pid"; word: "pid" }
        Head { width: table.numW; key: "cpu"; word: "cpu" }
        Head { width: table.numW; key: "rss"; word: "mem" }
    }
    Rectangle { width: table.width; height: Theme.size.rule; color: Theme.colors.line }

    // ---- The rows ------------------------------------------------------------------------------------------------
    Repeater {
        model: ScriptModel { values: table.names }
        Item {
            id: row
            required property var modelData        // the app's name
            readonly property var p: table.byName[modelData] ?? { pid: -1, pids: [], name: modelData, cpu: 0, rss: 0, count: 0, instances: 0 }
            readonly property bool acting: table.actionsFor === p.pid
            width: parent ? parent.width : 0           // the table
            height: Theme.dash.listRow + Theme.size.rule

            HoverFill { anchors.bottomMargin: Theme.size.rule; hovered: mouse.containsMouse || row.acting }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: event => {
                    if (event.button === Qt.RightButton) { table.actionsFor = row.acting ? -1 : row.p.pid; table.confirming = false; }
                    else if (row.acting) table.actionsFor = -1;
                }
                onContainsMouseChanged: {
                    if (containsMouse && (name.truncated || row.p.count > 1))
                        Tip.show(name, name.width / 2, name.height, row.p.name
                                 + (row.p.instances > 1 ? " · " + row.p.instances + " instances" : "")
                                 + (row.p.count > 1 ? " · " + row.p.count + " processes" : ""));
                    else Tip.hide(name);
                }
                // A row leaving the top 8 while hovered is destroyed without a containsMouse change: take its tip along.
                Component.onDestruction: if (name && Tip.owner === name) Tip.hide(name)
            }
            Txt {
                id: name
                x: 0
                width: Math.min(implicitWidth, table.width - table.pidW - 2 * table.numW - Theme.space.s3
                                - (countText.visible ? countText.implicitWidth + Theme.space.s2 : 0))
                height: Theme.dash.listRow
                text: row.p.name
            }
            // How many processes the app is, after its name (a browser's tabs and helpers), faint. Its own width, never
            // set: an eliding Text whose width follows its implicitWidth loops (the warning in the log).
            Annot {
                id: countText
                visible: row.p.count > 1
                x: name.width + Theme.space.s2
                height: Theme.dash.listRow
                text: "\u00d7" + row.p.count
                color: Theme.colors.textFaint
            }
            Row {
                visible: !row.acting
                x: table.width - table.pidW - 2 * table.numW
                height: Theme.dash.listRow
                Annot { width: table.pidW; height: parent.height; horizontalAlignment: Text.AlignRight; text: row.p.instances > 1 ? "–" : row.p.pid }
                Txt { width: table.numW; height: parent.height; horizontalAlignment: Text.AlignRight; variant: Theme.font.label; text: Metrics.num(row.p.cpu) }
                Txt { width: table.numW; height: parent.height; horizontalAlignment: Text.AlignRight; variant: Theme.font.label; text: table.memory(row.p.rss) }
            }
            // A right click: its actions in place of the numbers; terminate asks again.
            Row {
                visible: row.acting
                anchors.right: parent.right
                height: Theme.dash.listRow
                spacing: Theme.space.s4
                Annot {
                    visible: table.confirming
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.p.instances > 1 ? "terminate all " + row.p.instances + " " + row.p.name + "?"
                                                 : "terminate " + row.p.name + " (" + row.p.pid + ")?"
                    color: Theme.colors.text
                }
                TextButton {
                    visible: !table.confirming && row.p.instances === 1
                    text: "copy pid"
                    onClicked: { Quickshell.execDetached(["wl-copy", String(row.p.pid)]); table.actionsFor = -1; }
                }
                TextButton {
                    text: table.confirming ? "yes" : "terminate…"
                    onClicked: {
                        if (!table.confirming) { table.confirming = true; return; }
                        Processes.terminate(row.p.pids);
                        table.actionsFor = -1;
                        table.confirming = false;
                    }
                }
                TextButton {
                    visible: table.confirming
                    text: "no"
                    onClicked: { table.actionsFor = -1; table.confirming = false; }
                }
            }
            Rectangle { y: Theme.dash.listRow; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
        }
    }
}
