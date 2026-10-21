import QtQuick
import Quickshell
import qs
import qs.components
import qs.services
import "../services/Format.js" as Format

// Bluetooth (design/panels BluetoothPanel; the Bluetooth glyph in the bar, or Super+Ctrl+B). Everything is done here,
// passkeys and PINs included; nothing hands off to a terminal. Every change goes through services/Bt, which reads the
// result back: a row shows "…" while its command runs, then the real state, or why it failed.
//   heading     "Bluetooth" and the adapter's switch (a circle and the word)
//   CONNECTED   filled circle, name, the battery as a mini ruler and "NN %" in mono when the device reports it (under
//               20 %: the attention triangle before it, "low" in the tooltip), the headphones glyph for audio. Choosing
//               a row shows its actions: disconnect, and for audio "audio output" (its PipeWire output becomes the
//               default)
//   PAIRED      ring, name, what it is in mono (the headphones glyph for audio): one click connects
//   NEARBY      only while searching: devices not paired, by name; one click pairs (and a paired device is then
//               trusted and connected). Devices without a name (mostly phones, watches and earbuds announcing
//               themselves from rotating random addresses, not asking to pair) fold into one faint line, "show N
//               without a name", that lists them after the named ones. The eyebrow counts the search down. The search
//               starts when this opens and stops when it closes, or after Theme.panel.scanTimeout.
//   pairing     a device's request expands its row (services/BtAgent: it opens this panel by itself): the code to
//               confirm in display with "pair" (the panel's one accent) and cancel; the code to type on a keyboard; a
//               PIN or passkey field for a device that asks for one. What is typed is the panel's (reqCode), not the
//               row's: a row made again, or the request moving to the panel's own block when its device leaves the
//               lists (the search ended), shows it again, the field focused
//   footer      "stop searching" / "search again", and the adapter in mono
// Right click a paired device to remove it (asked first). Off: one sentence and the number of paired devices.
// Keys: ↑↓ or Tab choose a device, Enter acts on it (or answers a request), Delete asks to remove it, S searches or
// stops, N shows or hides the devices without a name, Esc cancels a question, closes a row's actions, then closes the
// panel. For the first Theme.panel.answerDelay of a request (BtAgent.armed) every key does nothing and its field and
// buttons are off, so keys meant for another window cannot pair, refuse or remove anything.
Column {
    id: panel
    width: Theme.panel.column
    focus: true

    function byName(a, b) { return a.name.localeCompare(b.name) }
    readonly property var connected: Bt.on ? Bt.devices.filter(d => d.connected).sort(byName) : []
    readonly property var paired: Bt.on ? Bt.devices.filter(d => Bt.known(d) && !d.connected).sort(byName) : []
    // Unnamed devices (BlueZ gives only the address as their name) are folded away until asked for, then come after
    // the named ones.
    property bool showNameless: false
    readonly property int namelessCount: Bt.discovering ? Bt.devices.filter(d => !Bt.known(d) && d.deviceName === "").length : 0
    readonly property var nearby: Bt.discovering
        ? Bt.devices.filter(d => !Bt.known(d) && (showNameless || d.deviceName !== ""))
            .sort((a, b) => ((a.deviceName === "") - (b.deviceName === "")) || byName(a, b))
        : []
    readonly property var rows: connected.concat(paired).concat(nearby)
    readonly property int pairedCount: Bt.devices.filter(d => Bt.known(d)).length

    property int current: -1
    property string opened: ""      // the address of the connected device whose actions are shown
    property string removing: ""    // the address of the device asked about removal
    readonly property var req: BtAgent.request
    // Where the request is answered: under its device's row, or on its own when the shell cannot tell which device.
    readonly property string reqAddress: req && BtAgent.device && rows.some(d => d.address === BtAgent.device.address) ? BtAgent.device.address : ""
    property string reqCode: ""     // the PIN or passkey typed so far for this request
    // The keys come back to the panel with each new request or its end: a code field that had them is hidden then, and
    // keys sent to a hidden item reach only the panel host (Esc closed the panel). The field takes them again itself.
    onReqChanged: { reqCode = ""; forceActiveFocus(); }
    function indexOf(d) { return d ? rows.findIndex(x => x.address === d.address) : -1 }
    function byAddress(a) { return rows.find(d => d.address === a) ?? null }

    Component.onCompleted: Bt.search(true)
    Component.onDestruction: if (Bt.searchEnds > 0 || Bt.searchPending) Bt.search(false)

    // The search's countdown, once a second while it runs.
    property real now: Date.now()
    Timer { running: Bt.discovering; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: panel.now = Date.now() }
    readonly property string searchText: {
        if (!Bt.discovering) return "";
        if (Bt.searchEnds <= 0) return "searching …";
        const s = Math.max(0, Math.ceil((Bt.searchEnds - now) / 1000));
        return "searching … " + Format.mmss(s);
    }

    function act(d) {
        if (!d || Bt.busy(d)) return;
        removing = "";
        if (d.connected) opened = opened === d.address ? "" : d.address;
        else if (Bt.known(d)) Bt.connect(d);
        else Bt.pair(d);
    }
    function askRemove(d) { if (d && Bt.known(d)) { removing = d.address; opened = ""; } }

    Keys.onPressed: event => {
        const k = event.key;
        if (req && !BtAgent.armed) { event.accepted = true; return; }
        if (k === Qt.Key_Escape) {
            if (removing !== "") removing = "";
            else if (req) BtAgent.refuse();
            else if (opened !== "") opened = "";
            else return;                       // the panel host closes
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab) current = Math.min(rows.length - 1, current + 1);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab) current = Math.max(0, current - 1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (removing !== "") { const d = byAddress(removing); removing = ""; if (d) Bt.forget(d); }
            else if (req && req.kind !== "pin" && req.kind !== "passkey" && req.kind !== "display") BtAgent.answer("yes");
            else act(rows[current]);
        } else if (k === Qt.Key_Delete) askRemove(rows[current]);
        else if (k === Qt.Key_S) Bt.search(!Bt.discovering);
        else if (k === Qt.Key_N && namelessCount > 0) showNameless = !showNameless;
        else return;
        event.accepted = true;
    }

    Heading {
        title: "Bluetooth"
        Switch {
            visible: Bt.present
            checked: Bt.on
            onToggled: Bt.setEnabled(!Bt.on)
        }
    }
    Item { width: Theme.size.rule; height: Theme.space.s5 }

    // ---- No adapter, or off ---------------------------------------------------------------------------------
    Txt {
        visible: !Bt.on
        width: parent.width
        text: !Bt.present ? "No Bluetooth adapter." : "Bluetooth is off."
        color: Theme.colors.textMuted
    }
    Annot {
        visible: Bt.present && !Bt.on
        topPadding: Theme.space.s2
        text: panel.pairedCount + (panel.pairedCount === 1 ? " paired device" : " paired devices")
        color: Theme.colors.textFaint
    }

    // ---- A request the shell cannot place under a row -------------------------------------------------------
    Column {
        visible: Bt.on && panel.req !== null && panel.reqAddress === ""
        width: parent.width
        SectionHead { title: "Pairing" }
        PairingRequest { width: parent.width; device: BtAgent.device }
        Item { width: Theme.size.rule; height: Theme.panel.sectionGap }
    }

    // The lists are keyed by device (ScriptModel): a device appearing, leaving or moving keeps every other row, and
    // what it shows (a request being answered, its actions, a question, a tooltip).
    // ---- Connected ------------------------------------------------------------------------------------------
    SectionHead { visible: panel.connected.length > 0; title: "Connected" }
    Repeater {
        model: ScriptModel { values: panel.connected }
        DeviceEntry {}
    }

    // ---- Paired ---------------------------------------------------------------------------------------------
    Item { visible: panel.paired.length > 0 && panel.connected.length > 0; width: Theme.size.rule; height: Theme.panel.sectionGap }
    SectionHead { visible: panel.paired.length > 0; title: "Paired" }
    Repeater {
        model: ScriptModel { values: panel.paired }
        DeviceEntry {}
    }

    Txt {
        visible: Bt.on && panel.connected.length === 0 && panel.paired.length === 0 && !Bt.discovering
        width: parent.width
        height: Theme.size.hitTarget
        text: "No paired devices."
        color: Theme.colors.textMuted
    }

    // ---- Nearby, while searching ----------------------------------------------------------------------------
    Item { visible: Bt.discovering && (panel.connected.length > 0 || panel.paired.length > 0); width: Theme.size.rule; height: Theme.panel.sectionGap }
    SectionHead { visible: Bt.discovering; title: "Nearby"; annotation: panel.searchText }
    Txt {
        visible: Bt.discovering && panel.nearby.length === 0
        width: parent.width
        height: Theme.size.hitTarget
        text: "Looking for devices…"
        color: Theme.colors.textMuted
    }
    // Past Theme.panel.listMax the list scrolls inside the panel.
    Flickable {
        id: nearbyList
        visible: panel.nearby.length > 0
        width: parent.width
        height: Math.min(contentHeight, Theme.panel.listMax)
        contentHeight: nearbyColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: nearbyColumn
            width: parent.width
            Repeater {
                model: ScriptModel { values: panel.nearby }
                DeviceEntry {}
            }
        }
    }
    TextButton {
        visible: panel.namelessCount > 0
        text: (panel.showNameless ? "hide " : "show ") + panel.namelessCount + " without a name"
        color: Theme.colors.textFaint
        onClicked: panel.showNameless = !panel.showNameless
    }

    // ---- Footer ---------------------------------------------------------------------------------------------
    Item { visible: Bt.on; width: Theme.size.rule; height: Theme.space.s5 }
    PanelFooter {
        visible: Bt.on
        action: Bt.discovering ? "stop searching" : "search again"
        backend: [Bt.adapterId, (Bt.adapter?.name ?? "").toLowerCase()].filter(s => s !== "").join(" · ")
        onClicked: Bt.search(!Bt.discovering)
    }

    // ---- The tooltip: a cut name in full, and a low battery in words (after the hover delay) --------------------
    property var tipFor: null          // { device, item }
    property bool tipShown: false
    Timer { id: tipDelay; interval: Theme.motion.tooltipDelay; onTriggered: panel.tipShown = true }
    function hoverTip(device, item, wanted) {
        if (wanted) { tipFor = { device: device, item: item }; tipShown = false; tipDelay.restart(); }
        else if (tipFor && tipFor.device.address === device.address) { tipDelay.stop(); tipShown = false; tipFor = null; }
    }
    TipBox {
        id: tip
        readonly property point at: panel.tipFor ? panel.tipFor.item.mapToItem(panel, 0, panel.tipFor.item.height) : Qt.point(0, 0)
        readonly property var d: panel.tipFor ? panel.tipFor.device : null
        parent: panel.parent
        z: 1
        visible: panel.tipShown && d !== null && panel.indexOf(d) >= 0
        x: Math.round(Math.min(panel.width - width, at.x + Theme.space.s3) + panel.x)
        y: Math.round(at.y + panel.y + Theme.space.s1)
        maxWidth: panel.width
        text: !d ? "" : [d.name, d.batteryAvailable ? "battery " + Math.round(d.battery * 100) + " %" + (d.battery < 0.2 ? " · low" : "") : ""]
            .filter(s => s !== "").join(" · ")
    }

    // ---- One device: its row, then what it shows when chosen, asked, pairing or failed ------------------------
    component DeviceEntry: Column {
        id: entry
        required property var modelData
        readonly property var d: modelData
        readonly property bool known: Bt.known(d)
        readonly property string kind: Bt.kind(d)
        readonly property bool audio: kind === "audio"
        readonly property bool busy: Bt.busy(d)
        readonly property bool low: d.batteryAvailable && d.battery < 0.2
        readonly property int row: panel.indexOf(d)
        readonly property string failure: Bt.failed[d.address] ?? ""
        readonly property var sink: audio && d.connected ? Audio.sinkFor(d.address) : null
        readonly property bool showActions: panel.opened === d.address && d.connected && !asked
        readonly property bool asked: panel.removing === d.address
        readonly property bool pairingHere: panel.reqAddress === d.address
        readonly property bool failed: failure !== "" && !busy
        width: parent ? parent.width : 0

        RowItem {
            id: rowItem
            radio: true
            checked: entry.d.connected
            busy: entry.busy
            selected: panel.current === entry.row || panel.opened === entry.d.address
            onHoveredIn: { panel.current = entry.row; panel.hoverTip(entry.d, rowItem, nameText.truncated || entry.low); }
            onHoveredChanged: if (!hovered) panel.hoverTip(entry.d, rowItem, false)
            onActivated: panel.act(entry.d)
            onRightClicked: panel.askRemove(entry.d)

            Txt {
                id: nameText
                anchors { left: parent.left; right: trail.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: entry.d.name + (entry.busy ? " …" : "")
                color: entry.d.deviceName === "" ? Theme.colors.textFaint : Theme.colors.text
            }
            Row {
                id: trail
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                // Connected: the battery, as a mini ruler and a number (the triangle under 20 %).
                Mark {
                    visible: entry.d.connected && entry.low
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "triangle"
                }
                MiniMeter {
                    visible: entry.d.connected && entry.d.batteryAvailable
                    anchors.verticalCenter: parent.verticalCenter
                    value: entry.d.battery
                }
                Annot {
                    visible: entry.d.connected && entry.d.batteryAvailable
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(entry.d.battery * 100) + " %"
                }
                // Paired: what it is; nearby: what a click does, or that it has no name.
                Annot {
                    visible: text !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.d.connected || entry.busy ? ""
                        : entry.known ? (entry.audio ? "" : entry.kind)
                        : entry.d.deviceName === "" ? "no name" : "pair"
                    color: entry.d.deviceName === "" && !entry.known ? Theme.colors.textFaint : Theme.colors.textMuted
                }
                Icon {
                    visible: entry.audio && entry.known
                    anchors.verticalCenter: parent.verticalCenter
                    name: Theme.icons.headphones
                    color: Theme.colors.textMuted
                }
            }
        }

        // The detail, indented to the row's text.
        Column {
            // (From the conditions, not the children's `visible`: a hidden parent hides its children's too.)
            visible: entry.showActions || entry.asked || entry.pairingHere || entry.failed
            x: Theme.space.s3 + Theme.size.markCircle + Theme.space.s3
            width: parent.width - x - Theme.space.s3
            topPadding: Theme.space.s1
            bottomPadding: Theme.space.s3
            spacing: Theme.space.s2

            Row {
                id: actions
                visible: entry.showActions
                spacing: Theme.space.s5
                TextButton { text: "disconnect"; onClicked: { panel.opened = ""; Bt.disconnect(entry.d); } }
                TextButton {
                    visible: entry.audio
                    enabled: entry.sink !== null && entry.sink !== Audio.sink
                    text: "audio output"
                    onClicked: Audio.makeDefault(entry.sink)
                }
            }
            Column {
                id: removeAsk
                visible: entry.asked
                width: parent.width
                spacing: Theme.space.s1
                Txt {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    text: "Remove " + entry.d.name + "? It will need pairing again."
                }
                Row {
                    spacing: Theme.space.s5
                    TextButton { text: "remove"; onClicked: { panel.removing = ""; Bt.forget(entry.d); } }
                    TextButton { text: "cancel"; onClicked: panel.removing = "" }
                }
            }
            PairingRequest {
                id: pairing
                visible: entry.pairingHere
                width: parent.width
                device: entry.d
            }
            ErrorLine {
                id: failLine
                visible: entry.failed
                text: entry.failure
            }
        }
    }

    // ---- A pairing request: what the device asks for, and the answers -------------------------------------------
    component PairingRequest: Column {
        id: request
        property var device: null
        readonly property var r: panel.req
        readonly property string who: device ? device.name : "The device"
        readonly property bool asksCode: !!r && (r.kind === "pin" || r.kind === "passkey")
        onRChanged: Qt.callLater(code.restore)      // a new request while the field stays shown: empty again
        Connections { target: BtAgent; function onArmedChanged() { if (BtAgent.armed) Qt.callLater(code.restore) } }
        function spaced(passkey) { return String(passkey ?? "").replace(/(\d{3})(?=\d)/g, "$1 ") }   // in threes
        spacing: Theme.space.s2

        Txt {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            text: !request.r ? ""
                : request.r.kind === "confirm" ? "Confirm this code on the device:"
                : request.r.kind === "display" ? "Type this code on the device, then Enter:"
                : request.r.kind === "pin" ? "Type the PIN code for " + request.who + "."
                : request.r.kind === "passkey" ? "Type the 6-digit passkey for " + request.who + "."
                : request.r.kind === "authorize" ? request.who + " asks to pair."
                : request.who + " asks to use a service (" + request.r.uuid + ")."
        }
        Txt {
            visible: !!request.r && (request.r.kind === "confirm" || request.r.kind === "display")
            variant: Theme.font.display
            height: Theme.font.display.lineHeight
            text: request.r ? request.spaced(request.r.passkey) : ""
        }
        Field {
            id: code
            visible: request.asksCode
            enabled: BtAgent.armed
            width: parent.width
            placeholder: request.r && request.r.kind === "passkey" ? "000000" : "PIN"
            validator: RegularExpressionValidator { regularExpression: request.r && request.r.kind === "passkey" ? /[0-9]{0,6}/ : /[0-9A-Za-z]{0,16}/ }
            // What is typed is the panel's: this field shows it again when it appears (a new request starts empty) and
            // takes the focus; once its row is in the window (callLater) when the row itself was just made.
            function restore() { if (code.visible) { code.text = panel.reqCode; code.focusInput(); } }
            onVisibleChanged: restore()
            Component.onCompleted: Qt.callLater(restore)
            onTextChanged: if (code.visible) panel.reqCode = code.text
            onAccepted: if (text.length > 0) BtAgent.answer(text)
            onCancelled: { BtAgent.refuse(); panel.forceActiveFocus(); }
        }
        Row {
            spacing: Theme.space.s4
            TextButton {
                visible: !!request.r && request.r.kind !== "display"
                kind: "primary"
                text: request.r && request.r.kind === "service" ? "allow" : "pair"
                enabled: BtAgent.armed && (!request.asksCode || code.text.length > 0)
                onClicked: BtAgent.answer(request.asksCode ? code.text : "yes")
            }
            TextButton {
                enabled: BtAgent.armed
                text: request.r && request.r.kind === "service" ? "refuse" : "cancel"
                onClicked: BtAgent.refuse()
            }
        }
    }
}
