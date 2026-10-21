pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs

// The Bluetooth pairing agent, so PINs, passkeys and confirmations are answered in the shell (the Bluetooth popover),
// never in a terminal. Quickshell's Bluetooth module has no agent API (0.3.2), so BlueZ's own agent does the D-Bus
// side: `bluetoothctl` runs hidden (scripts/bt-agent.sh: unbuffered, each prompt ended with a newline), registered as
// the default agent (KeyboardDisplay); this reads its requests and writes the answers. (From BlueZ 5.87 client/agent.c: a request prints a line, "Request confirmation",
// then a prompt without a newline, "[agent] Confirm passkey 123456 (yes/no): "; the answer is one line.)
//   request   null, or { kind, passkey, uuid }:
//               confirm    the device shows `passkey`: answer yes / no
//               pin        type the device's PIN code            passkey   type a 6-digit passkey
//               display    type `passkey` on the device (no answer here)
//               authorize  a device asks to pair                  service   a device asks to use a service (`uuid`)
//   device    the device being paired, when the shell knows it (BlueZ does not print it): the one BlueZ says is
//             pairing, or the one the panel asked to pair (Bt.pairTarget)
//   armed     false for Theme.panel.answerDelay after each request appears; answer() and refuse() do nothing until
//             then. A request opens the popover with the keyboard, maybe while the owner is typing elsewhere, and a
//             stray Enter would pair (the owner's choice, 20 October 2026).
Singleton {
    id: root

    property var request: null
    readonly property var device: Bt.devices.find(d => d.pairing) ?? Bt.pairTarget ?? null
    property bool armed: false
    signal requested()
    onRequestChanged: { armed = false; if (request) arm.restart(); else arm.stop(); }

    function answer(text) {
        if (!request || !armed) return;
        proc.write(text + "\n");
        request = null;
    }
    function refuse() {
        if (!request || !armed) return;
        if (request.kind === "display") { if (device) Bt.cancelPair(device); request = null; return; }
        answer(request.kind === "pin" || request.kind === "passkey" ? "" : "no");
    }

    // One line from bt-agent.sh, its colours and readline's invisible-text markers dropped.
    function parse(data) {
        const l = data.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/[\x01\x02\r\n]/g, "").trim();
        if (l === "") return;
        line(l);
        prompt(l);
    }
    function line(l) {
        if (/Request canceled/.test(l)) root.request = null;
        else {
            let m = l.match(/\[agent\] Passkey: (\d{6})/);
            if (m) { show({ kind: "display", passkey: m[1] }); return; }
            m = l.match(/\[agent\] PIN code: (\S+)/);
            if (m) show({ kind: "display", passkey: m[1] });
        }
    }
    function prompt(p) {
        let m;
        if ((m = p.match(/\[agent\] Confirm passkey (\d{6}) \(yes\/no\):/))) show({ kind: "confirm", passkey: m[1] });
        else if (/\[agent\] Enter PIN code:/.test(p)) show({ kind: "pin" });
        else if (/\[agent\] Enter passkey \(number in 0-999999\):/.test(p)) show({ kind: "passkey" });
        else if (/\[agent\] Accept pairing \(yes\/no\):/.test(p)) show({ kind: "authorize" });
        else if ((m = p.match(/\[agent\] Authorize service (\S+) \(yes\/no\):/))) show({ kind: "service", uuid: m[1] });
    }
    function show(r) { request = r; requested(); }

    Process {
        id: proc
        // Only with an adapter; started again after a pause if it ever stops.
        running: Bluetooth.defaultAdapter !== null
        command: [Quickshell.shellDir + "/scripts/bt-agent.sh"]
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.parse(data + "\n") }
        onStarted: { write("agent KeyboardDisplay\n"); write("default-agent\n"); }
        onExited: { root.request = null; if (Bluetooth.defaultAdapter !== null) restart.start(); }
    }
    Timer { id: arm; interval: Theme.panel.answerDelay; onTriggered: root.armed = true }
    Timer {
        id: restart
        interval: 3000
        // The binding again, not `true`: an assignment would replace it, and the agent would then not come back when
        // an adapter that went away returns.
        onTriggered: proc.running = Qt.binding(() => Bluetooth.defaultAdapter !== null)
    }
}
