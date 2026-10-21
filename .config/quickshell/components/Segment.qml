import QtQuick
import qs

// A choice of a few words in a row (the dashboard's holds, 30m · 1h · 2h · off; the wallpaper picker's sort, layout and
// shape): the chosen one in ink with a 2 px ink line under it, the others muted. Each is a 32 px target; Left / Right move the choice when focused.
Row {
    id: seg
    property var options: []
    property string current: ""
    signal picked(string value)

    Repeater {
        model: seg.options
        Item {
            id: opt
            required property string modelData
            readonly property bool chosen: modelData === seg.current
            width: word.implicitWidth + 2 * Theme.space.s2
            height: Theme.size.hitTarget
            activeFocusOnTab: true

            HoverFill { pressed: mouse.pressed; hovered: mouse.containsMouse }
            Txt {
                id: word
                anchors.centerIn: parent
                variant: opt.chosen ? Theme.font.labelStrong : Theme.font.label
                text: opt.modelData
                color: opt.chosen ? Theme.colors.text : Theme.colors.textMuted
            }
            Rectangle {
                visible: opt.chosen
                anchors.bottom: parent.bottom
                width: parent.width
                height: Theme.size.marker
                color: Theme.colors.text
            }
            FocusRing { visible: opt.activeFocus }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seg.picked(opt.modelData)
            }
            Keys.onPressed: event => {
                const i = seg.options.indexOf(seg.current);
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) seg.picked(opt.modelData);
                else if (event.key === Qt.Key_Left && i > 0) seg.picked(seg.options[i - 1]);
                else if (event.key === Qt.Key_Right && i < seg.options.length - 1) seg.picked(seg.options[i + 1]);
                else return;
                event.accepted = true;
            }
        }
    }
}
