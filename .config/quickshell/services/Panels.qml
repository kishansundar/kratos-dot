pragma Singleton
import QtQuick
import Quickshell

// Which popup is open: only one at a time; opening another closes the first.
//   anchored popups hang flush from the bar under the module that opened them (Popup): left-aligned with modules
//   in the left third of the screen, right-aligned in the right third, centred under the clock's stroke in between;
//   a left-aligned one starts at its slot's `hangLeft` (the launcher, from the NixOS mark: on the mark itself)
//   centred popups (the clipboard) sit in the upper middle of the screen
// Every screen has its own bar, so every panel name has a slot per screen: a click opens the popup from the slot
// clicked (toggle(name, slot)); a key or IPC (no slot) opens it on the focused monitor (mango's "active" one), from
// that screen's slot.
Singleton {
    id: root

    property string current: ""
    property bool trayOpen: false        // the tray drawer in the bar (not a popup: it never covers anything)
    property var trayItem: null           // the tray item whose menu is open (panel "traymenu")
    property var screen: focusedScreen   // the screen the popup is on
    property real anchorX: -1            // the module's anchor point (its middle, or the clock's stroke), screen x
    property real anchorLeft: -1         // the module's left and right edges, screen x
    property real anchorRight: -1
    property var slots: ({})             // panel name -> its bar slots, one per screen's bar
    // `qs ipc call dock focus`: the dock on the focused screen (if it is showing) takes the keyboard.
    signal dockFocusRequested()

    // The focused monitor's screen, else the first: where a key or IPC opens a popup, and the toasts and the OSD show.
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Mango.focused) ?? Quickshell.screens[0]

    readonly property var centred: ["clipboard"]

    function register(name, item) { slots[name] = (slots[name] ?? []).concat([item]) }
    function unregister(name, item) { if (slots[name]) slots[name] = slots[name].filter(i => i !== item) }
    function screenOf(item) { return item?.QsWindow.window?.screen ?? null }

    // `item`: the slot it hangs from (a click); none: the panel's slot on the focused monitor (a key, IPC).
    function open(name, item) {
        const scr = screenOf(item) ?? focusedScreen;
        const from = item ?? (slots[name] ?? []).find(i => screenOf(i) === scr) ?? null;
        if (from && !centred.includes(name)) {
            const p = from.mapToItem(null, 0, 0);
            anchorLeft = p.x + (from.hangLeft ?? 0);
            anchorRight = p.x + from.width;
            anchorX = p.x + (from.anchorX ?? from.width / 2);
        } else {
            anchorX = anchorLeft = anchorRight = -1;
        }
        screen = scr;
        current = name;
    }
    // A tray item's own menu, hung from the bar rule under its cell (the drawer's right click).
    function openTrayMenu(item, cell) { trayItem = item; open("traymenu", cell) }
    function close() { current = "" }
    // Open on another screen than the one it is on: it moves there.
    function toggle(name, item) {
        if (current === name && screen === (screenOf(item) ?? focusedScreen)) close();
        else open(name, item);
    }

    // A screen unplugged with the popup on it: closed, and the next one opens on the focused monitor.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!Quickshell.screens.includes(root.screen)) { root.close(); root.screen = root.focusedScreen; }
        }
    }
}
