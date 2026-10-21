import QtQuick
import qs

// The press / hover fill every control shares: `pressed` first, then `hovered` (the pointer, or a state that reads as
// hover: a bar slot whose popover is open, a selected row), else nothing; nothing at all while `disabled`. Its colour
// fades over motion.fast like every other change, except while the whole desktop recolours (a mode switch). It fills
// its parent; a caller trims it with anchors margins (the bar's slots and the process rows leave their bottom rule).
Rectangle {
    property bool pressed: false
    property bool hovered: false
    property bool disabled: false
    anchors.fill: parent
    color: disabled ? "transparent" : pressed ? Theme.states.pressed : hovered ? Theme.states.hover : "transparent"
    Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
}
