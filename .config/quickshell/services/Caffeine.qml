pragma Singleton
import QtQuick
import Quickshell
import qs

// Keep awake: while on, the bar holds a Wayland idle inhibitor (bar/Bar.qml), so hypridle neither locks the
// screen nor switches it off. One state for the bar's tick, Super+Alt+C and the dashboard's caffeine switch.
// Switched on, it holds for Prefs.caffeineHold ("30m" "1h" "2h", or "off": until switched off) and then lets go by
// itself (`until`). It survives a shell reload but deliberately not a new login: a desktop that will not lock should
// never be the state you come back to.
Singleton {
    id: root
    readonly property bool on: state.on
    readonly property real until: state.until          // ms since the epoch, 0 = until switched off

    function toggle() { setOn(!state.on) }
    function setOn(v) {
        const min = Theme.control.holdMinutes[Prefs.caffeineHold] ?? 0;
        state.until = v && min > 0 ? Date.now() + min * 60000 : 0;
        state.on = v;
    }
    // A new hold while on starts counting from now.
    function setHold(h) { Prefs.set("caffeineHold", h); if (state.on) setOn(true) }

    PersistentProperties {
        id: state
        reloadableId: "caffeine"
        property bool on: false
        property real until: 0
    }
    // The hold's end, checked every few seconds (a timer set for hours would drift across a suspend).
    Timer {
        running: state.on && state.until > 0
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= state.until) root.setOn(false)
    }
}
