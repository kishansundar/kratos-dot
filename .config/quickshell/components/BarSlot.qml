import QtQuick
import Quickshell
import qs
import qs.services

// One clickable place in the bar: the bar's full height, at least 32 px wide (the hit target). Hover: the surfaceAlt
// fill; pressed: line; while its popover is open, the surfaceAlt fill stays.
//   panel    the popover a left click toggles, hung from this slot (a keyboard shortcut hangs it from the slot of that
//            name on the focused monitor: services/Panels)
//   tooltip  text shown under the slot after a short hover (`tipDelay`; the tray row's wait a little longer)
// Content goes inside; the slot is `fixedWidth` wide, or as wide as its content plus `padding` on each side.
Item {
    id: slot

    property string panel: ""
    property string tooltip: ""
    property int tipDelay: Theme.motion.tooltipDelay
    property int padding: Theme.space.s2
    property int fixedWidth: -1
    // Where its popover hangs from: the slot's middle, unless a slot names a better point (the clock: its stroke).
    property real anchorX: width / 2
    // Where a popover hung from the left of the slot puts its left edge (the NixOS mark: on the mark, not its hit area).
    property real hangLeft: 0
    readonly property bool active: panel !== "" && Panels.current === panel
    default property alias content: inner.data
    readonly property bool hovered: mouse.containsMouse

    signal clicked(int button)
    signal scrolled(int steps)

    implicitWidth: fixedWidth > 0 ? fixedWidth : Math.max(Theme.size.hitTarget, inner.childrenRect.width + 2 * padding)
    implicitHeight: Theme.bar.height

    Component.onCompleted: if (panel !== "") Panels.register(panel, slot)
    Component.onDestruction: if (panel !== "") Panels.unregister(panel, slot)

    HoverFill { anchors.bottomMargin: Theme.size.rule; pressed: mouse.pressed; hovered: slot.active || slot.hovered }

    // Fixed slots: content fills the slot (centre it with anchors). Sized slots: content is centred in the slot.
    Item {
        id: inner
        x: slot.fixedWidth > 0 ? 0 : Math.round((slot.width - childrenRect.width) / 2)
        width: slot.fixedWidth > 0 ? slot.width : childrenRect.width
        height: parent.height
    }

    // The tip, after a hover. On show it follows its text (the volume changes under the pointer, a track changes). A
    // press takes it away until the pointer leaves: a click that changes what it says (light / dark) would otherwise
    // show the new words, re-centred, as the desktop recolours.
    property bool tipQuiet: false
    function updateTip() {
        const w = QsWindow.window;
        if (!w || !w.showTip) return;
        if (hovered && tooltip !== "" && !tipQuiet) w.showTip(slot, tooltip, tipDelay);
        else w.hideTip(slot);
    }
    onHoveredChanged: { if (!hovered) tipQuiet = false; updateTip(); }
    onTooltipChanged: if (hovered) updateTip()

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: { slot.tipQuiet = true; slot.updateTip(); }
        onClicked: event => {
            if (event.button === Qt.LeftButton && slot.panel !== "") Panels.toggle(slot.panel, slot);
            slot.clicked(event.button);
        }
        // A touchpad sends small deltas: add them up to whole wheel notches. A notch takes the tip away until the
        // pointer leaves, as a press does: what the wheel changes has its own read-out (the OSD).
        property real accumulated: 0
        onWheel: event => {
            accumulated += event.angleDelta.y;
            const steps = Math.trunc(accumulated / 120);
            if (steps !== 0) { accumulated -= steps * 120; slot.tipQuiet = true; slot.updateTip(); slot.scrolled(steps); }
        }
    }
}
