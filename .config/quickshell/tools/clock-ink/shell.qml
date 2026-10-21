import QtQuick
import Quickshell

// Clock ink probe: renders every string the bar's clock can show, in the clock's own styles, so measure.py can read
// where each one's ink really starts and ends (Qt's TextMetrics tight box is off by about 1 px against the hinted,
// natively rendered glyphs). The styles copy Theme.font.count and Theme.font.label and Txt's settings: keep them in
// step. Run it on a scale-1 output (`quickshell -p tools/clock-ink/shell.qml`, PROBE_DARK=1 for the dark colours),
// capture the window with grim, then run measure.py on the light and dark captures; see README.md.
ShellRoot {
    id: root
    readonly property bool dark: Quickshell.env("PROBE_DARK") === "1"
    readonly property color ink: dark ? "#f2f2ee" : "#111111"
    readonly property color ground: dark ? "#0d0d0d" : "#f4f4f1"
    readonly property var counts: Array.from({ length: 60 }, (_, n) => String(n).padStart(2, "0"))
    readonly property var days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    readonly property var dates: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

    component Probe: Text {
        required property int index
        required property string modelData
        property bool big: true
        text: modelData
        color: root.ink
        font.family: "Geist"
        font.pixelSize: big ? 22 : 12
        font.weight: big ? Font.Bold : Font.Medium
        font.letterSpacing: big ? -0.44 : 0.24
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }

    PanelWindow {
        anchors { top: true; left: true }
        implicitWidth: 1000
        implicitHeight: 400
        color: root.ground
        // Layout read by measure.py: counts in rows of 10 at x 20 + 80 k, y 20 + 40 r; weekdays at x 20 + 120 k, y 280;
        // date digits at x 20 + 40 k, y 320.
        Repeater { model: root.counts; Probe { x: 20 + (index % 10) * 80; y: 20 + Math.floor(index / 10) * 40 } }
        Repeater { model: root.days; Probe { big: false; x: 20 + index * 120; y: 280 } }
        Repeater { model: root.dates; Probe { big: false; x: 20 + index * 40; y: 320 } }
    }
}
