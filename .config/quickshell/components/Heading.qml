import QtQuick
import qs

// A popover's title: h2 on the column, mono metadata at its right ("2 active sessions"), or controls (a switch, a
// text button); the short ruler 4 px under the title. 40 px: title 0-24, ruler 28-36, 4 px to the content.
Item {
    id: heading
    property string title: ""
    property string annotation: ""
    default property alias trailing: trailingRow.data

    width: parent ? parent.width : 0
    height: 40

    Txt {
        id: titleText
        anchors { left: parent.left; top: parent.top }
        height: Theme.font.h2.lineHeight
        variant: Theme.font.h2
        text: heading.title
    }
    Annot {
        anchors { left: titleText.right; leftMargin: Theme.space.s3; right: trailingRow.left
                  rightMargin: trailingRow.children.length > 0 ? Theme.space.s3 : 0; verticalCenter: titleText.verticalCenter }
        horizontalAlignment: Text.AlignRight
        text: heading.annotation
    }
    Row {
        id: trailingRow
        anchors { right: parent.right; verticalCenter: titleText.verticalCenter }
        spacing: Theme.space.s4
    }
    Ruler {
        y: Theme.font.h2.lineHeight + Theme.space.s1
    }
}
