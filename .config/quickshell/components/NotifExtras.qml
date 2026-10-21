import QtQuick
import qs

// What a notification adds under its text, the same in a toast (NotificationCard) and in the centre (NotifItem): a
// progress the sender reports (the "value" hint: a download, a copy), the mini meter's ruler across with its percent
// in mono, following each update the sender makes; then the sender's actions as text buttons.
Column {
    id: extras
    property real progress: -1          // 0-1; below 0 for none
    property var actions: []
    signal acted(var action)
    width: parent ? parent.width : 0

    Item {
        visible: extras.progress >= 0
        width: parent.width
        height: visible ? Theme.font.mono.lineHeight + Theme.space.s1 : 0
        MiniMeter {
            anchors { left: parent.left; right: percent.left; rightMargin: Theme.space.s3; bottom: percent.baseline }
            value: extras.progress
        }
        Txt {
            id: percent
            anchors { right: parent.right; bottom: parent.bottom }
            variant: Theme.font.mono
            text: Math.round(extras.progress * 100) + " %"
            color: Theme.colors.textMuted
        }
    }
    Row {
        visible: extras.actions.length > 0
        topPadding: Theme.space.s1
        spacing: Theme.space.s5
        Repeater {
            model: extras.actions
            TextButton {
                required property var modelData
                text: modelData.text
                onClicked: extras.acted(modelData)
            }
        }
    }
}
