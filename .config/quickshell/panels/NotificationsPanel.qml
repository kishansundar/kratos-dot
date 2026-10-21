import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// The notification centre (design/panels NotificationsPanel; the bell, or Ctrl+Alt+\), notifWidth wide:
//   Notifications ········· ● dnd  clear all     h2 and its ruler; do not disturb as a circle and a word; clear all,
//                                                which becomes "undo" for Theme.panel.undo after it is used
//   ⍉ Do not disturb · until 15:00     2 held     only while it is on: when it ends, and how many it kept back
//   SYSTEMD                                  1     one group per app, newest first (a group with a critical item
//   ─────────────────────────────────────────     first): the app as an eyebrow, its count in mono
//   ▌! Backup failed                  14:02  ×     the items (components/NotifItem), critical first, at most
//   ...                                            notifGroupMax, then "+N more" (a click shows the rest)
//   No notifications.                              empty: that sentence only
// The history survives a restart (services/Notifs records). Opening marks everything read (the bell loses its square).
// Keys: D do not disturb, Delete clear all, Ctrl+Z undo, Esc close.
Column {
    id: panel
    width: Theme.panel.notifWidth - 2 * Theme.space.s5
    focus: true

    Component.onCompleted: Notifs.markRead()

    property var opened: []                 // apps whose group shows every item
    readonly property var groups: {
        const by = {};
        for (const r of Notifs.shown) {
            const app = r.app || "Notification";
            (by[app] = by[app] ?? []).push(r);
        }
        const out = Object.keys(by).map(app => {
            const items = by[app].slice().sort((a, b) => (b.urgency === 2) - (a.urgency === 2) || b.time - a.time);
            return { app: app, items: items, critical: items.some(r => r.urgency === 2), newest: Math.max(...items.map(r => r.time)) };
        });
        return out.sort((a, b) => (b.critical - a.critical) || b.newest - a.newest);
    }
    // The groups are computed afresh on every change, so the lists are keyed (ScriptModel): the groups by app, looked up
    // here, and the items by record. A notification arriving or leaving keeps every other group and item, and what they
    // show (an item opened to its full text).
    readonly property var apps: groups.map(g => g.app)
    readonly property var byApp: { const m = {}; for (const g of groups) m[g.app] = g; return m }
    readonly property bool clearing: Notifs.pendingClear.length > 0

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete && Notifs.shown.length > 0) Notifs.clearLater();
        else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier) && panel.clearing) Notifs.undoClear();
        else if (event.key === Qt.Key_D) Notifs.setDnd(!Prefs.dnd);
        else return;
        event.accepted = true;
    }

    Heading {
        title: "Notifications"
        Switch {
            word: "dnd"
            checked: Prefs.dnd
            onToggled: Notifs.setDnd(!Prefs.dnd)
        }
        TextButton {
            visible: panel.clearing || Notifs.shown.length > 0
            text: panel.clearing ? "undo" : "clear all"
            onClicked: panel.clearing ? Notifs.undoClear() : Notifs.clearLater()
        }
    }

    Item { width: 1; height: Theme.space.s5 }

    // Do not disturb: when it ends, and how many it kept back.
    Item {
        visible: Prefs.dnd
        width: parent.width
        height: Theme.size.hitTarget
        Icon {
            id: bellOff
            anchors.verticalCenter: parent.verticalCenter
            name: Theme.icons.bellOff
        }
        Txt {
            anchors { left: bellOff.right; leftMargin: Theme.space.s2; right: heldText.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            text: "Do not disturb" + (Prefs.dndUntil > 0 ? " · until " + Qt.formatTime(new Date(Prefs.dndUntil), "HH:mm") : "")
        }
        Annot {
            id: heldText
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: Notifs.held + " held"
        }
    }

    Item { visible: Prefs.dnd; width: 1; height: Theme.space.s4 }

    Txt {
        visible: panel.groups.length === 0
        height: Theme.size.hitTarget
        text: "No notifications."
        color: Theme.colors.textMuted
    }

    Flickable {
        id: scroller
        visible: panel.groups.length > 0
        width: parent.width
        height: Math.min(contentHeight, Theme.panel.notifListMax)
        contentHeight: groupColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: groupColumn
            width: scroller.width
            spacing: Theme.panel.sectionGap

            Repeater {
                model: ScriptModel { values: panel.apps }
                Column {
                    id: group
                    required property var modelData        // the app
                    readonly property var g: panel.byApp[modelData] ?? { app: modelData, items: [] }
                    readonly property bool open: panel.opened.includes(modelData)
                    readonly property int more: g.items.length - Theme.panel.notifGroupMax
                    width: groupColumn.width

                    // The app as an eyebrow over the short ruler, its count in mono: every popover's section head.
                    SectionHead { title: group.modelData; annotation: String(group.g.items.length) }
                    Repeater {
                        model: ScriptModel { values: group.open ? group.g.items : group.g.items.slice(0, Theme.panel.notifGroupMax) }
                        NotifItem {
                            required property var modelData
                            record: modelData
                        }
                    }
                    TextButton {
                        visible: group.more > 0 && !group.open
                        x: Theme.space.s3
                        text: "+" + group.more + " more"
                        onClicked: panel.opened = panel.opened.concat([group.modelData])
                    }
                }
            }
        }
    }
}
