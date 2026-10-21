import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Now playing (design/swiss/components/NowPlaying), in the bar's right group:
//   zen +1  Subathon day 16 — It's our 14th…  ⏮ ⏸ ⏭
//           ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  the progress, on the bar rule
// The player id in mono (with +N in faint when there are several): a click goes to the player's window (the owner's wish,
// over the package's "click cycles"), a right click moves to the next player; the
// title slot, `Title — Artist` in label, at most 192 px (it shrinks for short text); previous / play-pause / next,
// 32 px each, fixed at the module's right edge so they never move when the track changes.
// A title longer than the slot scrolls inside it: it rests 1.5 s, then moves left at 32 px/s, followed by its copy
// 48 px later, so the loop has no jump; two loops after each track change, then it rests at the start, elided.
// Hovering it scrolls it again, and pauses it while the pointer stays (moving text must be stoppable: WCAG 2.2.2).
// Under reduced motion it never scrolls. The edges cut hard (no fades: no gradients here). The full text is in the
// tooltip. Paused: the title dims. Progress: a 3 px ink line on the bar rule under the slot, updated once a second,
// hidden for streams. Clicks: the title opens the media popover, a middle click plays / pauses; the wheel does
// nothing here (it is the volume's, on the speaker). With no player the module is absent.
Item {
    id: np
    property int maxWidth: 350

    readonly property var player: Media.player
    readonly property string text: Media.title + (Media.artist !== "" ? " — " + Media.artist : "")
    readonly property int textWidth: Math.ceil(metrics.advanceWidth)
    readonly property int roomForText: Math.max(0, maxWidth - idSlot.width - 2 * Theme.space.s2 - transport.width)
    readonly property int slotTextWidth: Math.min(Theme.size.npTextMax, textWidth, roomForText)
    readonly property bool overflow: textWidth > slotTextWidth
    readonly property bool hasLength: !!player && player.lengthSupported && player.length > 0

    visible: player !== null
    implicitWidth: idSlot.width + titleSlot.width + transport.width
    implicitHeight: Theme.bar.height

    TextMetrics { id: metrics; font: shown.font; text: np.text }

    // ---- The player id ----------------------------------------------------------------------------
    BarSlot {
        id: idSlot
        padding: Theme.space.s2
        tooltip: "Go to " + (np.player?.identity ?? "the player") + "'s window"
            + (Media.players.length > 1 ? " · right click: next player (" + Media.players.map(p => p.identity).join(", ") + ")" : "")
        onClicked: button => {
            if (button === Qt.LeftButton) Media.goTo(np.player);
            else if (button === Qt.RightButton) Media.cycle();
        }
        Row {
            height: Theme.bar.height
            spacing: Theme.space.s1
            Annot {
                anchors.baseline: parent.top
                anchors.baselineOffset: Theme.bar.baseline
                text: Media.idOf(np.player)      // "Mozilla Firefox" -> "firefox"
            }
            Annot {
                visible: Media.players.length > 1
                anchors.baseline: parent.top
                anchors.baselineOffset: Theme.bar.baseline
                text: "+" + (Media.players.length - 1)
                color: Theme.colors.textFaint
            }
        }
    }

    // ---- The title slot ---------------------------------------------------------------------------
    BarSlot {
        id: titleSlot
        x: idSlot.width
        panel: "media"
        padding: Theme.space.s2
        fixedWidth: np.slotTextWidth > 0 ? np.slotTextWidth + 2 * padding : 0
        visible: np.text !== ""
        tooltip: np.text + " · " + (np.player?.identity ?? "") + " · middle click " + (Media.playing ? "pauses" : "plays")
        onClicked: button => { if (button === Qt.MiddleButton && np.player?.canTogglePlaying) np.player.togglePlaying() }

        Item {
            id: clipper
            x: titleSlot.padding
            width: np.slotTextWidth
            height: parent.height
            clip: true
            readonly property color ink: Media.playing ? Theme.colors.text : Theme.colors.textMuted

            // At rest: the text, elided.
            Txt {
                id: shown
                visible: !marquee.running
                width: clipper.width
                anchors.baseline: parent.top
                anchors.baselineOffset: Theme.bar.baseline
                variant: Theme.font.label
                text: np.text
                color: clipper.ink
            }
            // Scrolling: the text and its copy, 48 px apart, moved left by one period per loop.
            Row {
                id: strip
                visible: marquee.running
                y: Theme.bar.baseline - first.baselineOffset
                spacing: Theme.motion.marqueeGap
                Txt { id: first; variant: Theme.font.label; text: np.text; color: clipper.ink; elide: Text.ElideNone }
                Txt { variant: Theme.font.label; text: np.text; color: clipper.ink; elide: Text.ElideNone }
            }
        }

        // Hover: at rest, scroll again (one loop); while scrolling, pause until the pointer leaves.
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    if (marquee.running && !marquee.paused) marquee.pause();
                    else if (!marquee.running) np.scroll(1);
                } else if (marquee.paused) {
                    marquee.resume();
                }
            }
        }
    }

    SequentialAnimation {
        id: marquee
        PauseAnimation { duration: Theme.motion.marqueeHold }
        NumberAnimation {
            target: strip
            property: "x"
            from: 0
            to: -(np.textWidth + Theme.motion.marqueeGap)
            duration: (np.textWidth + Theme.motion.marqueeGap) / Theme.motion.marqueeSpeed * 1000
            easing.type: Easing.Linear
        }
        onStopped: strip.x = 0
    }
    function scroll(loops) {
        marquee.stop();
        if (!np.overflow || Theme.reduceMotion) return;
        marquee.loops = loops;
        marquee.start();
    }
    // A new track (or a narrower slot): two loops, then rest.
    onTextChanged: scroll(2)
    onOverflowChanged: if (overflow) scroll(2); else marquee.stop()

    // ---- Transport ------------------------------------------------------------------------------------
    Row {
        id: transport
        x: titleSlot.visible ? titleSlot.x + titleSlot.width : idSlot.width
        GlyphButton {
            glyphY: Theme.bar.iconTop
            name: Theme.icons.prev
            enabled: np.player?.canGoPrevious ?? false
            onClicked: np.player.previous()
        }
        GlyphButton {
            glyphY: Theme.bar.iconTop
            name: Media.playing ? Theme.icons.pause : Theme.icons.play
            enabled: np.player?.canTogglePlaying ?? false
            onClicked: np.player.togglePlaying()
        }
        GlyphButton {
            glyphY: Theme.bar.iconTop
            name: Theme.icons.next
            enabled: np.player?.canGoNext ?? false
            onClicked: np.player.next()
        }
    }

    // ---- Progress: a 3 px ink line on the bar rule under the slot ------------------------------------------
    // A player just chosen (or paused) has a stale position until it is read again: read it at once.
    onPlayerChanged: if (player && player.positionSupported) player.positionChanged()
    Timer {
        running: np.visible && np.hasLength && Media.playing
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: np.player.positionChanged()
    }
    Rectangle {
        visible: np.hasLength && titleSlot.visible
        x: titleSlot.x + titleSlot.padding
        y: np.height - height
        width: np.hasLength ? Math.round(Math.max(0, Math.min(1, np.player.position / np.player.length)) * np.slotTextWidth) : 0
        height: Theme.size.progressW
        color: Theme.colors.text
    }
}
