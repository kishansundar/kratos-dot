import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.components
import qs.services

// Network (the network glyph in the bar, or Super+Ctrl+W): design/panels WifiPanel. Everything happens here, passwords
// too; what doesn't fit (hidden networks, 802.1X, other VPNs) belongs to network settings (the footer, when installed).
//   heading     "Network", and the Wi-Fi radio as a switch at the right: "wi-fi on" / "wi-fi off"
//   WIRED       the Ethernet port: a filled circle when it carries the connection, its speed in mono, the lan glyph
//   TAILSCALE   the tailnet's name; one row that is the switch: circle "connected", ring "stopped", triangle "needs
//               login" (coming up keeps Tailscale's DNS off unless "use tailscale dns" asks for it). Connected: this
//               machine's address and the DNS in use, the DNS switch, the exit node (only when the tailnet offers one),
//               the peers, online first (a click copies a peer's address). Needs login: log in (the panel's one red)
//               and copy link. Read again every 5 s while open, and after each action: never optimistic.
//   CONNECTED   the Wi-Fi network in use: its address, band, channel and signal; disconnect, forget (asks first: it
//               may be the only link), details
//   NETWORKS    the rest, strongest first, saved before unsaved at equal strength; scanned only while open, 30 s at
//               most. A saved or open network joins on one click; a new secured one opens a password field in place
//               (connect is the panel's one red). A joining row shows "…"; after 20 s or a refused password the
//               failure is said in words with the error glyph.
//   Wi-Fi off   one sentence in place of the Wi-Fi sections; Wired and Tailscale stay
//   footer      network settings (only when nm-connection-editor is installed), the backends in mono
// Keys: Tab walks the controls in reading order; Up / Down walk the rows (Tailscale, exit nodes, peers, networks) and
// Enter acts on one; Esc closes the open form or list first, then the panel.
Column {
    id: panel
    width: Theme.panel.column
    focus: true

    readonly property var wifi: Net.wifi
    readonly property bool wifiOn: wifi !== null && Networking.wifiEnabled
    readonly property var connected: Net.wifiNetwork
    readonly property var networks: Net.inRange
    // Where a row's words start (after its circle): details and forms under a row are indented to it.
    readonly property int textX: Theme.space.s3 + Theme.size.markCircle + Theme.space.s3

    property var asking: null           // the secured network whose password form is open
    property var trying: null           // the network being joined
    property bool tryingPsk: false
    property var failed: null           // the network the last attempt failed on, and why in words
    property string failure: ""
    property bool scanning: false
    property bool exitOpen: false       // the exit-node list
    property bool forgetAsk: false      // "forget" asks first
    property bool moreDetails: false
    property string copiedIp: ""        // the peer address just copied ("copied" stands in for it until the pointer leaves)
    property bool settingsApp: false

    // ---- Tailscale, in words and marks -----------------------------------------------------------------------
    readonly property bool tsVisible: Tailscale.state !== "not-installed"
    readonly property bool tsUp: Tailscale.state === "connected"
    readonly property bool tsActionable: tsUp || Tailscale.state === "disconnected"
    readonly property string tsWord: Tailscale.state === "connected" ? "connected"
        : Tailscale.state === "disconnected" ? "stopped"
        : Tailscale.state === "needs-login" ? "needs login"
        : Tailscale.state === "starting" ? "starting"
        : Tailscale.state === "service-down" ? "service not running"
        : Tailscale.hasChecked ? "unknown" : "checking"
    function toggleTailscale() {
        if (Tailscale.busy || !tsActionable) return;
        Tailscale.setRunning(!tsUp);
    }
    function copyIp(p) {
        if (!p.ip) return;
        Quickshell.execDetached(["wl-copy", p.ip]);
        copiedIp = p.ip;
    }
    function logIn() {
        if (Tailscale.loginUrl === "") { Tailscale.setRunning(true); return; }   // asks tailscaled for a login link
        Quickshell.execDetached(["xdg-open", Tailscale.loginUrl]);
        Panels.close();
    }

    // ---- Joining a network -----------------------------------------------------------------------------------
    readonly property string wrongPassword: "wrong password — try again"
    function choose(n) {
        if (trying === n) return;
        failure = ""; failed = null;
        if (n.known || !Net.secured(n)) { asking = null; begin(n, false); Net.connect(n); return; }
        asking = asking === n ? null : n;
        if (!asking) panel.forceActiveFocus();
    }
    function join(n, psk) {
        if (psk.length < 8 || trying === n) return;      // WPA's least
        failure = ""; failed = null;
        begin(n, true);
        Net.connectWithPsk(n, psk);
    }
    function begin(n, psk) { trying = n; tryingPsk = psk; connectTimer.restart() }
    function fail(n, words) {
        connectTimer.stop();
        trying = null;
        failed = n;
        failure = words;
    }
    // Esc or cancel: the open form (and its failure), list or question closes.
    function collapse() {
        if (asking && failed === asking) { failed = null; failure = ""; }
        asking = null; exitOpen = false; forgetAsk = false;
        panel.forceActiveFocus();
    }
    Timer {
        id: connectTimer
        interval: Theme.panel.connectTimeout
        onTriggered: if (panel.trying) panel.fail(panel.trying, panel.tryingPsk ? panel.wrongPassword : "couldn't connect")
    }
    Connections {
        target: panel.trying
        function onConnectionFailed(reason) {
            const n = panel.trying;
            const auth = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout;
            if (auth && Net.secured(n)) { panel.asking = n; panel.fail(n, panel.wrongPassword); }   // a saved one too
            else panel.fail(n, "couldn't connect");
        }
        function onConnectedChanged() {
            if (panel.trying && panel.trying.connected) { connectTimer.stop(); panel.trying = null; panel.asking = null; }
        }
    }

    // ---- While open: scan (at most scanTimeout), read Tailscale every few seconds, read the link's details ------
    function startScan() { if (!wifiOn) return; Net.setScanning(true); scanning = true; scanTimer.restart() }
    Component.onCompleted: { startScan(); Net.readWifiDetails(); Tailscale.refresh(); settingsCheck.running = true }
    Component.onDestruction: if (scanning) Net.setScanning(false)
    Timer { id: scanTimer; interval: Theme.panel.scanTimeout; onTriggered: { Net.setScanning(false); panel.scanning = false } }
    Timer { interval: Theme.panel.tailscaleRefresh; running: true; repeat: true; onTriggered: Tailscale.refresh(false) }   // the status; the prefs are read on open and after an action
    Connections {
        target: Net
        function onWifiNetworkChanged() { Net.readWifiDetails(); panel.forgetAsk = false; panel.moreDetails = false }
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged() { if (Networking.wifiEnabled) panel.startScan() }
    }
    // Network settings are offered only when the tool is there.
    Process {
        id: settingsCheck
        command: ["sh", "-c", "command -v nm-connection-editor"]
        onExited: code => panel.settingsApp = code === 0
    }

    // ---- Keyboard: the rows in reading order, by a stable key (peers are new objects on every read) ------------
    readonly property var keyRows: {
        const r = [];
        if (tsVisible && tsActionable) r.push({ kind: "ts", key: "ts", obj: null });
        if (tsUp && exitOpen) {
            r.push({ kind: "exit", key: "exit:", obj: null });
            for (const p of Tailscale.exitNodes) r.push({ kind: "exit", key: "exit:" + p.id, obj: p });
        }
        if (tsUp) for (const p of Tailscale.peerList) r.push({ kind: "peer", key: "peer:" + p.id, obj: p });
        if (wifiOn) for (const n of networks) r.push({ kind: "net", key: "net:" + n.name, obj: n });
        return r;
    }
    property string currentKey: ""
    function moveBy(d) {
        if (keyRows.length === 0) return;
        const i = keyRows.findIndex(r => r.key === currentKey);
        const next = i < 0 ? (d > 0 ? 0 : keyRows.length - 1) : Math.max(0, Math.min(keyRows.length - 1, i + d));
        currentKey = keyRows[next].key;
        const row = keyRows[next];
        if (row.kind === "net") netList.positionViewAtIndex(networks.indexOf(row.obj), ListView.Contain);
        else if (row.kind === "peer") peerList.positionViewAtIndex(Tailscale.peerList.findIndex(p => p.id === row.obj.id), ListView.Contain);
    }
    function actOn(row) {
        if (row.kind === "ts") toggleTailscale();
        else if (row.kind === "exit") { Tailscale.setExitNode(row.obj); exitOpen = false; }
        else if (row.kind === "peer") copyIp(row.obj);
        else if (row.kind === "net") choose(row.obj);
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && (asking || exitOpen || forgetAsk)) collapse();
        else if (event.key === Qt.Key_Down) moveBy(1);
        else if (event.key === Qt.Key_Up) moveBy(-1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const row = keyRows.find(r => r.key === currentKey);
            if (row) actOn(row);
        } else return;
        event.accepted = true;
    }

    // ---- Heading ------------------------------------------------------------------------------------------------
    Heading {
        title: "Network"
        Switch {
            visible: panel.wifi !== null
            word: Networking.wifiEnabled ? "wi-fi on" : "wi-fi off"
            checked: Networking.wifiEnabled
            onToggled: Net.setWifiEnabled(!Networking.wifiEnabled)
        }
    }

    // ---- Wired ----------------------------------------------------------------------------------------------------
    Column {
        id: wiredSection
        visible: Net.wired !== null
        width: parent.width
        topPadding: Theme.space.s5
        SectionHead { title: "Wired" }
        RowItem {
            interactive: false          // the port and its state: nothing to do here
            radio: true
            checked: Net.onWired
            Txt {
                anchors { left: parent.left; right: wiredTrail.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: "Ethernet"
            }
            Row {
                id: wiredTrail
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                Annot {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !Net.wired ? "" : Net.onWired ? Net.wiredSpeed : Net.wired.hasLink ? "not connected" : "cable unplugged"
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Net.wired && Net.wired.hasLink ? Theme.icons.lan : Theme.icons.lanOff
                    color: Net.onWired ? Theme.colors.text : Theme.colors.textMuted
                }
            }
        }
    }

    // ---- Tailscale ------------------------------------------------------------------------------------------------
    Column {
        id: tsSection
        visible: panel.tsVisible
        width: parent.width
        topPadding: wiredSection.visible ? Theme.panel.sectionGap : Theme.space.s5
        SectionHead { title: "Tailscale"; annotation: Tailscale.tailnet }

        // The switch row: its mark and word are the state; a click brings it up or down.
        RowItem {
            id: tsRow
            selected: panel.currentKey === "ts"
            interactive: panel.tsActionable
            busy: Tailscale.busy
            onHoveredIn: panel.currentKey = "ts"
            onActivated: panel.toggleTailscale()
            Mark {
                id: tsMark
                anchors.verticalCenter: parent.verticalCenter
                kind: panel.tsUp ? "circle" : Tailscale.state === "needs-login" ? "triangle" : "ring"
            }
            Txt {
                anchors { left: tsMark.right; leftMargin: Theme.space.s3; right: tsTrail.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: panel.tsWord + (Tailscale.busy ? " …" : "")
            }
            Row {
                id: tsTrail
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                Annot {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Tailscale.state === "unknown"
                    width: Math.min(implicitWidth, Theme.panel.column / 2)
                    text: Tailscale.detail.toLowerCase()
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Theme.icons.lan
                    color: panel.tsUp ? Theme.colors.text : Theme.colors.textMuted
                }
            }
        }

        // A failed action: tailscale's own words, under the switch, until the next action.
        ErrorLine {
            visible: Tailscale.error !== ""
            x: panel.textX
            width: parent.width - panel.textX
            text: Tailscale.error
        }

        // Connected: the details, the DNS switch, the exit node, the peers.
        Column {
            visible: panel.tsUp
            width: parent.width
            Annot {
                x: panel.textX
                width: parent.width - panel.textX
                height: Theme.size.hitTarget
                text: Tailscale.ip + " · dns: " + (Tailscale.dns ? "tailscale" : "system")
                color: Theme.colors.text
            }
            Switch {
                x: panel.textX - Theme.space.s2
                word: "use tailscale dns"
                checked: Tailscale.dns
                enabled: !Tailscale.busy
                onToggled: Tailscale.setDns(!Tailscale.dns)
            }
            Item {
                visible: Tailscale.exitNodes.length > 0
                width: parent.width
                height: Theme.size.hitTarget
                Txt {
                    x: panel.textX
                    anchors.verticalCenter: parent.verticalCenter
                    text: "exit node"
                    color: Theme.colors.textMuted
                }
                DropButton {
                    anchors { right: parent.right; rightMargin: Theme.space.s3 - Theme.space.s2; verticalCenter: parent.verticalCenter }
                    text: Tailscale.exitNode !== "" ? Tailscale.exitNode : "none"
                    open: panel.exitOpen
                    enabled: !Tailscale.busy
                    onClicked: panel.exitOpen = !panel.exitOpen
                }
            }
            // The exit-node choice, in place: none, or a peer that offers it.
            Column {
                visible: panel.exitOpen && Tailscale.exitNodes.length > 0
                // Indented so the circles stand where the words above start; the right edge stays the rows'.
                x: panel.textX - Theme.space.s3
                width: parent.width - x
                Repeater {
                    model: [null].concat(Tailscale.exitNodes)
                    RowItem {
                        id: exitRow
                        required property var modelData
                        readonly property string key: "exit:" + (modelData ? modelData.id : "")
                        radio: true
                        checked: modelData ? modelData.exitNode : Tailscale.exitNode === ""
                        selected: panel.currentKey === key
                        busy: Tailscale.busy
                        onHoveredIn: panel.currentKey = key
                        onActivated: { Tailscale.setExitNode(modelData); panel.exitOpen = false; }
                        Txt {
                            anchors { left: parent.left; right: exitIp.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            text: exitRow.modelData ? exitRow.modelData.name : "none"
                        }
                        Annot {
                            id: exitIp
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            text: !exitRow.modelData ? "" : exitRow.modelData.online ? exitRow.modelData.ip : "offline"
                        }
                    }
                }
            }
            // The peers: filled circle online, ring offline; the list scrolls past peersMax rows.
            ListView {
                id: peerList
                width: parent.width
                height: Math.min(count, Theme.panel.peersMax) * Theme.size.hitTarget
                clip: true
                interactive: count > Theme.panel.peersMax
                boundsBehavior: Flickable.StopAtBounds
                model: Tailscale.peerList
                delegate: RowItem {
                    id: peerRow
                    required property var modelData
                    width: peerList.width
                    radio: true
                    checked: modelData.online
                    selected: panel.currentKey === "peer:" + modelData.id
                    onHoveredIn: panel.currentKey = "peer:" + modelData.id
                    onHoveredChanged: if (!hovered && panel.copiedIp === modelData.ip) panel.copiedIp = ""
                    onActivated: panel.copyIp(modelData)
                    Txt {
                        anchors { left: parent.left; right: peerIp.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        text: peerRow.modelData.name
                    }
                    Annot {
                        id: peerIp
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: panel.copiedIp !== "" && panel.copiedIp === peerRow.modelData.ip ? "copied" : peerRow.modelData.ip
                        color: panel.copiedIp === peerRow.modelData.ip ? Theme.colors.text : Theme.colors.textMuted
                    }
                }
            }
            Annot {
                visible: Tailscale.peers > 0
                x: Theme.space.s3
                height: Theme.size.hitTarget
                text: Tailscale.peersOnline + " of " + Tailscale.peers + " online"
                color: Theme.colors.textFaint
            }
        }

        // Needs login: one sentence, log in (the panel's one red), copy link.
        Column {
            visible: Tailscale.state === "needs-login"
            x: panel.textX
            width: parent.width - panel.textX
            spacing: Theme.space.s2
            Txt {
                width: parent.width
                height: implicitHeight
                wrapMode: Text.Wrap
                maximumLineCount: 2
                text: "Open the login link to authorise this machine."
                color: Theme.colors.textMuted
            }
            Row {
                spacing: Theme.space.s4
                // The panel's one red, unless a password form below holds it (then connect is the primary).
                TextButton { kind: panel.asking ? "framed" : "primary"; text: "log in"; enabled: !Tailscale.busy; onClicked: panel.logIn() }
                TextButton {
                    text: "copy link"
                    enabled: Tailscale.loginUrl !== ""
                    onClicked: Quickshell.execDetached(["wl-copy", Tailscale.loginUrl])
                }
            }
        }
    }

    // ---- Connected Wi-Fi --------------------------------------------------------------------------------------
    Column {
        id: connectedSection
        visible: panel.wifiOn && panel.connected !== null
        width: parent.width
        topPadding: wiredSection.visible || tsSection.visible ? Theme.panel.sectionGap : Theme.space.s5
        SectionHead { title: "Connected" }
        RowItem {
            interactive: false
            radio: true
            checked: true
            id: connRow
            readonly property bool weak: Net.signal < 0.25
            Txt {
                anchors { left: parent.left; right: connTrail.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: panel.connected ? panel.connected.name : ""
            }
            Row {
                id: connTrail
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                // A weak link: the attention triangle and the word (never a colour).
                Mark { visible: connRow.weak; anchors.verticalCenter: parent.verticalCenter; kind: "triangle" }
                Annot { visible: connRow.weak; anchors.verticalCenter: parent.verticalCenter; text: "weak" }
                Icon {
                    visible: Net.secured(panel.connected)
                    anchors.verticalCenter: parent.verticalCenter
                    name: Theme.icons.lock
                    color: Theme.colors.textMuted
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Theme.icons.wifi[Net.bars(Net.signal)]
                }
            }
        }
        Annot {
            x: panel.textX
            width: parent.width - panel.textX
            height: implicitHeight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            readonly property var d: Net.wifiDetails
            text: [d.ip ?? "", d.band ?? "", d.channel ? "ch " + d.channel : "",
                   (d.signal ?? Math.round(Net.signal * 100)) + " %"].filter(s => s !== "").join(" · ")
            color: Theme.colors.text
        }
        Annot {
            visible: panel.moreDetails
            x: panel.textX
            width: parent.width - panel.textX
            height: implicitHeight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            readonly property var d: Net.wifiDetails
            text: [d.security ?? "", d.rate ?? "", panel.wifi ? panel.wifi.name : ""].filter(s => s !== "").join(" · ")
        }
        Row {
            visible: !panel.forgetAsk
            x: panel.textX
            spacing: Theme.space.s4
            TextButton { text: "disconnect"; onClicked: Net.disconnect(panel.connected) }
            TextButton { text: "forget"; onClicked: panel.forgetAsk = true }
            TextButton { text: panel.moreDetails ? "fewer details" : "details"; onClicked: panel.moreDetails = !panel.moreDetails }
        }
        // Forgetting deletes the saved password and drops what may be the only link: it asks first.
        Column {
            visible: panel.forgetAsk
            x: panel.textX
            width: parent.width - panel.textX
            Txt {
                width: parent.width
                height: implicitHeight
                topPadding: Theme.space.s1
                wrapMode: Text.Wrap
                maximumLineCount: 2
                text: "Forget " + (panel.connected ? panel.connected.name : "") + " and its password?"
            }
            Row {
                spacing: Theme.space.s4
                TextButton { text: "forget"; onClicked: { Net.forget(panel.connected); panel.forgetAsk = false; } }
                TextButton { text: "keep"; onClicked: panel.forgetAsk = false }
            }
        }
    }

    // ---- Networks in range --------------------------------------------------------------------------------------
    Column {
        id: netSection
        visible: panel.wifiOn
        width: parent.width
        topPadding: wiredSection.visible || tsSection.visible || connectedSection.visible ? Theme.panel.sectionGap : Theme.space.s5
        SectionHead { title: "Networks"; annotation: panel.scanning ? "scanning …" : "" }
        Txt {
            visible: panel.networks.length === 0
            x: Theme.space.s3
            height: Theme.size.hitTarget
            text: panel.scanning ? "Looking for networks …" : "No other networks in range"
            color: Theme.colors.textMuted
        }
        ListView {
            id: netList
            width: parent.width
            height: Math.min(contentHeight, Theme.panel.listMax)
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            // ScriptModel keeps each network's delegate while the list re-sorts, so a password being typed survives a
            // scan result.
            model: ScriptModel { values: panel.networks }
            delegate: Column {
                id: entry
                required property var modelData
                readonly property bool secured: Net.secured(modelData)
                readonly property bool joining: panel.trying === modelData
                width: netList.width

                RowItem {
                    radio: true
                    checked: false
                    busy: entry.joining
                    selected: panel.currentKey === "net:" + entry.modelData.name
                    onHoveredIn: panel.currentKey = "net:" + entry.modelData.name
                    onActivated: panel.choose(entry.modelData)
                    Txt {
                        anchors { left: parent.left; right: netTrail.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        text: entry.modelData.name + (entry.joining ? " …" : "")
                    }
                    Row {
                        id: netTrail
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: Theme.space.s2
                        Annot { visible: entry.modelData.known; anchors.verticalCenter: parent.verticalCenter; text: "saved" }
                        Icon {
                            visible: entry.secured
                            anchors.verticalCenter: parent.verticalCenter
                            name: Theme.icons.lock
                            color: Theme.colors.textMuted
                        }
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Theme.icons.wifi[Net.bars(entry.modelData.signalStrength)]
                            color: Theme.colors.textMuted
                        }
                    }
                }

                // The password, in place under its row: Enter or connect joins, Esc or cancel closes it.
                Column {
                    id: form
                    visible: panel.asking === entry.modelData
                    x: panel.textX
                    width: parent.width - panel.textX - Theme.space.s3
                    spacing: Theme.space.s2
                    bottomPadding: Theme.space.s2
                    property bool reveal: false
                    onVisibleChanged: if (visible) { psk.clear(); reveal = false; psk.focusInput(); }
                    Txt { height: Theme.font.body.lineHeight; text: "password"; color: Theme.colors.textMuted }
                    Field {
                        id: psk
                        password: true
                        reveal: form.reveal
                        error: panel.failed === entry.modelData ? panel.failure : ""
                        onAccepted: panel.join(entry.modelData, text)
                        onCancelled: panel.collapse()
                        onTextChanged: if (panel.failed === entry.modelData) { panel.failed = null; panel.failure = ""; }
                    }
                    // WPA needs eight characters at least: said under the field until there are enough.
                    Annot {
                        visible: psk.text.length > 0 && psk.text.length < 8 && psk.error === ""
                        text: "at least 8 characters"
                        color: Theme.colors.textFaint
                    }
                    Switch {
                        x: -Theme.space.s2
                        word: "show password"
                        checked: form.reveal
                        onToggled: { form.reveal = !form.reveal; psk.focusInput(); }
                    }
                    Row {
                        spacing: Theme.space.s4
                        TextButton {
                            kind: "primary"
                            text: "connect"
                            enabled: psk.text.length >= 8 && !entry.joining
                            onClicked: panel.join(entry.modelData, psk.text)
                        }
                        TextButton { text: "cancel"; onClicked: panel.collapse() }
                    }
                }
                // A failure without a form (an open or saved network): the words under its row.
                ErrorLine {
                    visible: panel.failed === entry.modelData && panel.asking !== entry.modelData && panel.failure !== ""
                    x: panel.textX
                    width: parent.width - panel.textX
                    text: panel.failure
                }
            }
        }
    }

    // ---- Wi-Fi off: one sentence for the Wi-Fi sections -------------------------------------------------------
    Column {
        visible: panel.wifi !== null && !Networking.wifiEnabled
        width: parent.width
        topPadding: wiredSection.visible || tsSection.visible ? Theme.panel.sectionGap : Theme.space.s5
        Txt {
            width: parent.width
            height: implicitHeight
            wrapMode: Text.Wrap
            maximumLineCount: 2
            text: "Wi-Fi is off." + (Net.onWired ? " Ethernet is connected." : " Nothing is connected.")
            color: Theme.colors.textMuted
        }
    }

    // ---- Footer ---------------------------------------------------------------------------------------------------
    Item { width: parent.width; height: Theme.space.s5 }
    PanelFooter {
        action: panel.settingsApp ? "network settings" : ""
        command: ["nm-connection-editor"]
        backend: "nmcli · tailscale"
    }

    // A text button with a chevron: the exit node's choice ("none ▾"), opening the list under it.
    component DropButton: Item {
        id: drop
        property string text: ""
        property bool open: false
        property bool enabled: true
        signal clicked()
        implicitWidth: dropRow.implicitWidth + 2 * Theme.space.s2
        implicitHeight: Theme.size.hitTarget
        activeFocusOnTab: enabled
        HoverFill { disabled: !drop.enabled; pressed: dropMouse.pressed; hovered: dropMouse.containsMouse || drop.open }
        Row {
            id: dropRow
            x: Theme.space.s2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.s1
            Txt { anchors.verticalCenter: parent.verticalCenter; text: drop.text; color: drop.enabled ? Theme.colors.text : Theme.states.disabled }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: drop.open ? Glyphs.chevronUp : Glyphs.chevronDown
                color: drop.enabled ? Theme.colors.text : Theme.states.disabled
            }
        }
        FocusRing { visible: drop.activeFocus }
        MouseArea {
            id: dropMouse
            anchors.fill: parent
            enabled: drop.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: drop.clicked()
        }
        Keys.onPressed: event => {
            if (drop.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                drop.clicked();
                event.accepted = true;
            }
        }
    }
}
