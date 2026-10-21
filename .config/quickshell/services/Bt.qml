pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs

// Bluetooth for the panel (design/panels BluetoothPanel). Every change to BlueZ goes through here; the panels only read.
// Under SWISS_DRY_RUN=1 (the test rig, which shares this machine's real adapter) each action is logged as "DRYRUN ..."
// and nothing changes, so an attempt runs out its time and says so. Pairing requests (passkeys, PINs) are answered by
// BtAgent.
//   devices          every device the adapter knows; `kind(d)` says what it is ("audio", "keyboard", "phone", …)
//   busy(d)          a command for it is running (connect, disconnect, pair, remove), or BlueZ says it is changing
//   failed[address]  why the last attempt for it failed, in words ("couldn't connect"), until the next attempt
//   An attempt ends when BlueZ reports the result (read back, never assumed) or after Theme.panel.connectTimeout.
//   A pairing that succeeds is trusted and connected at once (so the device can come back by itself).
//   search(on)       discovery, which the panel runs while it is open, for at most Theme.panel.scanTimeout;
//                    `searchEnds` is when the panel's own search stops (0: not the panel's)
//   searchPending    the panel asked while Bluetooth was off: the search starts once BlueZ reports the adapter on
Singleton {
    id: root

    readonly property bool dryRun: Theme.dryRun
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool on: present && adapter.enabled
    readonly property bool discovering: on && adapter.discovering
    readonly property var devices: present ? adapter.devices.values : []
    readonly property string adapterId: present ? adapter.adapterId : ""

    // ---- What a device is, from its freedesktop icon name ----------------------------------------------------------
    function kind(d) {
        const i = d ? (d.icon ?? "") : "";
        if (/^audio|headset|headphone|speaker/.test(i)) return "audio";
        if (/keyboard/.test(i)) return "keyboard";
        if (/mouse/.test(i)) return "mouse";
        if (/gaming/.test(i)) return "gamepad";
        if (/tablet/.test(i)) return "tablet";
        if (/phone/.test(i)) return "phone";
        if (/computer/.test(i)) return "computer";
        return "";
    }
    function known(d) { return d.paired || d.bonded }

    // ---- Attempts in flight ----------------------------------------------------------------------------------------
    property var pending: ({})       // address -> { action, until }
    property var failed: ({})        // address -> words
    property var pairTarget: null    // the device the panel last asked to pair (BlueZ's agent does not name it)

    function busy(d) {
        return !!pending[d.address] || d.pairing
            || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }
    function begin(d, action) {
        const p = Object.assign({}, pending);
        p[d.address] = { action: action, until: Date.now() + Theme.panel.connectTimeout, device: d };
        pending = p;
        const f = Object.assign({}, failed);
        delete f[d.address];
        failed = f;
    }
    function finish(address, failure) {
        if (pairTarget && pairTarget.address === address) pairTarget = null;
        const p = Object.assign({}, pending);
        delete p[address];
        pending = p;
        if (failure) {
            const f = Object.assign({}, failed);
            f[address] = failure;
            failed = f;
        }
    }
    // Read the result back: done when BlueZ says so, failed when the time runs out (a pairing still waiting for the
    // user's answer keeps its time).
    Timer {
        running: Object.keys(root.pending).length > 0
        interval: 250
        repeat: true
        onTriggered: {
            const now = Date.now();
            for (const a of Object.keys(root.pending)) {
                const p = root.pending[a], d = p.device;
                if (!d) { root.finish(a, ""); continue; }
                const done = p.action === "connect" ? d.connected
                           : p.action === "disconnect" ? !d.connected
                           : p.action === "pair" ? root.known(d)
                           : p.action === "remove" ? !root.known(d) : true;
                if (done) {
                    root.finish(a, "");
                    if (p.action === "pair") { root.trust(d); root.connect(d); }
                } else if (p.action === "pair" && d.pairing && now > p.until) {
                    p.until = now + Theme.panel.connectTimeout;
                } else if (now > p.until) {
                    root.finish(a, p.action === "connect" ? "couldn't connect" : p.action === "disconnect" ? "couldn't disconnect"
                                 : p.action === "pair" ? "couldn't pair" : "couldn't remove");
                }
            }
        }
    }

    // ---- Actions ---------------------------------------------------------------------------------------------------
    function setEnabled(on) { if (!adapter) return; if (dryRun) return console.log("DRYRUN bluetooth", on ? "on" : "off"); adapter.enabled = on }
    function setDiscovering(on) { if (!adapter) return; if (dryRun) return console.log("DRYRUN bluetooth search", on ? "on" : "off"); adapter.discovering = on }
    function connect(d) { begin(d, "connect"); if (dryRun) return console.log("DRYRUN bluetooth connect", d.name); d.connect() }
    function disconnect(d) { begin(d, "disconnect"); if (dryRun) return console.log("DRYRUN bluetooth disconnect", d.name); d.disconnect() }
    function pair(d) { pairTarget = d; begin(d, "pair"); if (dryRun) return console.log("DRYRUN bluetooth pair", d.name); d.pair() }
    function cancelPair(d) { finish(d.address, ""); if (dryRun) return console.log("DRYRUN bluetooth cancel pairing", d.name); d.cancelPair() }
    function trust(d) { if (dryRun) return console.log("DRYRUN bluetooth trust", d.name); d.trusted = true }
    function forget(d) { begin(d, "remove"); if (dryRun) return console.log("DRYRUN bluetooth remove", d.name); d.forget() }

    // ---- Search: while the panel is open, at most scanTimeout --------------------------------------------------------
    property real searchEnds: 0
    property bool searchPending: false
    function search(on) {
        if (!root.on) { searchEnds = 0; searchPending = on; return; }
        searchPending = false;
        searchEnds = on ? Date.now() + Theme.panel.scanTimeout : 0;
        setDiscovering(on);
    }
    // `enabled` turns true at the click, before BlueZ has powered the adapter (a search then fails "Resource Not Ready"), so a waiting or running panel search starts again on BlueZ's own "on"
    Connections {
        target: root.adapter
        function onStateChanged() { if ((root.searchPending || root.searchEnds > 0) && root.adapter.state === BluetoothAdapterState.Enabled) root.search(true); }
    }
    Timer {
        running: root.searchEnds > 0
        interval: Math.max(1, root.searchEnds - Date.now())
        onTriggered: root.search(false)
    }
}
