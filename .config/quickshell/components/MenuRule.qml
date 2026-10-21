import QtQuick
import qs

// A menu's separator: a hairline in the line colour, `gap` above it and below it (the power and dock menus' s2; the
// tray menu's entries s1).
Item {
    id: rule
    property int gap: Theme.space.s2
    width: parent ? parent.width : 0
    height: 2 * gap + Theme.size.rule
    Rectangle { y: rule.gap; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
}
