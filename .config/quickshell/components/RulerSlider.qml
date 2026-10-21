import QtQuick
import qs

// SSlider: a ruler with a scale. A 1 px baseline in the tick colour, 8 px ticks at 0, 50 and 100 %, 4 px every 10 %;
// a 3 px ink fill from the origin, centred on the baseline; a 2 x 16 px ink value tick as the handle, red while it is
// hovered or dragged (the one active thing at that moment). Click or drag to set, the wheel steps 5 %; with the
// keyboard focus, arrows step 1 % and Page Up / Page Down 10 %. `interactive: false` makes it a read-out (the OSD);
// `dimmed` (muted) draws fill and handle in the faint colour. The value as a number is the caller's (to the right).
// `ticks: false` leaves only the origin tick (a meter: the player's volume); `showValue: false` draws the scale alone,
// no fill and no handle (a live stream has no position). `hovered` and `hoverValue` (0-1 under the pointer) let the
// caller show what a click would set. `showHandle: false` keeps the fill but no handle (a read-only position).
// `accentHandle: false` keeps the handle ink when hovered, dragged or focused (a view whose one red thing is
// elsewhere: the Now Playing panel). `divisions` and `majorEvery` set the scale (10 and 5: every 10 %, long at 0 / 50 /
// 100 %); `keyStep` is an arrow key's step (0.01).
Item {
    id: slider
    property real value: 0
    property bool dimmed: false
    property bool interactive: true
    property bool ticks: true
    property bool showValue: true
    property bool accentHandle: true
    property bool showHandle: true
    property int divisions: 10
    property int majorEvery: 5
    property real keyStep: 0.01
    signal moved(real value)
    readonly property bool hovered: area.containsMouse
    readonly property real hoverValue: Math.max(0, Math.min(1, area.mouseX / width))

    readonly property bool engaged: interactive && (area.containsMouse || area.pressed)
    readonly property real v: Math.max(0, Math.min(1, value))
    readonly property alias base: rule.base             // y of the baseline
    readonly property color ink: dimmed ? Theme.colors.textFaint : Theme.colors.text

    implicitWidth: 200
    implicitHeight: Theme.size.hitTarget
    activeFocusOnTab: interactive

    function set(x) { slider.moved(Math.max(0, Math.min(1, x))) }

    SliderRule {
        id: rule
        value: slider.v
        ink: slider.ink
        handleColor: slider.accentHandle && (slider.engaged || slider.activeFocus) ? Theme.colors.accent : slider.ink
        ticks: slider.ticks
        divisions: slider.divisions
        majorEvery: slider.majorEvery
        showFill: slider.showValue
        showHandle: slider.showValue && slider.showHandle
    }
    // Keyboard focus: a 2 px accent outline, inset.
    FocusRing { visible: slider.activeFocus }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: slider.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => slider.set(event.x / slider.width)
        onPositionChanged: event => { if (pressed) slider.set(event.x / slider.width) }
        // 5 % a wheel notch (120 of angleDelta); a touchpad's small deltas add up to notches. A sideways scroll, or one
        // that cannot move the value (at its end), is passed on, so a Flickable around the slider scrolls instead.
        property real accumulated: 0
        onWheel: event => {
            const y = event.angleDelta.y;
            if (y === 0 || (y > 0 ? slider.v >= 1 : slider.v <= 0)) { accumulated = 0; event.accepted = false; return; }
            accumulated += y;
            const steps = Math.trunc(accumulated / 120);
            if (steps !== 0) { accumulated -= steps * 120; slider.set(slider.v + steps * 0.05); }
        }
    }
    Keys.onPressed: event => {
        if (!slider.interactive) return;
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Up) slider.set(slider.v + slider.keyStep);
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Down) slider.set(slider.v - slider.keyStep);
        else if (event.key === Qt.Key_PageUp) slider.set(slider.v + 0.1);
        else if (event.key === Qt.Key_PageDown) slider.set(slider.v - 0.1);
        else return;
        event.accepted = true;
    }
}
