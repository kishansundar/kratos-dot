import QtQuick
import qs
import qs.components
import qs.services

// Controls (design/dashboard v2 Controls): a 32 px header row ("feature", "state"), then two 32 px rows per control:
//   ● Caffeine                                           until 18:48     the switch row: the mark (filled on, a ring off),
//       30m  1h  [2h]  off                                               the name (600 when on), the state word; then
//                                                                        its option row, indented to the name
// No glyphs (the names say it), never a filled block, never the accent. Off rows are muted. While a command runs the
// word is "…"; a failure snaps back with "failed" in the error colour and the message in the tooltip.
//   Tailscale        up with Tailscale's DNS off; the option "tailscale dns" turns it on. The word: the tailnet IPv4
//                    when connected, "stopped", or "needs login" with a triangle (the link in the tooltip)
//   Night light      the option: a 2500-6500 K ruler with the value at its right. A right click on the switch row puts
//                    "sunset → sunrise" in the option row instead, until the next right click
//   Caffeine, DND    the hold: 30m · 1h · 2h · off ("off": until switched off); DND also counts what it held
Column {
    id: list
    readonly property int indent: Theme.size.markCircle + Theme.space.s3
    property bool nightMenu: false

    function clock(ms) { return Qt.formatTime(new Date(ms), "HH:mm") }

    // ---- The parts -----------------------------------------------------------------------------------------------
    component Rule: Rectangle { y: parent.height - height; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }

    component SwitchRow: Item {
        id: sw
        property string name: ""
        property bool on: false
        property string word: ""
        property bool busy: false
        property string error: ""
        property bool enabled: true
        property bool attention: false
        property string note: ""
        signal toggled()
        signal menu()
        readonly property bool failed: error !== ""
        readonly property bool live: enabled && !busy
        readonly property color ink: !enabled ? Theme.states.disabled : on ? Theme.colors.text : Theme.colors.textMuted

        width: list.width
        height: Theme.dash.listRow
        activeFocusOnTab: enabled

        Rectangle { anchors.fill: parent; color: mouse.containsMouse && sw.live ? Theme.states.hover : "transparent"; Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } } }
        Mark { anchors.verticalCenter: parent.verticalCenter; kind: sw.on ? "circle" : "ring"; color: sw.ink }
        Txt {
            x: list.indent
            anchors.verticalCenter: parent.verticalCenter
            text: sw.name
            variant: sw.on ? Theme.font.bodyStrong : Theme.font.body
            color: sw.ink
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s1
            Mark { visible: sw.attention && !sw.failed && !sw.busy; anchors.verticalCenter: parent.verticalCenter; kind: "triangle"; color: sw.ink }
            Icon { visible: sw.failed && !sw.busy; anchors.verticalCenter: parent.verticalCenter; name: Theme.icons.error; color: Theme.colors.error }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                variant: sw.on ? Theme.font.labelStrong : Theme.font.label
                text: sw.busy ? "…" : sw.failed ? "failed" : sw.word
                color: sw.failed && !sw.busy ? Theme.colors.error : sw.ink
            }
        }
        FocusRing { visible: sw.activeFocus }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: sw.live ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: event => { if (event.button === Qt.RightButton) sw.menu(); else if (sw.live) sw.toggled(); }
            onContainsMouseChanged: {
                if (containsMouse && (sw.failed || sw.note !== "")) Tip.show(sw, sw.width / 2, sw.height, sw.failed ? sw.error : sw.note);
                else Tip.hide(sw);
            }
        }
        Keys.onPressed: event => {
            if (sw.live && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                sw.toggled();
                event.accepted = true;
            }
        }
        Rule {}
    }

    // An option row's small switch: the mark and its words in mono ("tailscale dns").
    component OptionSwitch: Item {
        id: opt
        property string word: ""
        property bool on: false
        property bool enabled: true
        signal toggled()
        width: optRow.implicitWidth + 2 * Theme.space.s2
        height: Theme.dash.listRow
        x: -Theme.space.s2
        activeFocusOnTab: enabled
        Rectangle { anchors.fill: parent; color: optMouse.containsMouse && opt.enabled ? Theme.states.hover : "transparent"; Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } } }
        Row {
            id: optRow
            x: Theme.space.s2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.s2
            Mark { anchors.verticalCenter: parent.verticalCenter; kind: opt.on ? "circle" : "ring"; color: opt.enabled ? Theme.colors.text : Theme.states.disabled }
            Annot { text: opt.word; color: opt.enabled ? Theme.colors.text : Theme.states.disabled }
        }
        FocusRing { visible: opt.activeFocus }
        MouseArea { id: optMouse; anchors.fill: parent; hoverEnabled: true; enabled: opt.enabled; cursorShape: Qt.PointingHandCursor; onClicked: opt.toggled() }
        Keys.onPressed: event => {
            if (opt.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) { opt.toggled(); event.accepted = true; }
        }
    }

    component OptionRow: Item {
        default property alias content: inner.data
        width: list.width
        height: Theme.dash.listRow
        Item { id: inner; x: list.indent; width: parent.width - list.indent; height: parent.height }
        Rule {}
    }

    // ---- The header ----------------------------------------------------------------------------------------------
    Item {
        width: list.width
        height: Theme.dash.listRow
        Txt { x: list.indent; anchors.verticalCenter: parent.verticalCenter; variant: Theme.font.label; text: "feature"; color: Theme.colors.textMuted }
        Txt { anchors { right: parent.right; verticalCenter: parent.verticalCenter } variant: Theme.font.label; text: "state"; color: Theme.colors.textMuted }
        Rule {}
    }

    // ---- Tailscale ------------------------------------------------------------------------------------------------
    SwitchRow {
        name: "Tailscale"
        on: Tailscale.state === "connected" || Tailscale.state === "starting"
        word: !Tailscale.hasChecked ? "…" : Tailscale.state === "connected" ? (Tailscale.ip || "connected")
            : ({ "disconnected": "stopped", "needs-login": "needs login", "starting": "starting", "service-down": "not running",
                 "not-installed": "not installed", "unknown": "unknown" })[Tailscale.state]
        busy: Tailscale.busy
        error: Tailscale.error
        enabled: Tailscale.hasChecked && Tailscale.state !== "not-installed" && Tailscale.state !== "service-down"
        attention: Tailscale.state === "needs-login"
        note: Tailscale.state === "needs-login" && Tailscale.loginUrl !== "" ? "log in at " + Tailscale.loginUrl : ""
        onToggled: Tailscale.setRunning(!on)
    }
    OptionRow {
        OptionSwitch {
            anchors.verticalCenter: parent.verticalCenter
            word: "tailscale dns"
            on: Tailscale.dns
            enabled: Tailscale.hasChecked && !Tailscale.busy && Tailscale.state !== "not-installed" && Tailscale.state !== "service-down"
            onToggled: Tailscale.setDns(!Tailscale.dns)
        }
    }

    // ---- Night light ---------------------------------------------------------------------------------------------------
    SwitchRow {
        id: nightRow
        property int pending: -1               // the temperature being dragged to, committed after a pause
        readonly property int shown: pending > 0 ? pending : NightLight.temp
        name: "Night light"
        on: NightLight.on
        word: NightLight.unsupported ? "unsupported" : NightLight.on ? shown + " K" : "off"
        error: NightLight.error
        enabled: !NightLight.unsupported
        onToggled: NightLight.setOn(!NightLight.on)
        onMenu: list.nightMenu = !list.nightMenu
    }
    OptionRow {
        RulerSlider {
            id: nightRuler
            visible: !list.nightMenu
            width: parent.width - nightValue.width - Theme.space.s3
            height: parent.height
            divisions: (Theme.control.nightTempMax - Theme.control.nightTempMin) / 500       // a tick every 500 K
            majorEvery: 4
            keyStep: Theme.control.nightTempStep / (Theme.control.nightTempMax - Theme.control.nightTempMin)
            accentHandle: false
            interactive: !NightLight.unsupported
            dimmed: !NightLight.on
            value: (nightRow.shown - Theme.control.nightTempMin) / (Theme.control.nightTempMax - Theme.control.nightTempMin)
            onMoved: v => {
                const c = Theme.control;
                nightRow.pending = Math.round((c.nightTempMin + v * (c.nightTempMax - c.nightTempMin)) / c.nightTempStep) * c.nightTempStep;
                commit.restart();
            }
            Timer { id: commit; interval: 300; onTriggered: { NightLight.setTemp(nightRow.pending); nightRow.pending = -1; } }
        }
        Annot {
            id: nightValue
            visible: !list.nightMenu
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: nightRow.shown + " K"
        }
        OptionSwitch {
            visible: list.nightMenu
            anchors.verticalCenter: parent.verticalCenter
            word: NightLight.place !== "" ? "sunset → sunrise · " + NightLight.place : "sunset → sunrise"
            on: NightLight.schedule
            enabled: !NightLight.unsupported && NightLight.place !== ""
            onToggled: NightLight.setSchedule(!NightLight.schedule)
        }
    }

    // ---- Caffeine ----------------------------------------------------------------------------------------------------
    SwitchRow {
        name: "Caffeine"
        on: Caffeine.on
        word: !Caffeine.on ? "off" : Caffeine.until > 0 ? "until " + list.clock(Caffeine.until) : "on"
        onToggled: Caffeine.toggle()
    }
    OptionRow {
        Segment {
            x: -Theme.space.s2
            anchors.verticalCenter: parent.verticalCenter
            options: Theme.control.holdOptions
            current: Prefs.caffeineHold
            onPicked: v => Caffeine.setHold(v)
        }
    }

    // ---- Do not disturb ----------------------------------------------------------------------------------------------
    SwitchRow {
        name: "Do not disturb"
        on: Prefs.dnd
        word: !Prefs.dnd ? "off" : Prefs.dndUntil > 0 ? "until " + list.clock(Prefs.dndUntil) : "on"
        onToggled: Notifs.setDnd(!Prefs.dnd)
    }
    OptionRow {
        Segment {
            x: -Theme.space.s2
            anchors.verticalCenter: parent.verticalCenter
            options: Theme.control.holdOptions
            current: Prefs.dndHold
            onPicked: v => Notifs.setDndHold(v)
        }
        Annot {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: Prefs.dnd ? Notifs.held + " held" : Notifs.today() + " today"
        }
    }
}
