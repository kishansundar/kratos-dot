pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// This computer's Tailscale state: `tailscale status --json` and `tailscale debug prefs`, with a 4 s timeout so a hung
// daemon cannot stall anything. Checked when the dashboard opens, every refreshIdle (30 s) while it is open
// (`watching`; the Network panel reads it every Theme.panel.tailscaleRefresh itself) and after each action. The dashboard's switch acts through setRunning / setDns (kishan is Tailscale's operator, so no
// sudo): up keeps Tailscale's DNS off unless Prefs.tailscaleDns asks for it, so the system's resolver keeps answering.
// While an action runs `busy` is set; a failed one leaves its last words in `error` and the state as it really is.
//
//   state      "connected" | "disconnected" (stopped) | "service-down" | "needs-login" | "starting" | "not-installed"
//              | "unknown" (the check failed: never shown as disconnected)
//   detail     why, in words (the backend state, or the error)
//   ip         this machine's Tailscale IPv4, hostname, tailnet, peers online / total
//   dns        Tailscale's DNS is in use (the CorpDNS pref); loginUrl when it needs a login
//   checked    when the last check finished
//   peerList   the other devices for the Network panel: { id, name, ip, online, exitOption, exitNode }, online first,
//              then by name; exitNodes the ones that offer to be an exit node; exitNode the name of the one in use
//              ("" = none), set with setExitNode(peer) (null clears it). Checked once at start too, so the bar's
//              network tooltip can say "via <peer>".
Singleton {
    id: root

    property bool watching: false
    property string state: "unknown"
    property string detail: "Not checked yet"
    property string ip: ""
    property string tailnet: ""
    property int peersOnline: 0
    property int peers: 0
    property bool dns: false
    property string loginUrl: ""
    property bool busy: false
    property string error: ""
    property date checked: new Date(0)
    readonly property bool hasChecked: checked.getTime() > 0
    property var peerList: []
    readonly property var exitNodes: peerList.filter(p => p.exitOption)
    property string exitNode: ""

    // A plain refresh() reads the status and the prefs (Tailscale's DNS); refresh(false), the dashboard's every 30 s
    // (refreshIdle), the status alone: the prefs (a second run of the Go CLI) change from here only through an action,
    // which reads them again.
    property bool wantPrefs: true
    function refresh(prefs) {
        if (prefs !== false) wantPrefs = true;
        if (proc.running) return;
        proc.command = ["sh", "-c", "command -v tailscale >/dev/null || exit 127; timeout 4 tailscale status --json; s=$?; "
                        + (wantPrefs ? "printf '\\n\\036\\n'; timeout 4 tailscale debug prefs 2>/dev/null; " : "") + "exit $s"];
        wantPrefs = false;
        proc.running = true;
    }
    Component.onCompleted: refresh()

    onWatchingChanged: if (watching) refresh(true)
    Timer { running: root.watching; repeat: true; interval: Theme.motion.refreshIdle; onTriggered: root.refresh(false) }

    // ---- Actions -----------------------------------------------------------------------------------------
    function setRunning(on) {
        act(on ? ["sh", "-c", "tailscale set --accept-dns=\"$1\" && tailscale up", "sh", String(Prefs.tailscaleDns)]
               : ["tailscale", "down"]);
    }
    function setDns(on) {
        Prefs.set("tailscaleDns", on);
        act(["tailscale", "set", "--accept-dns=" + on]);
    }
    // Route this machine's traffic through a peer (by its Tailscale IP), or through nobody again.
    function setExitNode(peer) { act(["tailscale", "set", "--exit-node=" + (peer ? peer.ip : "")]) }
    function act(command) {
        if (busy) return;
        busy = true;
        error = "";
        action.command = ["timeout", "20"].concat(command);
        action.running = true;
    }
    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: code => {
            root.busy = false;
            if (code !== 0) root.error = actionErr.text.trim().split("\n").pop() || (code === 124 ? "tailscale did not answer within 20 s" : "tailscale exited with " + code);
            root.refresh(true);
            settle.restart();
        }
    }
    // Coming up takes a moment (Starting, then Running): look again shortly after.
    Timer { id: settle; interval: 1500; onTriggered: root.refresh(true) }

    Process {
        id: proc
        // `command -v` first, so a missing CLI is told apart from a failing one (exit 127 below). The prefs follow the
        // status after a record separator line.
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: (code, status) => {
            const parts = out.text.split("\n\u001e\n");
            try { root.dns = !!JSON.parse(parts[1] ?? "").CorpDNS; } catch (e) { /* prefs unreadable: keep the last */ }
            root.interpret(code, parts[0], err.text);
        }
    }

    function interpret(code, text, errText) {
        const list = root.read(code, text, errText);
        if (JSON.stringify(list) !== JSON.stringify(root.peerList)) root.peerList = list;     // unchanged: no churn in lists
        root.exitNode = list.find(p => p.exitNode)?.name ?? "";
    }
    // One status read into the properties above; returns the peers (none without a status).
    function read(code, text, errText) {
        root.checked = new Date();
        root.ip = ""; root.tailnet = ""; root.peers = 0; root.peersOnline = 0;
        if (code === 127) { root.state = "not-installed"; root.detail = "The tailscale command is not installed"; return []; }
        if (code === 124) { root.state = "unknown"; root.detail = "tailscale did not answer within 4 s"; return []; }
        let s = null;
        try { s = JSON.parse(text); } catch (e) { s = null; }
        if (!s) {
            const e = (errText || "").trim();
            // The daemon is down: the client cannot reach tailscaled at all.
            // Not a choice to disconnect: a service that is not running, said in neutral words and colour.
            if (/tailscaled|connect|no such file|connection refused/i.test(e)) { root.state = "service-down"; root.detail = "The tailscaled service is not running"; }
            else { root.state = "unknown"; root.detail = e.split("\n")[0] || "tailscale exited with " + code; }
            return [];
        }
        const backend = s.BackendState ?? "";
        root.detail = backend || "No backend state";
        if (backend === "Running") root.state = "connected";
        else if (backend === "Stopped") root.state = "disconnected";
        else if (backend === "NeedsLogin" || backend === "NeedsMachineAuth") root.state = "needs-login";
        else if (backend === "Starting") root.state = "starting";
        else root.state = "unknown";

        root.loginUrl = s.AuthURL ?? "";
        const self = s.Self ?? {};
        root.ip = (self.TailscaleIPs ?? []).find(a => a.indexOf(":") < 0) ?? "";
        root.tailnet = s.CurrentTailnet?.Name ?? "";
        const list = Object.values(s.Peer ?? {});
        root.peers = list.length;
        root.peersOnline = list.filter(p => p.Online).length;
        // A peer's name is its MagicDNS name (what the admin console calls it), else its hostname.
        const peerList = list.map(p => ({
            id: p.ID ?? "",
            name: (p.DNSName ?? "").split(".")[0] || p.HostName || "?",
            ip: (p.TailscaleIPs ?? []).find(a => a.indexOf(":") < 0) ?? "",
            online: !!p.Online,
            exitOption: !!p.ExitNodeOption,
            exitNode: !!p.ExitNode
        })).sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name, undefined, { numeric: true }));
        return peerList;
    }
}
