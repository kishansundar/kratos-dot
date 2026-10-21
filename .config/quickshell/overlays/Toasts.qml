import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Notification toasts (Toast): top right, directly under the bar, 384 wide, newest first, at most three, 8 px apart.
// Each leaves after 5 s (or the time the app asked for); critical ones stay until dismissed. Hidden while a popup is
// open; they come back when it closes. Hidden too while the focused window is fullscreen (Notifs.fullscreen: a game),
// unless a critical one is among them; their timers run on meanwhile.
// Keyed by notification (ScriptModel): a toast arriving or leaving keeps the others, and their timers run on from their
// own arrival.
PanelWindow {
    screen: Panels.focusedScreen          // the focused monitor (else the first)
    visible: Notifs.popups.length > 0 && Panels.current === ""
             && (!Notifs.fullscreen || Notifs.popups.some(n => Notifs.isCritical(n)))
    anchors { top: true; right: true }
    margins { top: Theme.space.s2; right: Theme.bar.padX }
    exclusionMode: ExclusionMode.Normal
    implicitWidth: Theme.size.popupWidth
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "swiss-toasts"

    Column {
        id: column
        width: parent.width
        spacing: Theme.space.s2

        Repeater {
            model: ScriptModel { values: Notifs.popups.slice(0, 3) }
            NotificationCard {
                required property var modelData
                notification: modelData
                Timer {
                    running: !Notifs.isCritical(parent.notification) && !parent.hovered
                    interval: parent.notification.expireTimeout > 0 ? parent.notification.expireTimeout : Theme.motion.toast
                    onTriggered: Notifs.unpop(parent.notification)
                }
            }
        }
    }
}
