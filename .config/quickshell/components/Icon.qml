import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs

// SIcon: one glyph of Swiss Glyphs (made in design/glyphs, loaded from assets/fonts), the system's own icon font:
// drawn on a 16 px grid with 2 px features, so it is always 16 px (or a whole multiple) and placed on whole pixels.
// `name` is a Glyphs.<name> character (Theme.icons says which means what). A level is a glyph (wifi0-4, volume0-2), never a tint.
// A name starting with "svg:" is a file in assets/icons instead, filled in `color`: Claude's own mark, the one
// product mark kept in the bar, drawn like a glyph: in ink, inside the glyphs' 14 px live area (1 px clear of the box).
Item {
    id: icon
    property string name: ""
    property color color: Theme.colors.text
    property int size: Theme.size.icon

    readonly property bool isSvg: name.startsWith("svg:")

    implicitWidth: size
    implicitHeight: size

    Text {
        visible: !icon.isSvg
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        text: icon.isSvg ? "" : icon.name
        color: icon.color
        font.family: Theme.font.icon
        font.pixelSize: icon.size
        renderType: Text.NativeRendering
        lineHeightMode: Text.FixedHeight
        lineHeight: icon.size
    }

    // An SVG mark in the glyphs' live area: 14 px, 1 px in, on whole pixels (at the full 16 it outsized every glyph).
    // Built only for an "svg:" name (Claude's mark), not for every glyph.
    Loader {
        anchors.fill: parent
        active: icon.isSvg
        sourceComponent: Item {
            FileView {
                id: file
                path: Quickshell.shellDir + "/assets/icons/" + icon.name.slice(4) + ".svg"
                blockLoading: true
                printErrors: true
            }
            // Drawn once in white and coloured on the GPU (colorization takes white to `color` exactly, edges
            // included): a new colour (light / dark, amber) shows in the same frame. With the colour written into the
            // SVG, each change was a new picture to load, and the mark blinked out (or stood a frame in the old colour
            // on the new ground).
            Image {
                id: mark
                visible: false
                x: 1
                y: 1
                width: icon.size - 2
                height: icon.size - 2
                source: file.text() ? "data:image/svg+xml;utf8," + encodeURIComponent(file.text().replace("<svg", '<svg fill="#ffffff"')) : ""
                sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                smooth: true
            }
            MultiEffect {
                x: mark.x
                y: mark.y
                width: mark.width
                height: mark.height
                source: mark
                colorization: 1
                colorizationColor: icon.color
            }
        }
    }
}
