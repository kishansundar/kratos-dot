import QtQuick
import Quickshell
import qs

// The bar's lower edge as a 24-hour ruler (kept from "Measure" by the owner's choice; it is also the package's "bar
// rule"): a hairline from 00:00 to 24:00 and an hourly tick, 8 px at 00, 06, 12 and 18, 4 px between. The part of
// the day already gone is the hairline in red, so the time of day reads as a length; a red tick (marker wide,
// major-tick tall) stands where it ends: now. Now Playing's 3 px ink track progress (size.progressW) lies over it under
// the title and stays its own line, 2 px taller. The owner's pick from renders on 15 October 2026 (the line in the tick colour was
// too faint; a 3 px ink fill was too heavy and hid the track progress). The scale spans the bar inside its
// 8 px padding (mango's window gap, so window edges stand on 00:00 and 24:00): 00:00 sits under the NixOS mark (the origin), 12:00 under the clock's stroke, 24:00 under the power
// glyph. It changes once a minute.
Item {
    id: ruler

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property real day: (clock.hours * 60 + clock.minutes) / 1440

    // The hairline runs from the 00:00 tick to the 24:00 tick (window edge to window edge), not into the padding.
    Rectangle {
        width: ruler.width
        anchors.bottom: parent.bottom
        height: Theme.size.rule
        color: Theme.colors.line
    }
    // The day so far, from 00:00 to now: the hairline in red.
    Rectangle {
        width: Math.round(ruler.day * (ruler.width - 1))
        anchors.bottom: parent.bottom
        height: Theme.size.rule
        color: Theme.colors.accent
    }
    Repeater {
        model: 25
        Rectangle {
            required property int index
            readonly property bool quarter: index % 6 === 0
            // 12:00 sits under the clock's stroke (both on the screen's centre): as wide as the stroke and exactly under
            // it, so the stroke runs on into the ruler as one line (a 1 px tick sat under its right half).
            readonly property bool noon: index === 12
            x: noon ? Math.round(ruler.width / 2 - Theme.size.marker / 2) : Math.round(index / 24 * (ruler.width - 1))
            anchors.bottom: parent.bottom
            width: noon ? Theme.size.marker : Theme.ruler.tickW
            height: quarter ? Theme.ruler.tickMajor : Theme.ruler.tickMinor
            color: quarter || index / 24 <= ruler.day ? Theme.colors.tick : Theme.colors.line
        }
    }
    // Now: the red tick at the fill's end.
    Rectangle {
        x: Math.round(ruler.day * (ruler.width - 1)) - Theme.size.marker / 2
        anchors.bottom: parent.bottom
        width: Theme.size.marker
        height: Theme.ruler.tickMajor
        color: Theme.colors.accent
    }
}
