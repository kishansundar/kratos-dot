import QtQuick
import Quickshell
import qs
import qs.services

// A panel's footer (design/panels Parts): a 1 px rule, a text button at the left ("network settings": what doesn't
// fit in the panel is handed to the system's settings app), and the backend in mono textFaint at the right. With
// `command`, the button runs it and closes the panel; otherwise it emits clicked().
Item {
    id: footer
    property string action: ""
    property var command: []
    property string backend: ""
    signal clicked()

    width: parent ? parent.width : 0
    height: Theme.space.s3 + Theme.size.hitTarget

    Rectangle {
        width: parent.width
        height: Theme.size.rule
        color: Theme.colors.line
    }
    TextButton {
        id: button
        visible: footer.action !== ""
        anchors { left: parent.left; bottom: parent.bottom }
        text: footer.action
        onClicked: {
            if (footer.command.length > 0) { Quickshell.execDetached(footer.command); Panels.close(); }
            else footer.clicked();
        }
    }
    Annot {
        anchors { left: button.visible ? button.right : parent.left; leftMargin: Theme.space.s3; right: parent.right
                  verticalCenter: button.verticalCenter }
        horizontalAlignment: Text.AlignRight
        text: footer.backend
        color: Theme.colors.textFaint
    }
}
