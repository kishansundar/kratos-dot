import QtQuick
import QtQuick.Shapes

// 16 × 16 busy mark that sits after the app id in the title module.
//
//   working  ruler scanner: four 2 px ticks, one ink tick sweeps back and forth
//   needs    8 px ink triangle (attention)
//   done     check glyph, textMuted
//   failed   error glyph, accent
//   idle     nothing (the slot stays, so the title never shifts)
//
// Theme names used: text, textMuted, tick, accent. Map them to your Theme singleton.
Item {
    id: root

    property string mode: "idle"          // idle | working | needs | done | failed
    property bool reduceMotion: false     // true: the scanner holds still
    property int stepMs: 150              // one tick per step, 6 steps per sweep

    implicitWidth: 16
    implicitHeight: 16

    Accessible.role: Accessible.Indicator
    Accessible.name: root.mode === "idle" ? "" : root.mode

    // ── working ───────────────────────────────────────────────────
    property int phase: 1
    readonly property int step: [0, 1, 2, 3, 2, 1][root.phase]

    Timer {
        interval: root.stepMs
        repeat: true
        running: root.mode === "working" && !root.reduceMotion && root.visible
        onTriggered: root.phase = (root.phase + 1) % 6
        onRunningChanged: if (!running) root.phase = 1
    }

    Repeater {
        model: 4
        Rectangle {
            required property int index
            readonly property bool lit: index === root.step
            visible: root.mode === "working"
            x: 1 + index * 4
            width: 2
            height: lit ? 12 : 4
            y: 14 - height                // shared foot at y = 14
            color: lit ? Theme.text : Theme.tick
        }
    }

    // ── needs you ─────────────────────────────────────────────────
    Shape {
        visible: root.mode === "needs"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.text
            strokeColor: "transparent"
            strokeWidth: 0
            startX: 8; startY: 4
            PathLine { x: 12; y: 12 }
            PathLine { x: 4; y: 12 }
            PathLine { x: 8; y: 4 }
        }
    }

    // ── done / failed ─────────────────────────────────────────────
    Text {
        visible: root.mode === "done" || root.mode === "failed"
        anchors.centerIn: parent
        text: root.mode === "failed" ? Glyphs.error : Glyphs.check
        font.family: "Swiss Glyphs"
        font.pixelSize: 16
        color: root.mode === "failed" ? Theme.accent : Theme.textMuted
    }
}
