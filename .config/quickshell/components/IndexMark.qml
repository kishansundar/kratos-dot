import QtQuick
import qs

// A marker: a 2 px stroke in the accent (the clock's "now" stroke; the wallpaper picker's index, at its own height).
Rectangle {
    width: Theme.size.marker
    height: Theme.ruler.tickValue
    color: Theme.colors.accent
}
