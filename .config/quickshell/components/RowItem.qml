import QtQuick
import qs

// A list row: 32 px (the hit target), padding 12 px (s3), text in body, flush left.
//   hover / `selected` (the keyboard's row)   the surfaceAlt fill        pressed   the line fill
//   `radio: true`   a choice among several (audio devices, networks, Bluetooth devices, players): a circle first,
//                   filled ink when `checked` (the one chosen / in use / connected), a 2 px ink ring when not; the
//                   content starts 12 px after it. Ink, not red: the red stays for the view's one active thing.
//   `interactive: false`   an information row: no hover, no click
//   `busy: true`   a command for this row is running: the caller puts "…" after the name; clicks are ignored
// The row's MouseArea lies under its content, so a control inside the row (a slider, a switch, a glyph button) takes
// its own presses and a press anywhere else falls through to the row. (Over the content, it took every press: no
// slider in a row could be dragged and no switch in a row could be switched.)
Item {
    id: row
    property bool selected: false
    property bool radio: false
    property bool checked: false
    property bool enabled: true
    property bool interactive: true
    property bool busy: false
    property int inset: Theme.space.s3
    default property alias content: inner.data
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    signal activated()
    signal rightClicked()      // a row's own menu (remove a device, a clock)
    signal middleClicked()
    signal hoveredIn()

    width: parent ? parent.width : 0
    height: Theme.size.hitTarget

    HoverFill { disabled: !row.interactive || !row.enabled; pressed: mouse.pressed; hovered: row.hovered || row.selected }
    Mark {
        visible: row.radio
        x: row.inset
        anchors.verticalCenter: parent.verticalCenter
        kind: row.checked ? "circle" : "ring"
        color: row.enabled ? Theme.colors.text : Theme.states.disabled
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.enabled && row.interactive
        cursorShape: row.busy ? Qt.BusyCursor : Qt.PointingHandCursor
        onEntered: row.hoveredIn()
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) row.rightClicked();
            else if (mouse.button === Qt.MiddleButton) row.middleClicked();
            else if (!row.busy) row.activated();
        }
    }
    Item {
        id: inner
        anchors { fill: parent; leftMargin: row.inset + (row.radio ? Theme.size.markCircle + Theme.space.s3 : 0); rightMargin: row.inset }
    }
}
