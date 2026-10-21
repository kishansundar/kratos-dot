import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// A tray item's own menu (the drawer's right click), hung from the bar rule under the item and styled as a popup
// (design/swiss/components/Tray): its entries as rows (a circle for a check or radio entry: filled when on, a ring when off),
// separators as hairlines, a chevron where an entry opens a submenu (entered in place, with a way back at the top);
// disabled entries faint. At the foot, the shell's own line: "Pin to the bar" / "Unpin from the bar".
// Keys: Up/Down choose, Enter runs (or enters a submenu), Left goes back, Esc closes.
Column {
    id: trayMenu
    readonly property int cardPadding: Theme.space.s2
    readonly property var item: Panels.trayItem
    property var stack: []                  // submenus entered, deepest last
    property int current: -1

    width: 240
    focus: true

    // One reader per level: the root menu stays held while a submenu is read (releasing it drops its entries).
    QsMenuOpener { id: opener; menu: trayMenu.item ? trayMenu.item.menu : null }
    Instantiator {
        id: levels
        model: trayMenu.stack
        delegate: QsMenuOpener { required property var modelData; menu: modelData }
    }
    readonly property var entries: {
        const model = stack.length > 0 && levels.count === stack.length ? levels.objectAt(stack.length - 1).children : opener.children;
        return model ? model.values : [];
    }
    readonly property var actionable: entries.filter(e => !e.isSeparator && e.enabled)

    function run(e) {
        if (e.hasChildren) { stack = stack.concat([e]); current = -1; return; }
        e.triggered();
        Panels.close();
    }
    Keys.onPressed: event => {
        const n = actionable.length;
        if (event.key === Qt.Key_Down && n > 0) current = (current + 1) % n;
        else if (event.key === Qt.Key_Up && n > 0) current = (current + n - 1) % n;
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && current >= 0 && current < n) run(actionable[current]);
        else if (event.key === Qt.Key_Left && stack.length > 0) { stack = stack.slice(0, -1); current = -1; }
        else return;
        event.accepted = true;
    }

    // Inside a submenu: the way back.
    RowItem {
        visible: trayMenu.stack.length > 0
        onActivated: { trayMenu.stack = trayMenu.stack.slice(0, -1); trayMenu.current = -1; }
        Icon { id: back; anchors.verticalCenter: parent.verticalCenter; name: Theme.icons.chevronLeft; color: Theme.colors.textMuted }
        Txt {
            anchors { left: back.right; leftMargin: Theme.space.s2; right: parent.right; verticalCenter: parent.verticalCenter }
            text: trayMenu.stack.length > 0 ? trayMenu.stack[trayMenu.stack.length - 1].text.replace(/_(?=\S)/, "") : ""
            color: Theme.colors.textMuted
        }
    }
    MenuRule { visible: trayMenu.stack.length > 0; gap: Theme.space.s1; height: Theme.space.s2 }

    Repeater {
        model: trayMenu.entries
        delegate: Item {
            id: entryItem
            required property var modelData
            width: trayMenu.width
            height: modelData.isSeparator ? separator.height : Theme.size.hitTarget

            MenuRule { id: separator; visible: entryItem.modelData.isSeparator; gap: Theme.space.s1 }
            RowItem {
                visible: !entryItem.modelData.isSeparator
                enabled: entryItem.modelData.enabled
                selected: trayMenu.actionable.indexOf(entryItem.modelData) === trayMenu.current
                radio: entryItem.modelData.buttonType !== QsMenuButtonType.None
                checked: entryItem.modelData.checkState === Qt.Checked
                onHoveredIn: trayMenu.current = trayMenu.actionable.indexOf(entryItem.modelData)
                onActivated: trayMenu.run(entryItem.modelData)
                Txt {
                    anchors { left: parent.left; right: sub.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                    text: entryItem.modelData.text.replace(/_(?=\S)/, "")      // the mnemonic marker
                    color: entryItem.modelData.enabled ? Theme.colors.text : Theme.states.disabled
                }
                Icon {
                    id: sub
                    visible: entryItem.modelData.hasChildren
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    name: Theme.icons.chevronRight
                    color: Theme.colors.textMuted
                }
            }
        }
    }

    // The shell's own line at the foot: pin the item to the bar, or unpin it.
    MenuRule { visible: trayMenu.entries.length > 0; gap: Theme.space.s1; height: Theme.space.s2 }
    RowItem {
        onActivated: { if (trayMenu.item) Prefs.togglePin(trayMenu.item.id); Panels.close(); }
        Txt {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            text: trayMenu.item && Prefs.pinned.includes(trayMenu.item.id) ? "Unpin from the bar" : "Pin to the bar"
        }
    }
}
