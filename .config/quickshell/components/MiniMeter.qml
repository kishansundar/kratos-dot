import QtQuick
import qs

// The mini meter (design/panels Parts): a miniMeter (32 px) ruler for a device's battery: the 1 px baseline in the
// tick colour, an ink fill (rulerFill, 3 px) on it to the value. `value` 0-1; below 0 nothing is drawn. The percent
// beside it is the caller's (mono), and so is the attention triangle under 20 %.
Item {
    id: meter
    property real value: -1
    readonly property real v: Math.max(0, Math.min(1, value))

    implicitWidth: Theme.panel.miniMeter
    implicitHeight: Theme.ruler.fill + 1

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.ruler.tickW
        color: Theme.colors.tick
    }
    Rectangle {
        visible: meter.value >= 0
        anchors.bottom: parent.bottom
        width: Math.max(Theme.size.marker, Math.round(meter.v * parent.width))
        height: Theme.ruler.fill
        color: Theme.colors.text
    }
}
