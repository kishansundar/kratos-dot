import QtQuick
import qs

// The busy mark after the app id in the bar's title (the owner's busy-indicator package, 16 October 2026; its
// BusyMark on the shell's own parts): 16 x 16, the ruler motif.
//   working  a ruler scanner (a kitty command or Claude's turn, or any app starting): four 2 px ticks at x 1, 5, 9, 13
//            on a shared foot at y 14, resting 4 px tall in tick, the lit one 12 px tall in ink, sweeping 0 1 2 3 2 1,
//            a step each Theme.busy.step; reduce motion holds tick 1
// All four are centred in the box (the lit tick's 12 px too), and the bar centres the box on the title's text (the
// owner's choice, 16 October 2026, from a rendered A/B: centred on the text, not on the bar's icon line).
//   needs    the attention triangle (components/Mark, 8 px: (8,4) (12,12) (4,12)) in ink
//   done     the check glyph, textMuted
//   failed   the error glyph, the red
//   idle     nothing, and no slot: the title moves aside only while a mark shows (the owner's choice)
Item {
    id: root

    property string mode: "idle"          // idle | working | needs | done | failed

    implicitWidth: Theme.size.icon
    implicitHeight: Theme.size.icon

    Accessible.role: Accessible.Indicator
    Accessible.name: root.mode === "idle" ? "" : root.mode

    // ---- working ----------------------------------------------------------------------------------------------
    property int phase: 1
    readonly property int step: [0, 1, 2, 3, 2, 1][root.phase]
    Timer {
        interval: Theme.busy.step
        repeat: true
        running: root.mode === "working" && !Theme.reduceMotion && root.visible
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
            y: 14 - height                // the shared foot: the 12 px lit tick centred in the box
            color: lit ? Theme.colors.text : Theme.colors.tick
        }
    }

    // ---- needs you --------------------------------------------------------------------------------------------
    Mark {
        visible: root.mode === "needs"
        kind: "triangle"
        x: (root.width - width) / 2
        y: (root.height - height) / 2
    }

    // ---- done / failed ----------------------------------------------------------------------------------------
    Icon {
        visible: root.mode === "done" || root.mode === "failed"
        name: root.mode === "failed" ? Glyphs.error : Glyphs.check
        color: root.mode === "failed" ? Theme.colors.accent : Theme.colors.textMuted
    }
}
