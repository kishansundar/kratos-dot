import QtQuick
import QtQuick.Shapes
import qs

// The three marks (README "Marks"), in ink only:
//   "circle"    a filled circle: on / selected                 (markCircle, 8 px; the one rounded thing)
//   "ring"      a 2 px ring: off / not selected
//   "triangle"  an upward triangle: attention; always with a word nearby ("near limit", "weak", "urgent")
// `color` is the ink (Theme.colors.text), or the ground (Theme.colors.bg) on an inverted fill.
Item {
    id: mark
    property string kind: "circle"
    property color color: Theme.colors.text

    implicitWidth: kind === "triangle" ? Theme.size.markTriangle : Theme.size.markCircle
    implicitHeight: implicitWidth

    Rectangle {
        visible: mark.kind !== "triangle"
        anchors.fill: parent
        radius: width / 2
        color: mark.kind === "circle" ? mark.color : "transparent"
        border.width: mark.kind === "ring" ? Theme.size.marker : 0
        border.color: mark.color
        antialiasing: true
    }
    Shape {
        visible: mark.kind === "triangle"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: mark.color
            startX: mark.width / 2; startY: 0
            PathLine { x: mark.width; y: mark.height }
            PathLine { x: 0; y: mark.height }
            PathLine { x: mark.width / 2; y: 0 }
        }
    }
}
