import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import "../services/AppMatch.js" as AppMatch

// The app launcher (design/launcher), Super+Space or a click on the NixOS mark: hung flush from the bar rule, its left
// edge on the mark (BarSlot.hangLeft), Theme.launcher.width wide.
//   query     the search glyph, the query in h2 with a 2 px ink caret, the count in mono at the right ("24 apps",
//             "2 of 24"); under it a ruler the launcher's width whose ink fill is the share of apps still matching
//   results   only real matches, best first (services/AppMatch.js, checked by tests/AppMatchTest.qml); the first row is
//             selected, so Enter opens the best match. A row: the app's icon (16 px), its name in body 500 with the
//             matched letters underlined, the generic name in textMuted, "open ↵" on the selected row
//   empty     the apps opened last under a RECENT eyebrow (none before the first launch)
//   no match  "No app matches “qzx”.", the ruler without fill; Enter does nothing
//   footer    the keys, in mono textFaint
// Keys: ↑↓ or Ctrl+N / Ctrl+P (or Ctrl+J / Ctrl+K) move, Page Up / Down by a page, Enter opens, Esc closes (PanelHost);
// hold Alt for the row numbers, Alt+1-9 opens that row (at once, without waiting for the numbers). The pointer moves the
// selection only when it moves: a list scrolling under a still pointer leaves the selection where the keys put it.
// Icons: an app in the Swiss app icons (design/app-icons, the owner's set of 16 October 2026) is its 16 px pictogram in
// ink, the selected row's too (the selected row is a pale fill, not the dark band design/app-icons assumes); any other
// app keeps its own icon in its own colours. Departure from the package: a right click on the NixOS mark opens the
// dashboard (Super+D), not the launcher.
// The calculator (this shell's addition, from Caelestia's launcher; not in design/launcher): a query starting with "="
// is a sum for qalc (libqalculate, from ~/nixos), not a search. "=2^10", "=12 km to mi", "=10 USD in EUR", "=3 h to
// min". It is asked calcSettle after typing pauses, one qalc at a time (a sum typed on meanwhile is asked when it
// ends, and the stale answer is dropped); the answer is one selected row, "=" in the icon slot and the value in mono
// ink, grouped as qalc groups it (1 048 576); Enter (or a click) copies it plain (1048576, "-" for qalc's "−") and
// closes. qalc's warning, if any, is a faint line under it ("Division by zero."); its error replaces the row in
// textMuted, like "No app matches". Without qalc installed, "calculator needs qalc". qalc runs with its own config and
// state folders in the shell's cache (it writes qalc.cfg on every run, which would otherwise land in the owner's
// ~/.config/qalculate), never updates exchange rates (no network: the rates shipped with it, or the owner's own if
// they run `qalc -e`), and gives single units ("7.456 mi", not "7 mi + 803 yd + …"). " in <unit>" at the end means
// " to <unit>", as people type it (qalc alone reads "in" as inches: "12 km in miles" came out 490 528 m³).
FocusScope {
    id: launcher

    readonly property int cardPadding: Theme.size.rule      // the rows run to the card's border
    readonly property int pad: Theme.space.s5

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)
    readonly property string q: input.text.trim()
    readonly property bool calc: q.startsWith("=")
    readonly property var results: q === "" ? AppMatch.recentApps(apps, Prefs.recent, Theme.launcher.recentCount)
                                 : calc ? [] : AppMatch.rank(apps, q, Prefs.recent, Theme.launcher.fuzzyMin)
    readonly property var current: results[view.currentIndex]
    property bool numbers: false                            // Alt held for altReveal

    // ---- The calculator -----------------------------------------------------------------------------------
    readonly property string sum: calc ? qalcInput(q.slice(1).trim()) : ""
    property var answer: null       // { value, copy, note } | { error } | { missing: true }; null until answered
    property string asked: ""       // the sum the running qalc was given
    onSumChanged: settle.restart()
    Timer { id: settle; interval: Theme.launcher.calcSettle; onTriggered: launcher.ask() }

    function qalcInput(s) {
        const m = /^(.*\S)\s+in\s+([^\s\d]\S*)$/.exec(s);
        return m ? m[1] + " to " + m[2] : s;
    }
    function ask() {
        if (sum === "") { answer = null; return; }
        if (qalc.running) return;                           // asked again when it ends
        asked = sum;
        qalc.command = ["sh", "-c",
            'command -v qalc >/dev/null || exit 127; o=$(qalc -t "$@"); c=$?; printf "%s\\n\\036\\n" "$o"; ' +
            'qalc "$@" 2>&1 | grep -E "^(error|warning): " | head -n 2; exit $c',
            "sh", "-m", String(Theme.launcher.calcLimit), "-s", "upxrates 0", "-s", "autoconversion 0",
            "-s", "digit grouping 1", "--", sum];      // "--": a sum such as "-e" is never read as an option (-exrates)
        qalc.running = true;
    }
    // qalc -t prints only the value and hides its messages, so a second, plain run gives the "error:" / "warning:"
    // lines (about 45 ms each). qalc exits 1 after an error ("sin(", "asdf qwer"), still printing a value.
    function readQalc(code, text) {
        if (code === 127) return { missing: true };
        const parts = text.split("\x1e\n");
        const value = (parts[0] ?? "").trim().split("\n").join(" ");
        const msgs = (parts[1] ?? "").split("\n");
        const error = msgs.find(l => l.startsWith("error: "));
        if (error || code !== 0 || value === "") return { error: error ? error.slice(7) : "qalc gave no answer." };
        const warning = msgs.find(l => l.startsWith("warning: "));
        return { value: value, note: warning ? warning.slice(9) : "",
                 copy: value.replace(/(\d) (?=\d)/g, "$1").replace(/ /g, " ").replace(/−/g, "-") };
    }
    function copyAnswer() {
        if (!answer || answer.copy === undefined) return;
        Quickshell.execDetached(["wl-copy", "--", answer.copy]);
        Panels.close();
    }
    Process {
        id: qalc
        environment: ({
            XDG_CONFIG_HOME: launcher.qalcHome + "/config",
            XDG_STATE_HOME: launcher.qalcHome + "/state"
        })
        stdout: StdioCollector { id: qalcOut }
        onExited: code => {
            if (launcher.asked === launcher.sum) launcher.answer = launcher.readQalc(code, qalcOut.text);
            else launcher.ask();                            // typed on meanwhile: this answer is stale
        }
    }
    readonly property string qalcHome: Theme.cacheDir + "/qalc"

    width: Theme.launcher.width - 2 * Theme.size.rule
    height: column.height
    focus: true

    // Made afresh on every open (PanelHost), so the field takes the keys each time.
    Component.onCompleted: input.forceActiveFocus()

    function move(by) {
        if (results.length === 0) return;
        view.currentIndex = Math.max(0, Math.min(results.length - 1, view.currentIndex + by));
        view.positionViewAtIndex(view.currentIndex, ListView.Contain);
    }
    // The row numbered n on screen (counted from the first row in view).
    function rowAt(n) { return results[view.firstVisible + n - 1] }
    function launch(entry) {
        if (!entry) return;
        const app = entry.app;
        Prefs.opened(app.id);
        Panels.close();
        Busy.start(app);                  // "starting" in the bar's title until its window opens
    }

    Timer { id: altTimer; interval: Theme.launcher.altReveal; onTriggered: launcher.numbers = true }

    Column {
        id: column
        width: parent.width

        // ---- The query -------------------------------------------------------------------------------
        // The glyph, the query and the count share one centre line, s2 above the ruler (as h2's line stands on it).
        Item {
            width: parent.width
            height: Theme.launcher.fieldH

            Icon {
                id: glyph
                x: launcher.pad
                anchors.verticalCenter: input.verticalCenter
                name: Theme.icons.search
            }
            TextInput {
                id: input
                anchors { left: glyph.right; leftMargin: Theme.space.s3; right: count.left; rightMargin: Theme.space.s3
                          bottom: parent.bottom; bottomMargin: Theme.space.s2 }
                height: Theme.font.h2.lineHeight
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.font.h2.family
                font.pixelSize: Theme.font.h2.size
                font.weight: Theme.font.h2.weight
                font.letterSpacing: Theme.font.h2.spacing
                color: Theme.colors.text
                selectionColor: Theme.colors.selection
                selectedTextColor: Theme.colors.text
                renderType: Text.NativeRendering
                clip: true
                focus: true
                // The caret: 2 px of ink, as tall as the type, steady.
                cursorDelegate: Rectangle {
                    width: Theme.size.marker
                    height: Theme.font.h2.size
                    y: Math.round((input.height - height) / 2)
                    color: Theme.colors.text
                    visible: input.activeFocus
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const alt = event.modifiers & Qt.AltModifier;
                    if (event.key === Qt.Key_Alt) { if (!event.isAutoRepeat) altTimer.restart(); }
                    else if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) launcher.launch(launcher.rowAt(event.key - Qt.Key_0));
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (launcher.calc) launcher.copyAnswer();
                        else launcher.launch(launcher.current);
                    }
                    else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_N || event.key === Qt.Key_J))) launcher.move(1);
                    else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_P || event.key === Qt.Key_K))) launcher.move(-1);
                    else if (event.key === Qt.Key_PageDown) launcher.move(Theme.launcher.maxRows);
                    else if (event.key === Qt.Key_PageUp) launcher.move(-Theme.launcher.maxRows);
                    else return;
                    event.accepted = true;
                }
                Keys.onReleased: event => {
                    if (event.key !== Qt.Key_Alt || event.isAutoRepeat) return;
                    altTimer.stop();
                    launcher.numbers = false;
                }

                Txt {
                    anchors.fill: parent
                    leftPadding: Theme.space.s1             // after the caret
                    visible: input.text.length === 0
                    variant: Theme.font.h2
                    text: "Search apps"
                    color: Theme.colors.textFaint
                }
            }
            Annot {
                id: count
                anchors { right: parent.right; rightMargin: launcher.pad; verticalCenter: input.verticalCenter }
                text: launcher.q === "" ? launcher.apps.length + (launcher.apps.length === 1 ? " app" : " apps")
                    : launcher.calc ? "calculator" : launcher.results.length + " of " + launcher.apps.length
            }
        }

        // ---- The ruler: the share of apps still matching ----------------------------------------------
        // A 1 px baseline, 8 px ticks at both ends, 4 px every pitch; the ink fill (3 px, centred on the baseline) is
        // matches / apps, none for an empty query or no match.
        Item {
            id: ruler
            x: launcher.pad
            width: parent.width - 2 * launcher.pad
            height: Theme.ruler.tickMajor + Theme.size.rule
            readonly property int base: Theme.ruler.tickMajor - Theme.ruler.tickW     // the baseline's row
            readonly property real share: launcher.q === "" || launcher.apps.length === 0 ? 0
                                        : launcher.results.length / launcher.apps.length

            Rectangle { y: ruler.base; width: ruler.width; height: Theme.ruler.tickW; color: Theme.colors.tick }
            Repeater {
                model: Math.floor((ruler.width - Theme.ruler.tickW) / Theme.ruler.pitch) + 1
                Rectangle {
                    required property int index
                    x: index * Theme.ruler.pitch
                    y: ruler.base + Theme.ruler.tickW - height
                    width: Theme.ruler.tickW
                    height: index === 0 ? Theme.ruler.tickMajor : Theme.ruler.tickMinor
                    color: Theme.colors.tick
                }
            }
            Rectangle {
                x: ruler.width - Theme.ruler.tickW
                y: ruler.base + Theme.ruler.tickW - height
                width: Theme.ruler.tickW
                height: Theme.ruler.tickMajor
                color: Theme.colors.tick
            }
            Rectangle {
                y: ruler.base - (Theme.ruler.fill - Theme.ruler.tickW) / 2
                width: Math.round(ruler.share * ruler.width)
                height: Theme.ruler.fill
                visible: width > 0
                color: Theme.colors.text
                Behavior on width { NumberAnimation { duration: Theme.motion.fast; easing.type: Easing.OutCubic } }
            }
        }

        // ---- The results ----------------------------------------------------------------------------
        Item { visible: launcher.results.length > 0; width: 1; height: Theme.space.s2 }
        Caps {
            visible: launcher.q === "" && launcher.results.length > 0
            x: launcher.pad
            topPadding: Theme.space.s3
            bottomPadding: Theme.space.s1
            text: "Recent"
        }
        Item {
            visible: launcher.results.length > 0
            width: parent.width
            height: view.height

            ListView {
                id: view
                width: parent.width
                height: Math.min(launcher.results.length, Theme.launcher.maxRows) * Theme.launcher.rowH
                clip: true
                model: launcher.results
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                readonly property int firstVisible: Math.max(0, indexAt(0, contentY + 1))
                // A new list (each keystroke) starts at its best match.
                onModelChanged: { currentIndex = 0; positionViewAtBeginning(); }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem
                    readonly property int number: index - view.firstVisible + 1
                    width: view.width
                    height: Theme.launcher.rowH

                    Rectangle {
                        anchors.fill: parent
                        color: row.selected ? Theme.colors.surfaceAlt : "transparent"
                    }
                    Annot {
                        id: num
                        x: Theme.space.s3
                        width: Theme.space.s4
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        visible: launcher.numbers && row.number >= 1 && row.number <= 9
                        text: row.number
                        color: Theme.colors.textFaint
                    }
                    // The app's Swiss drawing in ink (design/app-icons) when the set has one; otherwise the app's own icon.
                    // One that is only in an icon theme (this shell sets none, so tray and app icons stay the apps' own)
                    // gets the plain square instead of Quickshell's missing-image checkerboard.
                    IconImage {
                        id: icon
                        readonly property string path: Quickshell.iconPath(row.modelData.app.icon ?? "", true)
                        anchors { left: num.right; leftMargin: Theme.space.s3 }
                        y: (row.height - Theme.size.appIcon) / 2
                        implicitSize: Theme.size.appIcon
                        source: drawing.available ? "" : path
                        visible: path !== "" && !drawing.available
                    }
                    AppIcon {
                        id: drawing
                        anchors.fill: icon
                        name: row.modelData.app.icon ?? ""
                    }
                    Icon {
                        anchors.fill: icon
                        visible: icon.path === "" && !drawing.available
                        name: Theme.icons.noIcon
                        color: Theme.colors.textFaint
                    }
                    Underlined {
                        id: name
                        anchors { left: icon.right; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, open.x - Theme.space.s3 - x)
                        font.weight: Font.Medium
                        text: row.modelData.app.name
                        marks: row.modelData.marks
                    }
                    Underlined {
                        anchors { left: name.right; leftMargin: Theme.space.s3; right: open.left; rightMargin: Theme.space.s3
                                  verticalCenter: parent.verticalCenter }
                        text: AppMatch.shortGeneric(row.modelData.app)
                        marks: row.modelData.genericMarks
                        color: Theme.colors.textMuted
                    }
                    Annot {
                        id: open
                        anchors { right: parent.right; rightMargin: launcher.pad; verticalCenter: parent.verticalCenter }
                        opacity: row.selected ? 1 : 0
                        text: "open ↵"
                    }
                }
            }
            // The pointer: a move selects the row under it, a click opens it. Over the list rather than in each row,
            // so a list scrolling under a still pointer changes nothing (the first report only notes where it is).
            MouseArea {
                anchors.fill: view
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property point last: Qt.point(-1, -1)
                onPositionChanged: mouse => {
                    const moved = last.x >= 0 && (mouse.x !== last.x || mouse.y !== last.y);
                    last = Qt.point(mouse.x, mouse.y);
                    const i = view.indexAt(mouse.x, mouse.y + view.contentY);
                    if (moved && i >= 0) view.currentIndex = i;
                }
                onClicked: mouse => launcher.launch(launcher.results[view.indexAt(mouse.x, mouse.y + view.contentY)])
            }
        }
        Item { visible: launcher.results.length > 0; width: 1; height: Theme.space.s2 }

        Txt {
            visible: launcher.q !== "" && !launcher.calc && launcher.results.length === 0
            width: parent.width
            padding: launcher.pad
            text: "No app matches “" + launcher.q + "”."
            color: Theme.colors.textMuted
        }

        // ---- The calculator's answer (see the header) --------------------------------------------------------
        Item {
            id: answerRow
            readonly property bool shown: launcher.sum !== "" && launcher.answer !== null && launcher.answer.value !== undefined
            visible: shown
            width: parent.width
            height: shown ? Theme.launcher.rowH + 2 * Theme.space.s2 : 0

            Rectangle {
                y: Theme.space.s2
                width: parent.width
                height: Theme.launcher.rowH
                color: Theme.colors.surfaceAlt

                // "=" in the icon slot, where an app row has its icon (past the hidden number slot).
                Annot {
                    id: equals
                    x: Theme.space.s3 + Theme.space.s4 + Theme.space.s3
                    width: Theme.size.appIcon
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "="
                    color: Theme.colors.text
                }
                Annot {
                    anchors { left: equals.right; leftMargin: Theme.space.s3; right: copyHint.left; rightMargin: Theme.space.s3
                              verticalCenter: parent.verticalCenter }
                    text: answerRow.shown ? launcher.answer.value : ""
                    color: Theme.colors.text
                }
                Annot {
                    id: copyHint
                    anchors { right: parent.right; rightMargin: launcher.pad; verticalCenter: parent.verticalCenter }
                    text: "copy ↵"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcher.copyAnswer()
                }
            }
        }
        // Under the answer: qalc's warning. Instead of it: qalc's error, the missing qalc, or (only "=") what to type.
        Txt {
            readonly property var a: launcher.answer
            readonly property string line: !launcher.calc ? ""
                : launcher.sum === "" ? "2^10 · 12 km to mi · 10 USD to EUR · 3 h to min"
                : a === null ? ""
                : a.missing ? "calculator needs qalc"
                : a.error !== undefined ? a.error
                : a.note
            visible: line !== ""
            width: parent.width
            leftPadding: launcher.pad
            rightPadding: launcher.pad
            topPadding: answerRow.shown ? 0 : launcher.pad
            bottomPadding: answerRow.shown ? Theme.space.s3 : launcher.pad
            variant: launcher.sum === "" ? Theme.font.mono : Theme.font.body
            text: line
            color: a !== null && (a.missing || a.error !== undefined) && launcher.sum !== "" ? Theme.colors.textMuted
                                                                                         : Theme.colors.textFaint
        }

        // ---- The keys -------------------------------------------------------------------------------
        Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
        Annot {
            width: parent.width
            leftPadding: launcher.pad
            rightPadding: launcher.pad
            topPadding: Theme.space.s3
            bottomPadding: Theme.space.s3
            text: launcher.calc ? "↵ copy · esc close" : "↑↓ select · ↵ open · hold alt for numbers · esc close"
            color: Theme.colors.textFaint
        }
    }
}
