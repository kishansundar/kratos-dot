import QtQuick
import qs
import qs.components

// A group of the dashboard (design/dashboard v2 Section): a caps label in ink on a 1 px ink rule, the group's scale or
// count at the right in mono, muted; hitTarget (32) tall with the label 4 px above the rule. The content starts right
// under the rule. The one heading style of the sheet: Compute, Memory, Heat, Network, Processes, Storage, Controls.
Column {
    id: section
    property string title: ""
    property string meta: ""
    default property alias content: body.data

    Item {
        width: section.width
        height: Theme.size.hitTarget
        Caps {
            anchors { left: parent.left; bottom: rule.top; bottomMargin: Theme.space.s1 }
            text: section.title
            color: Theme.colors.text
        }
        Annot {
            anchors { right: parent.right; bottom: rule.top; bottomMargin: Theme.space.s1 }
            height: Theme.font.mono.lineHeight
            verticalAlignment: Text.AlignBottom
            text: section.meta
        }
        Rectangle { id: rule; anchors.bottom: parent.bottom; width: parent.width; height: Theme.size.rule; color: Theme.colors.text }
    }
    Column {
        id: body
        width: section.width
    }
}
