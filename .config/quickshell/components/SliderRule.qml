import QtQuick
import qs

// The ruler both sliders draw (RulerSlider, DdcSlider), filling its slider: a 1 px baseline in the tick colour 8 px
// above the foot, 8 px ticks at 0, 50 and 100 % and 4 px every 10 % (`divisions`, `majorEvery`; `ticks: false`
// leaves the origin tick), a 3 px fill from the origin to `value` centred on the baseline, and the 2 x 16 px value
// tick as the handle. What a slider adds between fill and handle (DdcSlider's confirmed value) goes inside it.
Item {
    id: rule
    property real value: 0                  // 0-1
    property color ink: Theme.colors.text   // the fill
    property color handleColor: ink
    property bool ticks: true
    property bool showFill: true
    property bool showHandle: true
    property int divisions: 10
    property int majorEvery: 5
    default property alias between: between.data
    readonly property int base: height - 8              // y of the baseline

    anchors.fill: parent

    Repeater {
        model: rule.ticks ? rule.divisions + 1 : 1
        Rectangle {
            required property int index
            x: Math.round(index / rule.divisions * (rule.width - 1))
            y: rule.base - height
            width: Theme.ruler.tickW
            height: index % rule.majorEvery === 0 ? Theme.ruler.tickMajor : Theme.ruler.tickMinor
            color: Theme.colors.tick
        }
    }
    Rectangle { x: 0; y: rule.base; width: rule.width; height: Theme.ruler.tickW; color: Theme.colors.tick }
    // The fill, 3 px centred on the baseline.
    Rectangle {
        visible: rule.showFill
        x: 0
        y: rule.base - 1
        width: Math.round(rule.value * rule.width)
        height: Theme.ruler.fill
        color: rule.ink
    }
    Item { id: between; anchors.fill: parent }
    // The value tick: the handle.
    Rectangle {
        visible: rule.showHandle
        x: Math.round(rule.value * (rule.width - width))
        y: rule.base + 2 - height
        width: Theme.size.marker
        height: Theme.ruler.tickValue
        color: rule.handleColor
        Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
    }
}
