import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

// The tray as a drawer in the bar (design/swiss/components/Tray), not a panel; its row is design/tray-row's:
//   [drawer ←] chevron · pinned apps · (then, in Status) keep-awake · Claude
//   closed   the chevron (Swiss Glyph chevron-left, 16 px in ink like its neighbours), then the pinned items
//   open     a click on the chevron (or Super+Ctrl+T) slides the other items out to its left, inside the bar (180 ms),
//            their extent marked by a 3 px ink line on the bar rule; the chevron turns (› "hide tray"). It stays open
//            until the chevron or Esc closes it: it never closes by itself and never covers anything. Pinned items,
//            Claude and keep-awake sit right of the chevron and never move.
//   attention   an item that needs attention carries an ink triangle; on a hidden one it goes on the chevron, whose
//            tooltip names the app
// Items: 32 px cells with a 16 px icon, in the order they registered: an app in the Swiss app icons (design/app-icons,
// the owner's set of 16 October 2026) as its pictogram in ink, any other as the picture it sends, in its own colours
// (in ink when it is one colour made for one kind of panel: AppIcons.trayInk); passive items hidden unless pinned.
// Left click: the app's main action; middle: its secondary action; right: its own menu, dropped from the bar rule and styled as a popup, with "Pin to bar" / "Unpin" at its foot; the
// wheel goes to the app. The apps keep running either way.
// Both rows are keyed by item (ScriptModel): an item registering, leaving or changing its status keeps the other cells
// (and a tooltip or menu anchored to one).
Row {
    id: drawer

    readonly property var all: SystemTray.items.values
    readonly property var pinned: all.filter(i => Prefs.pinned.includes(i.id))
    readonly property var hidden: all.filter(i => !Prefs.pinned.includes(i.id) && i.status !== Status.Passive)
    readonly property var attention: hidden.filter(i => i.status === Status.NeedsAttention)
    readonly property bool open: Panels.trayOpen

    visible: all.length > 0
    height: Theme.bar.height

    // One tray item.
    component Cell: Item {
        id: cell
        required property var modelData
        width: Theme.size.hitTarget
        height: Theme.bar.height

        HoverFill { anchors.bottomMargin: Theme.size.rule; pressed: mouse.pressed; hovered: mouse.containsMouse || (Panels.current === "traymenu" && Panels.trayItem === cell.modelData) }
        // The app's Swiss drawing in ink (design/app-icons, its 16 px drawing) when the set has one, found by the
        // item's icon name or, for items that send pixels, by its id or title (AppIcons.trayName); otherwise the
        // picture the app sends, in its own colours, or in ink when it is one colour made for one kind of panel
        // (AppIcons.trayInk), painted through its alpha as AppIcon paints a drawing.
        readonly property bool inked: !drawing.available && AppIcons.trayInked(cell.modelData)
        IconImage {
            id: cellIcon
            x: Math.round((cell.width - width) / 2)
            y: Theme.bar.iconTop
            implicitSize: Theme.size.appIcon
            source: drawing.available ? "" : cell.modelData.icon
            visible: !drawing.available && !cell.inked
            layer.enabled: cell.inked
        }
        Rectangle {
            anchors.fill: cellIcon
            visible: cell.inked
            color: Theme.colors.text
            layer.enabled: cell.inked
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cellIcon
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }
        AppIcon {
            id: drawing
            anchors.fill: cellIcon
            name: AppIcons.trayName(cell.modelData)
        }
        Mark {
            visible: cell.modelData.status === Status.NeedsAttention
            kind: "triangle"
            x: cellIcon.x + cellIcon.width - width / 2
            y: Theme.bar.iconTop - 2
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: event => {
                const i = cell.modelData;
                if (event.button === Qt.MiddleButton) i.secondaryActivate();
                else if (event.button === Qt.RightButton || (i.onlyMenu && i.hasMenu)) Panels.openTrayMenu(i, cell);
                else i.activate();
            }
            onWheel: event => cell.modelData.scroll(event.angleDelta.y, false)
            // A press takes the tip away until the pointer leaves (as BarSlot's).
            property bool tipQuiet: false
            onPressed: { tipQuiet = true; updateTip(); }
            onContainsMouseChanged: { if (!containsMouse) tipQuiet = false; updateTip(); }
            function updateTip() {
                const w = QsWindow.window;          // the bar's window (its one tooltip), as BarSlot and Folio find it
                if (!w || !w.showTip) return;
                const i = cell.modelData;
                if (containsMouse && !tipQuiet) w.showTip(cell, (i.tooltipTitle || i.title || i.id) + (Prefs.pinned.includes(i.id) ? " · pinned" : "") + " · right click: menu", Theme.trayRow.tipDelay);
                else w.hideTip(cell);
            }
        }
    }

    // ---- The drawer: the hidden items, sliding out to the left of the pinned ones --------------------------
    Item {
        id: slide
        width: drawer.open ? items.width : 0
        height: Theme.bar.height
        clip: true
        Behavior on width { NumberAnimation { duration: Theme.motion.drawer; easing.type: Easing.OutCubic } }
        Row {
            id: items
            anchors.right: parent.right
            Repeater {
                model: ScriptModel { values: drawer.hidden }
                Cell {}
            }
        }
        // How far the drawer reaches: a 3 px ink line on the bar rule.
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.size.progressW
            color: Theme.colors.text
        }
    }

    // ---- The chevron -----------------------------------------------------------------------------------------
    BarSlot {
        id: chevron
        fixedWidth: Theme.size.hitTarget
        tipDelay: Theme.trayRow.tipDelay
        tooltip: drawer.open ? "Hide tray · Super+Ctrl+T"
            : drawer.attention.length > 0 ? drawer.attention.map(i => i.tooltipTitle || i.title || i.id).join(", ") + " needs attention · Super+Ctrl+T"
            : "Show tray · " + drawer.hidden.length + (drawer.hidden.length === 1 ? " app" : " apps") + " · Super+Ctrl+T"
        onClicked: button => { if (button === Qt.LeftButton) Panels.trayOpen = !Panels.trayOpen }
        Icon {
            id: chevronGlyph
            x: Math.round((chevron.width - width) / 2)
            y: Theme.bar.iconTop
            name: drawer.open ? Theme.icons.drawerOpen : Theme.icons.drawerClosed
            color: drawer.hidden.length > 0 || drawer.open ? Theme.colors.text : Theme.colors.textMuted
        }
        // A hidden item needs attention: the ink triangle on the chevron.
        Mark {
            visible: !drawer.open && drawer.attention.length > 0
            kind: "triangle"
            x: chevronGlyph.x + chevronGlyph.width - width / 2
            y: Theme.bar.iconTop - 2
        }
    }

    // ---- Pinned items: right of the chevron, so the drawer never moves them ------------------------------------
    Repeater {
        model: ScriptModel { values: drawer.pinned }
        Cell {}
    }
}
