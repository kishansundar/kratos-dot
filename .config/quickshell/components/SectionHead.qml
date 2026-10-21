import QtQuick
import qs

// An eyebrow: one word in capitals (OUTPUT, DEVICE, NETWORK) with the short ruler 4 px under it, optional mono
// metadata at the right, or controls. 32 px: the word 0-16, the ruler 20-28, 4 px to the content.
Item {
    id: head
    property string title: ""
    property string annotation: ""
    default property alias trailing: trailingRow.data

    width: parent ? parent.width : 0
    height: 32

    Caps {
        id: word
        anchors { left: parent.left; top: parent.top }
        height: Theme.font.caps.lineHeight
        text: head.title
    }
    Annot {
        anchors { left: word.right; leftMargin: Theme.space.s3; right: trailingRow.left
                  rightMargin: trailingRow.children.length > 0 ? Theme.space.s3 : 0; verticalCenter: word.verticalCenter }
        horizontalAlignment: Text.AlignRight
        text: head.annotation
    }
    Row {
        id: trailingRow
        anchors { right: parent.right; verticalCenter: word.verticalCenter }
        spacing: Theme.space.s4
    }
    Ruler {
        y: Theme.font.caps.lineHeight + Theme.space.s1
    }
}
