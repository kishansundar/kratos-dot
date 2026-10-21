pragma Singleton
import QtQuick
import Quickshell
import qs
import Quickshell.Io
import Quickshell.Networking

// Network state from NetworkManager: which device is up, the Wi-Fi network and its signal. Event-driven.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var active: devices.find(d => d.connected) ?? null
    readonly property bool online: active !== null
    readonly property bool onWired: active !== null && active.type === DeviceType.Wired
    readonly property var wifiNetwork: wifi ? wifi.networks.values.find(n => n.connected) ?? null : null
    readonly property real signal: wifiNetwork ? wifiNetwork.signalStrength : 0
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited
                                 || Networking.connectivity === NetworkConnectivity.Portal

    function secured(n) { return n && n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe }

    readonly property string label: onWired ? "Ethernet"
                                  : wifiNetwork ? wifiNetwork.name
                                  : !Networking.wifiEnabled ? "Wi-Fi off" : "Offline"
    readonly property string detail: !online ? "" : limited ? "Limited connectivity"
                                   : onWired ? "Connected" : "Signal " + Math.round(signal * 100) + " %"

    // The wired link's speed in words ("1 Gb/s"); the device reports Mb/s, 0 without a link.
    readonly property string wiredSpeed: !wired || !(wired.linkSpeed > 0) ? ""
        : wired.linkSpeed >= 1000 ? wired.linkSpeed / 1000 + " Gb/s" : wired.linkSpeed + " Mb/s"

    // The networks in range, for a list: named ones only (hidden networks are set up in network settings), the
    // connected one apart; strongest first by lit bars, saved before unsaved at equal strength, then by signal and name.
    function bars(s) { return Math.max(1, Math.min(4, Math.ceil(s * 4))) }
    readonly property var inRange: !wifi ? [] : wifi.networks.values.filter(n => n.name !== "" && !n.connected).sort((a, b) =>
        (bars(b.signalStrength) - bars(a.signalStrength)) || (b.known - a.known)
        || (b.signalStrength - a.signalStrength) || a.name.localeCompare(b.name))

    // ---- The connected Wi-Fi link's details, read with nmcli when a panel asks (the network module has no
    // addresses): { ip, band, channel, signal (0-100), security, rate }, or {} until read.
    property var wifiDetails: ({})
    function readWifiDetails() {
        if (!wifi || details.running) return;
        details.command = ["sh", "-c", "nmcli -t -f IP4.ADDRESS dev show \"$1\"; echo ---; nmcli -t -f IN-USE,CHAN,FREQ,SIGNAL,SECURITY,RATE dev wifi list ifname \"$1\" --rescan no", "sh", wifi.name];
        details.running = true;
    }
    Process {
        id: details
        stdout: StdioCollector { onStreamFinished: root.wifiDetails = root.parseDetails(text) }
    }
    function parseDetails(text) {
        const out = {};
        const parts = text.split("\n---\n");
        const ip = (parts[0] ?? "").match(/IP4\.ADDRESS\[1\]:([0-9.]+)/);
        if (ip) out.ip = ip[1];
        // -t escapes a colon inside a field as "\:"; none of these fields should hold one, but keep them whole.
        const line = (parts[1] ?? "").split("\n").find(l => l.startsWith("*:"));
        if (line) {
            const f = line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
            const mhz = parseInt(f[2]);
            out.channel = f[1];
            out.band = isNaN(mhz) ? "" : mhz < 3000 ? "2.4 GHz" : mhz < 5925 ? "5 GHz" : "6 GHz";
            out.signal = parseInt(f[3]);
            out.security = (f[4] ?? "").toLowerCase();
            out.rate = (f[5] ?? "").toLowerCase();
        }
        return out;
    }

    // Scanning: only while a panel asks; the panel ends it (it closes, or scanTimeout passes). Reading, not a change.
    function setScanning(on) { if (wifi) wifi.scannerEnabled = on }

    // ---- Actions: every change to NetworkManager goes through here (panels only read). Under SWISS_DRY_RUN=1 (the test
    // rig) each one is logged as "DRYRUN ..." and nothing changes: the Wi-Fi under test may be this machine's only link.
    readonly property bool dryRun: Theme.dryRun
    function setWifiEnabled(on) { if (dryRun) return console.log("DRYRUN wifi", on ? "on" : "off"); Networking.wifiEnabled = on }
    function connect(n) { if (dryRun) return console.log("DRYRUN wifi connect", n.name); n.connect() }
    function connectWithPsk(n, psk) { if (dryRun) return console.log("DRYRUN wifi connect with a password", n.name); n.connectWithPsk(psk) }
    function disconnect(n) { if (dryRun) return console.log("DRYRUN wifi disconnect", n.name); n.disconnect() }
    function forget(n) { if (dryRun) return console.log("DRYRUN wifi forget", n.name); n.forget() }
}
