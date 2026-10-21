import QtQuick
import qs

// SRuler, the system's signature: a 1 px baseline in the tick colour, an 8 px origin tick and a 4 px tick every
// pitch (8 px), the grid made visible. Short (32 px, four pitches) under a heading or an eyebrow; full width only where
// a scale means something. Stands on its own bottom edge; 8 px tall.
Item {
    id: ruler
    implicitWidth: Theme.ruler.short
    implicitHeight: Theme.ruler.tickMajor

    Rectangle {
        anchors.bottom: parent.bottom
        width: ruler.width
        height: Theme.ruler.tickW
        color: Theme.colors.tick
    }
    Repeater {
        model: Math.floor((ruler.width - Theme.ruler.tickW) / Theme.ruler.pitch) + 1
        Rectangle {
            required property int index
            x: index * Theme.ruler.pitch
            anchors.bottom: parent.bottom
            width: Theme.ruler.tickW
            height: index === 0 ? Theme.ruler.tickMajor : Theme.ruler.tickMinor
            color: Theme.colors.tick
        }
    }
}
