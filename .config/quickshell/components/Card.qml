import QtQuick
import qs

// SPopup's sheet: the surface, a 1 px line border, square, 24 px (s5) padding. Popovers are `popupWidth` (384) wide,
// so their column is 336; the launcher, the clipboard and the dashboard are wider.
Rectangle {
    id: card
    property int padding: Theme.space.s5
    default property alias content: inner.data

    implicitWidth: inner.childrenRect.width + 2 * padding
    implicitHeight: inner.childrenRect.height + 2 * padding
    color: Theme.colors.surface
    border.width: Theme.size.rule
    border.color: Theme.colors.line
    radius: Theme.size.radius

    Item {
        id: inner
        x: card.padding
        y: card.padding
        width: childrenRect.width
        height: childrenRect.height
    }
}
