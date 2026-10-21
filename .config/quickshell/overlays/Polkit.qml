import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs
import qs.components
import qs.services

// The password prompt for admin actions: this shell is the session's polkit agent, so any app that needs an
// administrator's say-so (a system setting, 1Password, a service) asks here. The question (components/AuthPrompt) sits
// on a panel card in the middle of the focused monitor (mango's "active" one), like the dashboard, over a dimmed
// screen. A request closes any open popup first (both would want the keyboard). Esc or cancel refuses it; a click
// outside does nothing (a modal question is not dismissed by a stray click). Opens like every popup: opacity and an
// 8 px slide, motion.med. Without this agent such requests fail silently.
PanelWindow {
    id: dialog

    property bool shown: false
    property real slide: 0

    visible: shown
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.tint(Theme.colors.bg, 0.5)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "swiss-polkit"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PolkitAgent {
        id: agent
        onIsRegisteredChanged: console.info("Polkit agent registered:", isRegistered)
    }

    Connections {
        target: agent
        function onIsActiveChanged() {
            if (!agent.isActive) { dialog.shown = false; return; }
            Panels.close();
            dialog.screen = Quickshell.screens.find(s => Mango.monitor(s.name)?.active) ?? Quickshell.screens[0];
            dialog.shown = true;
            openAnim.restart();
            prompt.focusInput();
        }
    }

    // The dimmed screen takes every click, so nothing below is reached and nothing is dismissed.
    MouseArea { anchors.fill: parent }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: prompt.cancel()

        Card {
            id: card
            anchors { centerIn: parent; verticalCenterOffset: dialog.slide }
            opacity: 0
            AuthPrompt { id: prompt; flow: agent.flow }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.motion.med; easing.type: Easing.OutCubic }
        NumberAnimation { target: dialog; property: "slide"; from: -Theme.motion.slide; to: 0; duration: Theme.motion.med; easing.type: Easing.OutCubic }
    }
}
