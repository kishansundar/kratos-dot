import QtQuick
import qs

// A tooltip's box, the same wherever one shows (the bar, the Bluetooth and Now Playing panels, the dashboard, the
// dock's name label): the surface inside a hairline, around a label (`text`, at most `maxWidth` wide with the padding,
// cut at the end, or wrapping and centred when `wrap`) or content of its own, padded `padX` across and `padY` down, at
// least `minHeight` high. Where it shows, and when, stays with each place.
Rectangle {
    id: box
    property string text: ""
    property real maxWidth: Infinity
    property bool wrap: false
    property int padX: Theme.space.s2
    property int padY: Theme.space.s1
    property int minHeight: 0
    default property alias content: inner.data

    implicitWidth: Math.min(maxWidth, (text !== "" ? label.implicitWidth : inner.childrenRect.width) + 2 * padX)
    implicitHeight: Math.max(minHeight, (text !== "" ? label.implicitHeight : inner.childrenRect.height) + 2 * padY)
    color: Theme.colors.surface
    border.width: Theme.size.rule
    border.color: Theme.colors.line

    Txt {
        id: label
        visible: box.text !== ""
        anchors.centerIn: parent
        width: Math.min(implicitWidth, box.maxWidth - 2 * box.padX)
        variant: Theme.font.label
        wrapMode: box.wrap ? Text.Wrap : Text.NoWrap
        maximumLineCount: box.wrap ? undefined : 1
        horizontalAlignment: box.wrap ? Text.AlignHCenter : Text.AlignLeft      // a cut one-liner keeps its start
        text: box.text
    }
    Item { id: inner; x: box.padX; y: box.padY }
}
