import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs
import qs.components
import qs.services

// The right side of the bar, in two groups (whitespace, no rules):
//   status    [drawer ←] chevron · pinned apps (bar/TrayDrawer) · keep awake · Claude Code · network, Bluetooth,
//             brightness, volume, notifications, light / dark: one run of 32 px slots, no gap after the tray row (the
//             owner's choice); the other tray icons slide out left of the chevron, so nothing right of it moves
//   session   power: lock, log out, reboot, shut down, straight after light / dark in the same run of slots (the
//             owner's choice, 15 October 2026 evening; it stood 24 px from glyph to glyph, a group of its own, before)
// One glyph per slot (Swiss Glyphs, 16 px, on the baseline with the numerals), each slot 32 px wide (the hit target).
// Every slot is always there, so nothing moves when a state changes. A state is a shape, never a colour alone: off and
// muted are struck through, unread is the bell's square, keep awake is a ring or a filled circle. Inactive glyphs are muted; amber only for a degraded state, with a word in the tooltip.
Row {
    id: status
    spacing: 0

    // A slot holding one glyph.
    component IconSlot: BarSlot {
        id: islot
        property alias name: glyph.name
        property alias color: glyph.color
        fixedWidth: Theme.size.hitTarget
        Icon {
            id: glyph
            x: Math.round((islot.width - width) / 2)
            y: Theme.bar.iconTop
        }
    }

    // ---- Tray row (design/tray-row): the drawer and its chevron, keep awake, Claude Code -----------------------
    TrayDrawer { id: tray }

    // Keep awake: the shell's own idle inhibitor (services/Caffeine, held in bar/Bar). The shell's own on/off mark, 10 px:
    // a ring while the screen may sleep, a filled circle while it is kept awake (the owner's pick on 15 October 2026,
    // after a cup, an eye and a "Zz"); ink either way, the state is the shape. A click toggles; also Super+Alt+C and
    // the dashboard's Caffeine switch.
    IconSlot {
        id: awake
        tipDelay: Theme.trayRow.tipDelay
        tooltip: (Caffeine.on ? "keep awake: on" + (Caffeine.until > 0 ? " until " + Qt.formatTime(new Date(Caffeine.until), "HH:mm") : "")
                + " · screen won't sleep"
            : "keep awake: off · click to stop the screen sleeping") + " · Super+Alt+C"
        onClicked: button => { if (button === Qt.LeftButton) Caffeine.toggle() }
        name: Caffeine.on ? Theme.icons.awake : Theme.icons.awakeOff
    }

    // Claude Code: Claude's own mark filled with ink at 16 px, like a glyph; amber once a reported plan limit passes
    // 80 % (the tooltip says "near limit"). Not a tray app: a click opens the shell's Claude Code panel.
    IconSlot {
        id: claudeSlot
        tipDelay: Theme.trayRow.tipDelay
        // A window that has reset since the last report says nothing about now: left out (ClaudeUsage.current).
        readonly property var five: ClaudeUsage.current(ClaudeUsage.limits?.five_hour)
        readonly property var week: ClaudeUsage.current(ClaudeUsage.limits?.seven_day)
        readonly property bool high: ClaudeUsage.near(ClaudeUsage.limits?.five_hour) || ClaudeUsage.near(ClaudeUsage.limits?.seven_day)
        visible: ClaudeUsage.installed
        panel: "claude"
        tooltip: "Claude Code" + (high ? " · near limit" : "") + (five ? " · 5h " + Math.round(five.used_percentage) + " %" : "")
            + (week ? " · week " + Math.round(week.used_percentage) + " %" : "") + " · Super+Ctrl+K"
        name: Theme.icons.claude
        color: high ? Theme.colors.warn : Theme.colors.text
    }

    // ---- Status -----------------------------------------------------------------------------------

    // The running cat (the owner's choice, 23 October 2026, as on NixPad): RunCat's cat from the Waycat font (~/nixos fonts.nix) on the baseline, Theme.cat.size like the NixOS mark; asleep and muted under Theme.cat.sleepBelow % processor load (Metrics.cpu, every second), running in ink faster as it rises; hidden until the font is installed; a click opens the dashboard
    BarSlot {
        id: catSlot
        readonly property bool awake: Metrics.cpu >= Theme.cat.sleepBelow
        property int frame: 0
        visible: Qt.fontFamilies().includes("Waycat")
        fixedWidth: Theme.size.hitTarget
        tooltip: "processor " + (Metrics.cpu < 0 ? "…" : Math.round(Metrics.cpu) + " %") + " · Super+D"
        onClicked: button => { if (button === Qt.LeftButton) Panels.toggle("dashboard", catSlot) }
        Text {
            x: Math.round((catSlot.width - width) / 2)
            // Its feet on the glyphs' last ink row: their 14 px live area ends 1 px above the baseline (measured in a rig)
            anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline - 1 }
            font { family: "Waycat"; pixelSize: Theme.cat.size }
            color: catSlot.awake ? Theme.colors.text : Theme.colors.textMuted
            text: catSlot.awake ? "ABCDE"[catSlot.frame] : "J"
        }
        Timer {
            running: catSlot.awake && catSlot.visible
            repeat: true
            interval: Math.ceil((Theme.cat.strideMin + Theme.cat.strideRange * Math.pow(1 - Metrics.cpu / 100, 2)) / 5)
            onTriggered: catSlot.frame = (catSlot.frame + 1) % 5
        }
    }

    // Network: the full Wi-Fi fan while connected, whatever the signal (the owner reads the strength in the network
    // panel; a fan with hairline arcs was the lightest glyph in the bar); the bare fan with Wi-Fi on but no network;
    // struck through with Wi-Fi off; the network glyph on a cable.
    IconSlot {
        id: wifiSlot
        panel: "network"
        // While a Tailscale exit node carries the traffic, the tip says through whom.
        tooltip: Net.label + (Net.detail ? " · " + Net.detail : "")
            + (Tailscale.exitNode !== "" ? " · via " + Tailscale.exitNode : "") + " · Super+Ctrl+W"
        name: Net.onWired ? Theme.icons.lan
            : Net.wifiNetwork ? Theme.icons.wifi[4]
            : Net.wifi && Networking.wifiEnabled ? Theme.icons.wifi[0]
            : Net.wired ? Theme.icons.lanOff : Theme.icons.wifiOff
        color: Net.online && !Net.limited ? Theme.colors.text : Net.online ? Theme.colors.warn : Theme.colors.textMuted
    }

    // Bluetooth: there whenever the machine has an adapter; off is struck through, connected has the side marks.
    IconSlot {
        id: btSlot
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool adapterOn: adapter !== null && adapter.enabled
        readonly property var connectedDevices: (adapter?.devices?.values ?? []).filter(d => d.connected)
        visible: adapter !== null
        panel: "bluetooth"
        tooltip: (!adapterOn ? "Bluetooth off"
            : connectedDevices.length > 0 ? connectedDevices.map(d => d.name).join(", ") : "Bluetooth on, nothing connected")
            + " · Super+Ctrl+B"
        name: !adapterOn ? Theme.icons.bluetoothOff : connectedDevices.length > 0 ? Theme.icons.bluetoothOn : Theme.icons.bluetooth
        color: adapterOn ? Theme.colors.text : Theme.colors.textMuted
    }

    // Brightness (design/display BarModule): the sun, immediately left of volume; the monitor's own backlight over
    // DDC/CI. The glyph never changes with the level: the value is in the tooltip and the OSD. The wheel steps 5 %
    // (merged into one write, the OSD shows); a click opens the Display panel.
    IconSlot {
        panel: "display"
        tooltip: !Brightness.ready ? (Brightness.state === "missing" ? "Brightness: ddcutil is not installed" : Brightness.state === "unknown" ? "Brightness: looking for the monitor" : "Brightness: no DDC/CI monitor")
            : "brightness " + Brightness.percent(Brightness.current.b, Brightness.shown(Brightness.current.b)) + " %"
        onScrolled: steps => Brightness.step(steps)
        name: Theme.icons.brightness
    }

    // Volume: the speaker with 0-2 waves by level, struck through while muted; no number in the bar. Middle (or right)
    // click mutes, the wheel steps 5 %; the value and the devices are in the audio popover.
    IconSlot {
        panel: "audio"
        tooltip: Audio.ready ? Audio.nodeName(Audio.sink) + " · " + (Audio.muted ? "muted" : Audio.percent + " %") + " · middle click mutes" : "No audio output"
        onClicked: button => { if (button === Qt.MiddleButton || button === Qt.RightButton) Audio.toggleMute() }
        onScrolled: steps => Audio.step(Theme.panel.volumeStep / 100 * steps)
        name: !Audio.ready || Audio.muted ? Theme.icons.volumeMuted
            : Theme.icons.volume[Audio.volume <= 0 ? 0 : Audio.volume < 0.5 ? 1 : 2]
        color: Audio.ready && !Audio.muted ? Theme.colors.text : Theme.colors.textMuted
    }

    // Notifications: the bell; its square when there are unread ones; struck through in do not disturb.
    IconSlot {
        panel: "notifications"
        tooltip: (Prefs.dnd ? "Do not disturb" : Notifs.unread > 0 ? Notifs.unread + " unread" : "No new notifications") + " · Ctrl+Alt+\\"
        name: Prefs.dnd ? Theme.icons.bellOff : Notifs.unread > 0 ? Theme.icons.bellUnread : Theme.icons.bell
        color: Prefs.dnd ? Theme.colors.textMuted : Theme.colors.text
    }

    // Light / dark: one click switches the whole desktop (and is remembered); the tooltip names the mode in a word.
    IconSlot {
        tooltip: (Theme.dark ? "DARK" : "LIGHT") + " · click for " + (Theme.dark ? "light" : "dark") + " · Super+Shift+T"
        onClicked: button => { if (button === Qt.LeftButton) Theme.toggleMode() }
        name: Theme.icons.theme
    }


    // ---- Session ----------------------------------------------------------------------------------
    IconSlot {
        panel: "power"
        tooltip: "Lock, log out, reboot, shut down · Super+Esc"
        name: Theme.icons.power
    }
}
