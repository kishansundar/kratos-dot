pragma Singleton
import QtQuick
import Quickshell
import qs
import Quickshell.Io
import Quickshell.Services.Pipewire

// The default output and, while the sound panel is open (`detailed`), every output and input device, every playing app,
// the graph's sample rate (`rate`, from PipeWire's settings metadata) and whether a sound settings app is installed.
// Volumes stop at 100 % (Theme.panel.volumeMax: over-amplification is left to sound settings).
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!(sink && sink.audio)
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property int percent: Math.round(volume * 100)

    function nodeName(n) {
        if (!n) return "";
        const props = n.properties ?? {};
        return props["application.name"] || n.description || n.nickname || n.name || "Unknown";
    }

    // Devices and app streams are only tracked (kept live) while the audio panel is open.
    property bool detailed: false
    // Sorted by name: PipeWire does not keep a stable order.
    function byName(a, b) { return nodeName(a).localeCompare(nodeName(b)) }
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream).sort(byName)
    // Apps playing sound. Quickshell reports a playback stream as a stream *and* a sink (media.class
    // Stream/Output/Audio: isStream and isSink both true, probed 2026-10-14); recording streams are not sinks.
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.isSink).sort(byName)
    // Inputs (microphones): hardware sources only, not monitors of outputs.
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && !/\.monitor$/.test(n.name)).sort(byName)
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasSource: !!(source && source.audio)
    function makeDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node }

    PwObjectTracker {
        objects: root.detailed
            ? [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource].concat(root.sinks).concat(root.streams).concat(root.sources)
            : [Pipewire.defaultAudioSink]
    }

    function setVolume(node, v) {
        if (node && node.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(Theme.panel.volumeMax / 100, v));
        }
    }
    function step(delta) { if (ready) setVolume(sink, volume + delta) }
    function toggleMute(node) { const n = node ?? sink; if (n && n.audio) n.audio.muted = !n.audio.muted }
    function makeDefault(node) { Pipewire.preferredDefaultAudioSink = node }

    // ---- For the sound and Bluetooth panels --------------------------------------------------------------------
    function isBluetooth(n) { return !!n && (n.properties?.["device.api"] === "bluez5" || /^bluez_/.test(n.name ?? "")) }
    // The output a Bluetooth device plays through, if PipeWire has one for it (its address in the node's properties).
    function sinkFor(address) {
        const a = (address ?? "").toUpperCase();
        return a === "" ? null : Pipewire.nodes.values.find(n => n.audio && n.isSink && !n.isStream
            && ((n.properties?.["api.bluez5.address"] ?? "").toUpperCase() === a || (n.name ?? "").toUpperCase().indexOf(a.replace(/:/g, "_")) >= 0)) ?? null;
    }
    function appName(n) { const p = n?.properties ?? {}; return p["application.name"] || n?.description || n?.name || "Unknown" }
    function mediaName(n) { const p = n?.properties ?? {}; return p["media.name"] || "" }

    property int rate: 0                 // Hz, 0 until read
    property bool settingsApp: false     // pavucontrol is installed
    onDetailedChanged: if (detailed) { rateProc.running = true; appProc.running = true; }
    Process {
        id: rateProc
        command: ["pw-metadata", "-n", "settings", "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rates = {};
                const re = /key:'(clock\.(?:force-)?rate)' value:'(\d+)'/g;
                let m;
                while ((m = re.exec(text)) !== null) rates[m[1]] = parseInt(m[2]);
                root.rate = rates["clock.force-rate"] || rates["clock.rate"] || 0;
            }
        }
    }
    Process {
        id: appProc
        command: ["sh", "-c", "command -v pavucontrol"]
        onExited: code => root.settingsApp = code === 0
    }

    // The output pop-up listens for this: the default output became another device (headphones taking over, a choice
    // in sound settings), not the first one appearing at start or a moment without one (a device leaving).
    signal outputChanged()
    property string lastSinkName: ""
    Component.onCompleted: lastSinkName = sink?.name ?? ""
    onSinkChanged: {
        const n = sink?.name ?? "";
        if (n === "") return;
        if (armed && lastSinkName !== "" && n !== lastSinkName) { settling.restart(); outputChanged(); }
        lastSinkName = n;
    }
    // A new output reports its volume as it is bound: that is not a change the volume pop-up should show over the
    // output's (a short quiet after the switch).
    Timer { id: settling; interval: 500 }

    // The volume pop-up listens for this: it fires on a real change, not when the sink first appears.
    signal changedByUser()
    property bool armed: false
    Timer { running: root.ready; interval: 1000; onTriggered: root.armed = true }
    Connections {
        target: root.ready ? root.sink.audio : null
        function onVolumesChanged() { if (root.armed && !settling.running) root.changedByUser() }
        function onMutedChanged() { if (root.armed && !settling.running) root.changedByUser() }
    }
}
