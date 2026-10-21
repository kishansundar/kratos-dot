import QtQuick
import qs

// SMeter, a read-only measure:
//   Memory                                              11.2 / 31.3 GiB      label (body) left, value (label 600) right
//   ┃━━━━━━━━━━━━━━━━━┃─────────────────────────────────────────          baseline, 3 px fill, 2 x 16 px value tick
//   resets in 2h 57m · Thu 05:00                                           metadata (mono), optional
// No scale ticks: a meter reads a value, it is not set (the slider carries the scale). `value` < 0: unknown (no fill,
// the value "–"). Past `warnAt` an ink triangle stands on the value tick and the note leads with `nearWord` ("near
// limit"); the fill stays ink (no colour change). Used by the Claude popover's plan limits (panels/ClaudePanel).
Item {
    id: meter
    property string label: ""
    property real value: -1
    property string valueText: value < 0 ? "–" : Math.round(value * 100) + " %"
    property string note: ""
    property real warnAt: 2
    property bool near: value > warnAt        // or the caller's own rule (the Claude popover's: ClaudeUsage.near)
    property string nearWord: "near limit"

    readonly property real v: Math.max(0, Math.min(1, value))
    readonly property string fullNote: [near ? nearWord : "", note].filter(w => w !== "").join(" · ")

    width: parent ? parent.width : 200
    height: fullNote !== "" ? 60 : 40          // label 0-20, meter 20-40, note 40-60

    Txt {
        id: labelText
        anchors { left: parent.left; right: valueLabel.left; rightMargin: Theme.space.s3; top: parent.top }
        height: Theme.font.body.lineHeight
        text: meter.label
    }
    Txt {
        id: valueLabel
        anchors { right: parent.right; baseline: labelText.baseline }
        variant: Theme.font.labelStrong
        text: meter.valueText
        color: Theme.colors.text
    }
    Item {
        id: track
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 20 }
        height: 20
        readonly property int base: 14
        readonly property int tickX: Math.round(meter.v * (track.width - Theme.size.marker))
        Rectangle { y: track.base; width: track.width; height: Theme.ruler.tickW; color: Theme.colors.tick }
        Rectangle { y: track.base - height + 1; width: Theme.ruler.tickW; height: Theme.ruler.tickMajor; color: Theme.colors.tick }
        Rectangle {
            visible: meter.value >= 0
            y: track.base - 1
            width: Math.round(meter.v * track.width)
            height: Theme.ruler.fill
            color: Theme.colors.text
        }
        // The value tick; near the limit it is shorter and the triangle stands on it (16 px in all).
        Rectangle {
            visible: meter.value >= 0
            x: track.tickX
            y: track.base + 2 - height
            width: Theme.size.marker
            height: meter.near ? Theme.ruler.tickValue - Theme.size.markTriangle : Theme.ruler.tickValue
            color: Theme.colors.text
        }
        Mark {
            visible: meter.value >= 0 && meter.near
            kind: "triangle"
            x: Math.round(track.tickX + Theme.size.marker / 2 - width / 2)
            y: track.base + 2 - Theme.ruler.tickValue
        }
    }
    Annot {
        visible: meter.fullNote !== ""
        anchors { left: parent.left; right: parent.right; top: track.bottom }
        height: Theme.font.mono.lineHeight
        text: meter.fullNote
        color: Theme.colors.textMuted
    }
}
