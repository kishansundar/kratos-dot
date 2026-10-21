import QtQuick
import qs

// The Display panel's ruler slider (design/display Brightness): RulerSlider's scale, fill and handle, for a value the
// monitor has to confirm. A DDC write is slow and can fail, so:
//   confirmed   ink fill and handle at `value` (0-1, what the monitor last read back)
//   dragging    fill and handle follow the pointer in textMuted; nothing is sent until release (released(v))
//   sending     `pending` (0-1, or < 0 for none) in textMuted, until the read-back agrees
// While dragging or sending, a faint 1 px tick (pendingTick tall) stays at the confirmed value. Click jumps (sent on
// release, like a drag); ↑ / ↓ emit stepped(±1), the wheel stepped(n) by whole notches. No red: the handle stays ink
// when hovered (the panel has no accent). `ticks: false` draws only the origin tick.
Item {
    id: slider
    property real value: 0
    property real pending: -1
    property bool ticks: true
    property bool enabled: true
    signal released(real value)
    signal stepped(int steps)

    property real drag: -1
    readonly property bool dragging: area.pressed
    readonly property real shownValue: Math.max(0, Math.min(1, dragging ? drag : pending >= 0 ? pending : value))
    readonly property bool unconfirmed: dragging || pending >= 0
    readonly property color ink: !enabled ? Theme.states.disabled : unconfirmed ? Theme.colors.textMuted : Theme.colors.text

    implicitWidth: 200
    implicitHeight: Theme.size.hitTarget
    activeFocusOnTab: enabled

    SliderRule {
        id: rule
        value: slider.shownValue
        ink: slider.ink
        ticks: slider.ticks
        // The confirmed value, faint, while another is on its way.
        Rectangle {
            visible: slider.unconfirmed
            x: Math.round(Math.max(0, Math.min(1, slider.value)) * (slider.width - width))
            y: rule.base + 1 - height
            width: Theme.ruler.tickW
            height: Theme.display.pendingTick
            color: Theme.colors.textFaint
        }
    }
    // Keyboard focus: a 2 px accent outline, inset (the one rule for focus, everywhere).
    FocusRing { visible: slider.activeFocus }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: slider.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, x / slider.width)) }
        onPressed: event => { slider.drag = at(event.x) }
        onPositionChanged: event => { if (pressed) slider.drag = at(event.x) }
        onReleased: event => { slider.released(at(event.x)); slider.drag = -1 }
        onCanceled: slider.drag = -1
        // A step a wheel notch (120 of angleDelta); a touchpad's small deltas add up to notches. A sideways scroll, or
        // one that cannot move the value (at its end), is passed on, so a Flickable around the slider scrolls instead.
        property real accumulated: 0
        onWheel: event => {
            const y = event.angleDelta.y;
            if (y === 0 || (y > 0 ? slider.shownValue >= 1 : slider.shownValue <= 0)) {
                accumulated = 0; event.accepted = false; return;
            }
            accumulated += y;
            const steps = Math.trunc(accumulated / 120);
            if (steps !== 0) { accumulated -= steps * 120; slider.stepped(steps); }
        }
    }
    Keys.onPressed: event => {
        if (!slider.enabled) return;
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Right) slider.stepped(1);
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Left) slider.stepped(-1);
        else return;
        event.accepted = true;
    }
}
