import QtQuick
import QtQuick.Effects
import QtQuick.Window
import qs
import qs.services

// An app drawn by the Swiss app icons (design/app-icons; the files: assets/app-icons, listed by services/AppIcons):
// a one-colour pictogram painted in `color`, the text colour, so it follows Light and Dark at once. `name` is the
// app's icon name (as its desktop entry gives it, or AppIcons.trayName for a tray item). `available` is false when the
// set has no drawing for it: the caller then shows the app's own icon, in its own colours, as before.
// At 16 px and under the 16 px drawing (built on the glyphs' grid, for the tray and the launcher), above it the 48 px
// master. The colour goes through the drawing's alpha, never its own grey (MultiEffect's colorization of that grey is
// not `color`): a mask with min 0.5 and spread 1 runs the edge from alpha 0 to 1, so the anti-aliasing stays (the
// defaults cut it to hard pixels; see the gotcha on the mask's edge in CLAUDE.md).
Item {
    id: root
    property string name: ""
    property int size: Theme.size.appIcon
    property color color: Theme.colors.text

    readonly property string file: AppIcons.file(name, size)
    readonly property bool available: file !== ""

    implicitWidth: size
    implicitHeight: size
    visible: available

    Image {
        id: shape
        anchors.fill: parent
        visible: false
        layer.enabled: root.available
        source: root.file
        sourceSize: Qt.size(root.size * Screen.devicePixelRatio, root.size * Screen.devicePixelRatio)
        smooth: true
    }
    Rectangle {
        anchors.fill: parent
        color: root.color
        layer.enabled: root.available
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }
}
