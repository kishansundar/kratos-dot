import QtQuick
import qs

// SButton: a word, not an icon (unless the icon disambiguates), at least 32 px tall, square.
//   kind "text"     no border; its word flush with the item's edges (so it lines up with the column it stands in),
//                   the hover fill reaching 8 px past it: notification actions, Clear all, Today
//   kind "framed"   a 1 px line border, 12 px padding: an ordinary action
//   kind "primary"  the accent fill, onAccent word: the view's one primary action (Connect, Pair)
// States: hover surfaceAlt, pressed line, keyboard focus a 2 px accent outline (inset), disabled faint and inert.
// `hint`: a key or an arrow in mono after the word ("↗": opens something outside this popover).
Item {
    id: button
    property string text: ""
    property string hint: ""
    property string kind: "text"
    property bool enabled: true
    property color color: kind === "primary" ? Theme.colors.textOnAccent : Theme.colors.text
    signal clicked()

    readonly property int pad: kind === "text" ? 0 : Theme.space.s3
    readonly property int bleed: kind === "text" ? Theme.space.s2 : 0

    implicitWidth: row.implicitWidth + 2 * pad
    implicitHeight: Theme.size.hitTarget
    activeFocusOnTab: enabled

    Rectangle {
        anchors { fill: parent; leftMargin: -button.bleed; rightMargin: -button.bleed }
        color: button.kind === "primary" ? (mouse.pressed ? Qt.darker(Theme.colors.accent, 1.15) : Theme.colors.accent)
             : !button.enabled ? "transparent" : mouse.pressed ? Theme.states.pressed : mouse.containsMouse ? Theme.states.hover : "transparent"
        border.width: button.kind === "framed" ? Theme.size.rule : 0
        border.color: Theme.colors.line
        opacity: button.kind === "primary" && !button.enabled ? 0.5 : 1
        Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
    }
    FocusRing { visible: button.activeFocus; anchors { leftMargin: -button.bleed; rightMargin: -button.bleed } }
    Row {
        id: row
        x: button.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.s1
        Txt {
            text: button.text
            color: button.enabled ? button.color : Theme.states.disabled
        }
        Annot {
            visible: button.hint !== ""
            text: button.hint
            color: button.enabled ? Theme.colors.textMuted : Theme.states.disabled
        }
    }
    MouseArea {
        id: mouse
        anchors { fill: parent; leftMargin: -button.bleed; rightMargin: -button.bleed }
        enabled: button.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
    Keys.onPressed: event => {
        if (button.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            button.clicked();
            event.accepted = true;
        }
    }
}
