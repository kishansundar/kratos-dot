import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// The dashboard's switch and its sampling. The dashboard itself is a popover (panels/DashboardPanel.qml, PanelHost's
// "dashboard": Super+D, a right click on the NixOS mark); this adds `qs ipc call dash toggle` and keeps every source it
// reads sampling only while it is open (Metrics, Processes, Tailscale). Another view may watch the same service,
// so each binding lets go when it closes. The charts keep their ten minutes while the shell runs.
Scope {
    id: root
    readonly property bool open: Panels.current === "dashboard"
    onOpenChanged: if (!open) Tip.hide()

    IpcHandler {
        target: "dash"
        function toggle(): void { Panels.toggle("dashboard") }
    }

    Binding { target: Metrics; property: "watching"; value: true; when: root.open; restoreMode: Binding.RestoreBindingOrValue }
    Binding { target: Processes; property: "watching"; value: true; when: root.open; restoreMode: Binding.RestoreBindingOrValue }
    Binding { target: Tailscale; property: "watching"; value: true; when: root.open; restoreMode: Binding.RestoreBindingOrValue }
}
