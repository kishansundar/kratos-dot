import QtQuick
import qs
import qs.services

// One app playing sound (design/panels VolumePanel, Apps): its name in body with "NN %" at the right, a ruler without a
// scale under them (the origin tick only, ink fill, the value tick: drag or wheel to set it), and what it plays (the
// stream's media name) in mono, textMuted. Muted: fill and value textFaint, and "muted" after the media name.
// The keyboard is the panel's (`selected`: its entry; ←→ change the level, M mutes).
Item {
    id: app
    property var node
    property bool selected: false
    signal picked()

    readonly property bool hasAudio: !!(node && node.audio)
    readonly property real value: hasAudio ? node.audio.volume : 0
    readonly property bool muted: hasAudio ? node.audio.muted : false
    readonly property string media: Audio.mediaName(node)

    width: parent ? parent.width : 0
    height: lines.implicitHeight

    // The keyboard's entry: the surfaceAlt fill behind all three lines.
    HoverFill { hovered: app.selected }
    HoverHandler { onHoveredChanged: if (hovered) app.picked() }

    Column {
        id: lines
        width: parent.width

        Item {
            width: parent.width
            height: Theme.font.body.lineHeight
            Txt {
                anchors { left: parent.left; right: percent.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: Audio.appName(app.node)
            }
            Txt {
                id: percent
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                variant: Theme.font.label
                text: app.hasAudio ? Math.round(app.value * 100) + " %" : "–"
                color: app.muted || !app.hasAudio ? Theme.colors.textFaint : Theme.colors.text
            }
        }
        RulerSlider {
            width: parent.width
            height: Theme.size.hitTarget
            activeFocusOnTab: false
            ticks: false
            interactive: app.hasAudio
            value: app.value
            dimmed: app.muted
            onMoved: v => Audio.setVolume(app.node, v)
        }
        Annot {
            visible: text !== ""
            width: parent.width
            text: [app.media, app.muted ? "muted" : ""].filter(s => s !== "").join(" · ")
        }
    }
}
