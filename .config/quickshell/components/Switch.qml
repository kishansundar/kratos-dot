import QtQuick
import qs

// An on/off control as the system's mark (README "Marks"): a filled ink circle when on, a 2 px ink ring when off, and
// the state in a word beside it ("on", "off", lower case as in design/panels Parts), so it never rests on a colour. 32 px tall (the hit target); hover
// surfaceAlt, keyboard focus a 2 px accent outline. Space or Enter switches it when focused. `word` replaces On / Off
// where the state has a name of its own (the Now Playing modes: "shuffle", "repeat", "repeat one").
Item {
    id: sw
    property bool checked: false
    property bool enabled: true
    property string word: ""
    signal toggled()

    implicitWidth: row.implicitWidth + 2 * Theme.space.s2
    implicitHeight: Theme.size.hitTarget
    activeFocusOnTab: enabled

    HoverFill { disabled: !sw.enabled; pressed: mouse.pressed; hovered: mouse.containsMouse }
    Row {
        id: row
        x: Theme.space.s2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.s2
        Mark {
            anchors.verticalCenter: parent.verticalCenter
            kind: sw.checked ? "circle" : "ring"
            color: sw.enabled ? Theme.colors.text : Theme.states.disabled
        }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            variant: Theme.font.label
            text: sw.word !== "" ? sw.word : sw.checked ? "on" : "off"
            color: sw.enabled ? Theme.colors.text : Theme.states.disabled
        }
    }
    FocusRing { visible: sw.activeFocus }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: sw.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
    Keys.onPressed: event => {
        if (sw.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            sw.toggled();
            event.accepted = true;
        }
    }
}
