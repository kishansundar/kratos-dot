import QtQuick
import qs
import qs.services

// The sound panel's level (design/panels VolumePanel, Output and Input): a mute button showing the level glyph
// (volume-mute, volume-0…2; mic / mic-off with `mic: true`), the ruler slider (a scale every 10 %, ink fill, the value
// tick), and "NN %" in label, tabular, at the right. Muted: fill and value in textFaint, and the word "muted" beneath in
// mono, so the state is never colour alone. Sliders stop at 100 % (Audio.setVolume); the wheel steps 5 %. The keyboard
// is the panel's (`selected`: its row, the surfaceAlt fill; ←→ change the level there).
Column {
    id: level
    property var node
    property bool mic: false
    property bool selected: false
    signal picked()

    readonly property bool hasAudio: !!(node && node.audio)
    readonly property real value: hasAudio ? node.audio.volume : 0
    readonly property bool muted: hasAudio ? node.audio.muted : false

    width: parent ? parent.width : 0

    Item {
        width: parent.width
        height: Theme.size.hitTarget

        HoverFill { hovered: level.selected }
        HoverHandler { onHoveredChanged: if (hovered) level.picked() }

        GlyphButton {
            id: mute
            enabled: level.hasAudio
            activeFocusOnTab: false
            name: level.mic ? (level.muted ? Theme.icons.micOff : Theme.icons.mic)
                : level.muted ? Theme.icons.volumeMuted
                : Theme.icons.volume[level.value <= 0 ? 0 : level.value < 0.5 ? 1 : 2]
            color: level.muted || !level.hasAudio ? Theme.colors.textFaint : Theme.colors.text
            onClicked: Audio.toggleMute(level.node)
        }
        RulerSlider {
            anchors { left: mute.right; leftMargin: Theme.space.s1; right: percent.left; rightMargin: Theme.space.s3 }
            height: parent.height
            activeFocusOnTab: false
            interactive: level.hasAudio
            value: level.value
            dimmed: level.muted
            onMoved: v => Audio.setVolume(level.node, v)
        }
        Txt {
            id: percent
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: widest.implicitWidth
            horizontalAlignment: Text.AlignRight
            variant: Theme.font.label
            text: level.hasAudio ? Math.round(level.value * 100) + " %" : "–"
            color: level.muted || !level.hasAudio ? Theme.colors.textFaint : Theme.colors.text
        }
        // The widest the value gets, so the slider never moves as the number changes.
        Txt { id: widest; visible: false; variant: Theme.font.label; text: "100 %" }
    }
    Annot {
        visible: level.muted
        topPadding: Theme.space.s1
        bottomPadding: Theme.space.s2
        text: "muted"
    }
}
