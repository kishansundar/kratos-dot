import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// The tag ruler (Tags): the focused tag's number in count, its layout (bar/LayoutMark, a plan of the panes: the
// owner's ask, 20 October 2026), then one 2 px tick per tag, 12 px apart, standing on the bar's baseline (no "/9"
// total: the owner removed "3 /9" on 15 October and asked for the number alone back that evening, as in their
// reference):
//   3 ◫  ı ı ┃ ı · · · · ·
// State reads by height first, colour second:
//   empty 4 px (tick colour)   occupied 12 px (ink)   focused 16 px (accent: like the clock's "now" and the
//   day ruler's elapsed line, the bar's one red)   urgent 12 px (ink) capped with the attention triangle (the shape is the signal)
// Hover raises a tick to 16 px, so you see which tag a click will hit, and a tooltip names it. Click: view the tag;
// middle click: add it to the view or take it out; right click: move the focused window to it. The wheel anywhere on
// the ruler steps to the previous / next tag. The ticks are made once; mango's updates change heights and colours.
//
// A switch is measured out like a tape (Caelestia's workspace indicator, its leading and trailing edges, in the
// ruler's terms): a 2 px red line on the baseline runs from the tick that was focused to the one now focused. Its
// leading edge takes motion.med and its trailing edge half as long again, so the line stretches out from the old
// tag, reaches the new one, which only then stands red at full height, and draws in after it, ending under the
// focused tick's foot. The old tick drops to its state height at once; the number changes at once.
Item {
    id: folio
    required property var monitor

    readonly property int count: monitor ? monitor.tag_num : 9      // mango tag_num (9 since 15 October 2026)
    readonly property int current: {
        const t = monitor ? monitor.tags.find(t => t.is_active) : null;
        return t ? t.index : 1;
    }

    // ---- The tape: its two edges, in px from the first tick's cell; at rest both hug the focused tick ----
    function stemX(i) { return i * Theme.ruler.tagPitch + Math.round(Theme.ruler.tagPitch / 2 - Theme.size.marker / 2) }
    property real tapeA: stemX(current - 1)
    property real tapeB: stemX(current - 1) + Theme.size.marker
    property bool arriving: false            // the leading edge is still on its way: the new tick waits
    property bool placed: false              // the first focused tag (at start, or when the monitor appears) is set, not run to
    readonly property bool known: !!(monitor && monitor.tags && monitor.tags.length > 0)
    onCurrentChanged: {
        const to = stemX(current - 1);
        if (!placed || !known) {
            leadMove.stop(); trail.stop();
            tapeA = to; tapeB = to + Theme.size.marker;
            placed = known;
            return;
        }
        const right = to > tapeA;
        leadMove.stop(); trail.stop();
        leadMove.property = right ? "tapeB" : "tapeA";
        leadMove.to = right ? to + Theme.size.marker : to;
        trailMove.property = right ? "tapeA" : "tapeB";
        trailMove.to = right ? to : to + Theme.size.marker;
        arriving = true;
        leadMove.start(); trail.start();
    }
    Component.onCompleted: placed = known
    // The leading edge runs motion.med; the trailing edge holds at the old tick for half that, then follows over
    // motion.med (1.5 x in all), so the line first spans old to new, then draws in. Ease out, no overshoot.
    NumberAnimation {
        id: leadMove
        target: folio; duration: Theme.motion.med; easing.type: Easing.OutCubic
        onFinished: folio.arriving = false
    }
    SequentialAnimation {
        id: trail
        PauseAnimation { duration: Theme.motion.med / 2 }
        NumberAnimation { id: trailMove; target: folio; duration: Theme.motion.med; easing.type: Easing.OutCubic }
    }

    // A wheel notch up: the previous tag; down: the next.
    function step(steps) { Mango.view(Math.max(1, Math.min(folio.count, folio.current - steps))) }

    implicitWidth: ticks.x + ticks.width
    implicitHeight: Theme.bar.height

    // The wheel, anywhere on the ruler: previous / next tag.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton          // the wheel only: clicks go to the ticks
        property real accumulated: 0
        onWheel: event => {
            accumulated += event.angleDelta.y;
            const steps = Math.trunc(accumulated / 120);
            if (steps !== 0) {
                accumulated -= steps * 120;
                folio.step(steps);
            }
        }
    }

    // The focused tag's number, on the bar's baseline with the clock's numerals.
    Txt {
        id: numeral
        // Over the layout's hover fill, which starts at the numeral's advance: a 4 or an 8 inks a pixel past it.
        z: 1
        anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline }
        variant: Theme.font.count
        text: folio.current
    }

    // The tag's layout (bar/LayoutMark), s2 after the numeral: the two read as one ("1" in dwindle).
    LayoutMark {
        id: layout
        x: numeral.width + Theme.space.s2 - padding
        symbol: folio.monitor ? folio.monitor.layout_symbol ?? "" : ""
        visible: symbol !== ""
        onStepped: steps => folio.step(steps)
    }

    Row {
        id: ticks
        // moduleGap from the numeral (or the layout after it) to the first tick's ink, not its 12 px cell (the tick
        // stands 5 px into it).
        x: (layout.visible ? layout.x + layout.width - layout.padding : numeral.width) + Theme.bar.moduleGap
           - (Theme.ruler.tagPitch - Theme.size.marker) / 2
        height: parent.height

        Repeater {
            model: folio.count

            Item {
                id: tick
                required property int index
                readonly property var tag: folio.monitor ? folio.monitor.tags[index] ?? null : null
                // While the tape runs to it, the newly focused tick keeps its old look.
                readonly property bool isCurrent: (tag ? tag.is_active : index === 0)
                                                  && !(folio.arriving && index === folio.current - 1)
                readonly property bool isUrgent: tag ? tag.is_urgent : false
                readonly property bool occupied: tag ? tag.client_count > 0 : false
                readonly property color ink: tick.isCurrent ? Theme.colors.accent
                                           : tick.occupied || tick.isUrgent ? Theme.colors.text : Theme.colors.tick
                readonly property int tall: tick.isCurrent || hit.containsMouse ? Theme.ruler.tagActive
                                          : tick.occupied || tick.isUrgent ? Theme.ruler.tagOccupied : Theme.ruler.tagEmpty

                width: Theme.ruler.tagPitch
                height: parent.height

                Rectangle {
                    id: stem
                    x: Math.round(parent.width / 2 - Theme.size.marker / 2)
                    y: Theme.bar.baseline - height
                    width: Theme.size.marker
                    height: tick.tall
                    color: tick.ink
                    // The tick the tape lands on takes the red at once; the one it left fades as before.
                    Behavior on color {
                        enabled: !Theme.recolouring && tick.index !== folio.current - 1
                        ColorAnimation { duration: Theme.motion.fast }
                    }
                }
                // Urgent: the attention triangle caps the tick (ink: the shape is the signal, not a colour).
                Mark {
                    visible: tick.isUrgent && !tick.isCurrent
                    kind: "triangle"
                    x: Math.round(parent.width / 2 - width / 2)
                    y: stem.y - height - 1
                }
                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        const n = tick.index + 1;
                        if (event.button === Qt.MiddleButton) Mango.dispatch(["toggleview", n]);
                        else if (event.button === Qt.RightButton) Mango.dispatch(["tag", n, 0]);
                        else Mango.view(n);
                    }
                    // A press takes the tip away until the pointer leaves (as BarSlot's).
                    property bool tipQuiet: false
                    onPressed: { tipQuiet = true; updateTip(); }
                    onContainsMouseChanged: { if (!containsMouse) tipQuiet = false; updateTip(); }
                    function updateTip() {
                        const w = QsWindow.window;
                        if (!w || !w.showTip) return;
                        if (containsMouse && !tipQuiet) w.showTip(tick, "Tag " + (tick.index + 1)
                            + (tick.occupied ? " · " + tick.tag.client_count + (tick.tag.client_count === 1 ? " window" : " windows") : " · empty")
                            + (tick.isUrgent ? " · urgent" : "")
                            + " · middle: show too · right: move window here");
                        else w.hideTip(tick);
                    }
                }
            }
        }
    }

    // The tape, over the ticks' feet (rows baseline-2..baseline-1), in the Row's frame so it follows the numeral's
    // width. At rest it lies under the focused tick's own foot and is not drawn.
    Item {
        x: ticks.x
        Rectangle {
            visible: folio.tapeB - folio.tapeA > Theme.size.marker + 0.5
            x: Math.round(folio.tapeA)
            y: Theme.bar.baseline - Theme.size.marker
            width: Math.round(folio.tapeB) - Math.round(folio.tapeA)
            height: Theme.size.marker
            color: Theme.colors.accent
        }
    }
}
