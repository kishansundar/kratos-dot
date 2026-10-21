import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Sound (design/panels VolumePanel; the speaker in the bar, or Super+Ctrl+A): system volume. A player's own volume
// lives in the Now Playing panel.
//   heading   "Sound", the server and the sample rate in mono at the right
//   OUTPUT    the mute button with the level glyph, the ruler slider, "NN %"; the outputs as rows (filled circle = the
//             default; a Bluetooth output carries the Bluetooth glyph): choose one to make it the default
//   INPUT     the same with the microphone; muted, the fill and value turn faint and the word "muted" stands beneath
//   APPS      one entry per app playing sound (name, "NN %", a ruler without scale, what it plays); hidden when nothing
//             plays, the eyebrow counts them
//   footer    "sound settings" (pavucontrol, when installed) and the rate
// Levels stop at 100 % and step 5 % (Theme.panel.volumeMax, volumeStep); output changes made here show in the OSD.
// Keys: ↑↓ or Tab choose a row, ←→ change its level by 5 %, M mutes it, Enter makes a device the default (or mutes a
// level), Esc closes.
// The lists are keyed by node (ScriptModel): a node appearing or leaving (a notification sound, an app starting) keeps
// every other row, so a slider being dragged stays under the pointer.
Column {
    id: panel
    width: Theme.panel.column
    focus: true

    Component.onCompleted: Audio.detailed = true
    Component.onDestruction: Audio.detailed = false

    readonly property real step: Theme.panel.volumeStep / 100
    readonly property string rateText: Audio.rate <= 0 ? "" : (Audio.rate / 1000) + " kHz"

    // Rows the keyboard walks through, in reading order.
    readonly property var rows: (Audio.ready ? [{ kind: "output", node: Audio.sink }] : [])
        .concat(Audio.sinks.map(n => ({ kind: "sink", node: n })))
        .concat(Audio.hasSource ? [{ kind: "input", node: Audio.source }] : [])
        .concat(Audio.sources.map(n => ({ kind: "source", node: n })))
        .concat(Audio.streams.map(n => ({ kind: "app", node: n })))
    property int current: -1        // nothing until the keyboard or the pointer chooses a row
    function isCurrent(node, kind) { const r = rows[current]; return !!r && r.kind === kind && r.node === node }
    function pick(node, kind) { const i = rows.findIndex(r => r.kind === kind && r.node === node); if (i >= 0) current = i }

    Keys.onPressed: event => {
        const r = rows[current];
        const level = r && (r.kind === "output" || r.kind === "input" || r.kind === "app");
        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) current = Math.min(rows.length - 1, current + 1);
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) current = Math.max(0, current - 1);
        else if (!r) return;
        else if (event.key === Qt.Key_Right && level) Audio.setVolume(r.node, r.node.audio.volume + step);
        else if (event.key === Qt.Key_Left && level) Audio.setVolume(r.node, r.node.audio.volume - step);
        else if (event.key === Qt.Key_M && level) Audio.toggleMute(r.node);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (r.kind === "sink") Audio.makeDefault(r.node);
            else if (r.kind === "source") Audio.makeDefaultSource(r.node);
            else Audio.toggleMute(r.node);
        } else return;
        event.accepted = true;
    }

    Heading {
        title: "Sound"
        annotation: ["pipewire", panel.rateText].filter(s => s !== "").join(" · ")
    }
    Item { width: Theme.size.rule; height: Theme.space.s5 }

    // ---- Output ----------------------------------------------------------------------------------------------
    SectionHead { title: "Output" }
    Txt {
        visible: !Audio.ready
        height: Theme.size.hitTarget
        text: "No output."
        color: Theme.colors.textMuted
    }
    SoundLevel {
        visible: Audio.ready
        node: Audio.sink
        selected: panel.isCurrent(Audio.sink, "output")
        onPicked: panel.pick(Audio.sink, "output")
    }
    Item { width: Theme.size.rule; height: Theme.space.s2 }
    Repeater {
        model: ScriptModel { values: Audio.sinks }
        DeviceLine { mic: false }
    }

    // ---- Input -----------------------------------------------------------------------------------------------
    Item { visible: Audio.sources.length > 0; width: Theme.size.rule; height: Theme.panel.sectionGap }
    SectionHead { visible: Audio.sources.length > 0; title: "Input" }
    SoundLevel {
        visible: Audio.hasSource
        node: Audio.source
        mic: true
        selected: panel.isCurrent(Audio.source, "input")
        onPicked: panel.pick(Audio.source, "input")
    }
    Item { visible: Audio.sources.length > 0; width: Theme.size.rule; height: Theme.space.s2 }
    Repeater {
        model: ScriptModel { values: Audio.sources }
        DeviceLine { mic: true }
    }

    // ---- Apps ------------------------------------------------------------------------------------------------
    Item { visible: Audio.streams.length > 0; width: Theme.size.rule; height: Theme.panel.sectionGap }
    SectionHead {
        visible: Audio.streams.length > 0
        title: "Apps"
        annotation: Audio.streams.length + " playing"
    }
    Column {
        visible: Audio.streams.length > 0
        width: parent.width
        spacing: Theme.space.s3
        Repeater {
            model: ScriptModel { values: Audio.streams }
            SoundApp {
                required property var modelData
                node: modelData
                selected: panel.isCurrent(modelData, "app")
                onPicked: panel.pick(modelData, "app")
            }
        }
    }

    // ---- Footer ----------------------------------------------------------------------------------------------
    Item { width: Theme.size.rule; height: Theme.space.s5 }
    PanelFooter {
        action: Audio.settingsApp ? "sound settings" : ""
        command: ["pavucontrol"]
        backend: panel.rateText
    }

    // An output or input device: the circle (filled = the default), its name, the Bluetooth glyph for a Bluetooth one.
    component DeviceLine: RowItem {
        id: line
        required property var modelData
        property bool mic: false
        readonly property bool inUse: modelData === (mic ? Audio.source : Audio.sink)
        radio: true
        checked: inUse
        selected: panel.isCurrent(modelData, mic ? "source" : "sink")
        onHoveredIn: panel.pick(modelData, mic ? "source" : "sink")
        onActivated: mic ? Audio.makeDefaultSource(modelData) : Audio.makeDefault(modelData)

        Txt {
            anchors { left: parent.left; right: bt.visible ? bt.left : parent.right; rightMargin: bt.visible ? Theme.space.s2 : 0
                      verticalCenter: parent.verticalCenter }
            text: Audio.nodeName(line.modelData)
            color: line.inUse ? Theme.colors.text : Theme.colors.textMuted
        }
        Icon {
            id: bt
            visible: Audio.isBluetooth(line.modelData)
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            name: Theme.icons.bluetooth
            color: Theme.colors.textMuted
        }
    }
}
