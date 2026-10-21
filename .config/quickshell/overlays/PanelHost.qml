import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Where every popup is shown (Popup). One transparent layer below the bar (so the bar stays clickable and switching
// popups is one click) that holds the keyboard while open and closes on a click outside the card or Esc.
// The card hangs flush from the bar's bottom rule under the module that opened it: left-aligned under the left group,
// right-aligned under the right group, centred under the clock; the launcher hangs under the NixOS mark (Panels); the
// clipboard sits in the upper middle. Open: opacity 0 to 1 and an 8 px slide down, 180 ms, OutCubic; close: the
// reverse, InCubic.
// Switch (one popover open, another asked for, from the bar or a key): the card stays. Its content fades out (fast),
// the new one loads and fades in (med) while the card moves and resizes to it (motion.spatial, OutCubic, no
// overshoot), what does not fit yet cut at its border. A switch during a switch starts from where the card is. The
// dashboard and the clipboard are sheets of their own: switching to or from them opens them afresh, as before.
PanelWindow {
    id: host

    readonly property var files: ({
        launcher: "Launcher", clipboard: "Clipboard", power: "PowerPanel", calendar: "DateTimePanel",
        audio: "AudioPanel", display: "DisplayPanel", network: "NetworkPanel", notifications: "NotificationsPanel",
        bluetooth: "BluetoothPanel", claude: "ClaudePanel", media: "NowPlayingPanel", dashboard: "DashboardPanel",
        traymenu: "TrayMenu"
    })

    // The popup on show: the open one, or, for the length of the closing fade, the one that just closed.
    readonly property bool wanted: Panels.current !== "" && files[Panels.current] !== undefined
    property string shown: ""
    property bool closing: false
    onWantedChanged: {
        if (wanted) { closeAnim.stop(); switchAnim.stop(); card.settle(); closing = false; shown = Panels.current; openAnim.restart(); }
        else if (shown !== "") { switchAnim.stop(); closing = true; closeAnim.restart(); }
    }
    Connections {
        target: Panels
        function onCurrentChanged() {
            // Opening from nothing (or over a closing card) is onWantedChanged's.
            if (!host.wanted || host.shown === Panels.current || host.shown === "" || host.closing) return;
            if (card.hangs(host.shown) && card.hangs(Panels.current)) { card.hold(); switchAnim.restart(); }
            else { switchAnim.stop(); card.settle(); host.shown = Panels.current; openAnim.restart(); }
        }
    }

    screen: Panels.screen
    // Every popup but the wallpaper picker, which is its own window (overlays/WallpaperPicker.qml).
    visible: shown !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "swiss-popup"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // A click outside the card closes; a click on the card's empty parts does nothing.
    MouseArea { anchors.fill: parent; enabled: host.wanted; onClicked: Panels.close() }
    MouseArea { x: card.x; y: card.y; width: card.width; height: card.height }

    Card {
        id: card
        // The dashboard floats in the middle of the screen, both ways, whatever opened it; it fades in without the 8 px
        // slide (design/dashboard v2: it hangs from nothing).
        readonly property bool middle: host.shown === "dashboard"
        // Centred (the clipboard) by what is shown, not by Panels.current: close() empties current before the fade
        // out, and the card jumped to the top for it.
        readonly property bool centred: Panels.centred.includes(host.shown)
        readonly property bool anchored: !middle && !centred && Panels.anchorX >= 0
        // Where it hangs: by the third of the screen its module is in.
        readonly property string side: !anchored ? "centre"
            : Panels.anchorX < host.width / 3 ? "left" : Panels.anchorX > host.width * 2 / 3 ? "right" : "centre"
        readonly property real wantX: side === "left" ? Panels.anchorLeft
            : side === "right" ? Panels.anchorRight - wantW
            : anchored ? Panels.anchorX - wantW / 2 : (host.width - wantW) / 2
        // Each popup is as wide as its own column plus the padding: 384 for the popovers. A panel may ask for less
        // (`cardPadding`: the tray menu, 8). The panel's own width (its column), not its implicit width: a list that
        // bleeds or a line longer than the column must not widen the card.
        readonly property real wantW: (loader.item ? loader.item.width : 0) + 2 * padding
        readonly property real wantH: (loader.item ? loader.item.height : 0) + 2 * padding
        readonly property real wantLeft: Math.round(Math.max(0, Math.min(host.width - wantW, wantX)))
        padding: loader.item && loader.item.cardPadding !== undefined ? loader.item.cardPadding : Theme.space.s5

        // A switch: from where the card was (held) to where the new popup wants it, `morph` running 0 to 1.
        property bool morphing: false
        property real morph: 1
        property real fromX: 0
        property real fromW: 0
        property real fromH: 0
        function hangs(name) { return name !== "dashboard" && !Panels.centred.includes(name) }
        function hold() { fromX = x; fromW = width; fromH = height; morph = 0; morphing = true; }
        function settle() { morphing = false; morph = 1; body.opacity = 1; }
        function between(a, b) { return Math.round(a + (b - a) * morph) }

        x: morphing ? between(fromX, wantLeft) : wantLeft
        width: morphing ? between(fromW, wantW) : wantW
        height: morphing ? between(fromH, wantH) : wantH
        y: (middle ? Math.max(0, Math.round((host.height - height) / 2))
                   : centred ? Math.round(host.height * 0.16) : 0) + slide
        property real slide: 0
        opacity: 0

        // The card's inside (within its border): while the card moves, what does not fit yet is cut here.
        Item {
            id: body
            x: Theme.size.rule - card.padding
            y: Theme.size.rule - card.padding
            width: card.width - 2 * Theme.size.rule
            height: card.height - 2 * Theme.size.rule
            clip: card.morphing

            FocusScope {
                x: card.padding - Theme.size.rule
                y: card.padding - Theme.size.rule
                width: loader.item ? loader.item.width : 0
                height: loader.item ? loader.item.height : 0
                focus: true
                Keys.onEscapePressed: Panels.close()

                Loader {
                    id: loader
                    focus: true
                    active: host.shown !== ""
                    source: host.shown !== "" ? Qt.resolvedUrl("../panels/" + host.files[host.shown] + ".qml") : ""
                    onStatusChanged: if (status === Loader.Error) console.warn("PanelHost: cannot load", source, Qt.createComponent(source).errorString())
                }
            }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.motion.med; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "slide"; from: card.middle ? 0 : -Theme.motion.slide; to: 0; duration: Theme.motion.med; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.motion.med; easing.type: Easing.InCubic }
            NumberAnimation { target: card; property: "slide"; to: card.middle ? 0 : -Theme.motion.slide; duration: Theme.motion.med; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { host.closing = false; host.shown = ""; card.settle(); } }
    }
    SequentialAnimation {
        id: switchAnim
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: Theme.motion.fast; easing.type: Easing.InCubic }
        // The latest one asked for: a switch during the fade goes straight there.
        ScriptAction { script: host.shown = Panels.current }
        ParallelAnimation {
            NumberAnimation { target: card; property: "morph"; from: 0; to: 1; duration: Theme.motion.spatial; easing.type: Easing.OutCubic }
            NumberAnimation { target: body; property: "opacity"; to: 1; duration: Theme.motion.med; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: card.settle() }
    }
}
