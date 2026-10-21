import QtQuick
import qs

// The keyboard focus ring a control draws over itself while it has the focus (bind `visible` to its activeFocus): a
// Theme.states.focusWidth outline in the focus colour on the control's own edges (TextButton widens it by its bleed).
Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: Theme.states.focusWidth
    border.color: Theme.states.focus
}
