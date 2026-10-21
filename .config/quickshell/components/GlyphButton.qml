import QtQuick
import qs

// A glyph that is a control (mute, previous / next): 32 x 32, the glyph centred on whole pixels, hover surfaceAlt,
// pressed line, keyboard focus a 2 px accent outline. Only where the glyph is the clearest word for the action.
Item {
    id: gb
    property alias name: glyph.name
    property alias color: glyph.color
    property bool enabled: true
    property int glyphY: (height - Theme.size.icon) / 2      // in the bar: Theme.bar.iconTop, on the baseline
    signal clicked()

    implicitWidth: Theme.size.hitTarget
    implicitHeight: Theme.size.hitTarget
    activeFocusOnTab: enabled

    HoverFill { disabled: !gb.enabled; pressed: mouse.pressed; hovered: mouse.containsMouse }
    Icon {
        id: glyph
        x: (gb.width - width) / 2
        y: gb.glyphY
        color: gb.enabled ? Theme.colors.text : Theme.states.disabled
    }
    FocusRing { visible: gb.activeFocus }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: gb.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: gb.clicked()
    }
    Keys.onPressed: event => {
        if (gb.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            gb.clicked();
            event.accepted = true;
        }
    }
}
