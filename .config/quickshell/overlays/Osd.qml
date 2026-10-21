import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The level read-outs (Osd), one at a time in one place, a card 240 x 48 right-aligned directly under the bar; a new
// one replaces the old. Clicks pass through it.
//   volume       when the volume or mute changes (media keys, the wheel on the bar's speaker): "Volume" and "NN %" in
//                label on one line, a 2 px bar beneath (the line track, the accent fill). Muted: the word "Muted"
//                beside the label, not only a colour. Not shown while the sound panel is open.
//   brightness   (design/display Osd) the brightness keys or the wheel on the bar's sun: the sun, "Brightness", the
//                value as "NN %", and the accent fill, at once, as the volume's: the owner found the package's grey
//                "not confirmed yet" state weird (15 October 2026): it held for a second after the last press, then
//                turned red by itself. At a limit "· max" / "· min"; a failed write "· no answer" in the error colour,
//                and the value returns to the confirmed one. Not shown while the Display panel is open.
//   output       when the default output becomes another device (headphones taking over): "Output" and the device's
//                name, the 2 px bar beneath with its volume. Not shown while the sound panel is open (the choice was
//                made there). From Caelestia's "now using" notice.
// It stays 1.2 s after the last change (for brightness: or after the read-back, if later), then fades over 240 ms.
PanelWindow {
    id: osd
    screen: Panels.focusedScreen          // the focused monitor (else the first)
    visible: card.opacity > 0
    anchors { top: true; right: true }
    margins { top: 0; right: Theme.bar.padX }
    exclusionMode: ExclusionMode.Normal
    implicitWidth: Theme.size.osdWidth
    implicitHeight: Theme.size.osdHeight
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "swiss-osd"

    property string kind: "volume"
    function show(k, hold) {
        kind = k;
        fade.stop();
        card.opacity = 1;
        hide.interval = hold;
        hide.restart();
    }
    Connections {
        target: Audio
        function onChangedByUser() { if (Panels.current !== "audio") osd.show("volume", Theme.motion.osd) }
        function onOutputChanged() { if (Panels.current !== "audio") osd.show("output", Theme.motion.osd) }
    }
    Connections {
        target: Brightness
        function onStepped(index) { if (Panels.current !== "display") osd.show("brightness", Theme.display.osdHold) }
    }
    Timer { id: hide; interval: Theme.motion.osd; onTriggered: fade.restart() }
    NumberAnimation { id: fade; target: card; property: "opacity"; to: 0; duration: Theme.motion.slow; easing.type: Easing.InCubic }

    // The brightness being shown: the focused monitor's, once read (before that there is no value, only the note).
    readonly property var bctl: Brightness.ready ? Brightness.current.b : null
    readonly property bool bPending: Brightness.revision >= 0 && bctl !== null && bctl.target >= 0
    readonly property string bNote: Brightness.revision < 0 || !Brightness.ready
        ? (Brightness.pendingSteps !== 0 || Brightness.state === "unknown" ? "· looking for the monitor" : "· not available")
        : bctl.state === "failed" ? "· no answer" : Brightness.limit !== "" && !bPending ? "· " + Brightness.limit : ""

    Rectangle {
        id: card
        anchors.fill: parent
        opacity: 0
        color: Theme.colors.surface
        border.width: Theme.size.rule
        border.color: Theme.colors.line

        // ---- Volume ----
        Item {
            visible: osd.kind === "volume"
            anchors { fill: parent; leftMargin: Theme.space.s4; rightMargin: Theme.space.s4 }
            Txt {
                id: label
                y: Theme.space.s2
                variant: Theme.font.label
                text: "Volume"
            }
            Txt {
                anchors { left: label.right; leftMargin: Theme.space.s1; baseline: label.baseline }
                visible: Audio.muted
                variant: Theme.font.label
                text: "·  Muted"
                color: Theme.colors.textMuted
            }
            Txt {
                anchors { right: parent.right; baseline: label.baseline }
                variant: Theme.font.label
                text: Audio.percent + " %"
                color: Audio.muted ? Theme.colors.textMuted : Theme.colors.text
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Theme.space.s3 }
                height: Theme.size.marker
                color: Theme.colors.line
                Rectangle {
                    width: Math.round(Math.max(0, Math.min(1, Audio.volume)) * parent.width)
                    height: parent.height
                    color: Audio.muted ? Theme.colors.textFaint : Theme.colors.accent
                }
            }
        }

        // ---- Output: the device now playing, its volume beneath ----
        Item {
            visible: osd.kind === "output"
            anchors { fill: parent; leftMargin: Theme.space.s4; rightMargin: Theme.space.s4 }
            Txt {
                id: oLabel
                y: Theme.space.s2
                variant: Theme.font.label
                text: "Output"
            }
            Txt {
                anchors { left: oLabel.right; leftMargin: Theme.space.s2; right: parent.right; baseline: oLabel.baseline }
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                variant: Theme.font.label
                text: Audio.nodeName(Audio.sink)
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Theme.space.s3 }
                height: Theme.size.marker
                color: Theme.colors.line
                Rectangle {
                    width: Math.round(Math.max(0, Math.min(1, Audio.volume)) * parent.width)
                    height: parent.height
                    color: Audio.muted ? Theme.colors.textFaint : Theme.colors.accent
                }
            }
        }

        // ---- Brightness ----
        Item {
            visible: osd.kind === "brightness"
            anchors { fill: parent; leftMargin: Theme.space.s4; rightMargin: Theme.space.s4 }
            Icon {
                id: sun
                y: bLabel.y + Math.round((bLabel.height - height) / 2)
                name: Theme.icons.brightness
            }
            Txt {
                id: bLabel
                anchors { left: sun.right; leftMargin: Theme.space.s2 }
                y: Theme.space.s2
                variant: Theme.font.label
                text: "Brightness"
            }
            Txt {
                anchors { left: bLabel.right; leftMargin: Theme.space.s1; right: bValue.left; rightMargin: Theme.space.s2; baseline: bLabel.baseline }
                visible: osd.bNote !== ""
                variant: Theme.font.label
                text: osd.bNote
                color: Brightness.revision >= 0 && osd.bctl && osd.bctl.state === "failed" ? Theme.colors.error : Theme.colors.textMuted
            }
            Txt {
                id: bValue
                anchors { right: parent.right; baseline: bLabel.baseline }
                visible: osd.bctl !== null
                variant: Theme.font.label
                text: Brightness.percent(osd.bctl, Brightness.shown(osd.bctl)) + " %"
            }
            Rectangle {
                id: bTrack
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: Theme.space.s3 }
                height: Theme.size.marker
                color: Theme.colors.line
                Rectangle {
                    visible: osd.bctl !== null
                    width: osd.bctl && Brightness.revision >= 0 ? Math.round(Brightness.shown(osd.bctl) / Math.max(1, osd.bctl.max) * parent.width) : 0
                    height: parent.height
                    color: Theme.colors.accent
                }
            }
        }
    }
}
