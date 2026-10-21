import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The dock (design/dock, from the owner's nixos-mark-and-dock package, 15 October 2026). Hidden every time, on an empty
// tag too (the owner's ask, 19 October 2026, over the package's "shows while the tag is empty"): only the bottom edge
// brings it up.
//   pinned apps | running apps that aren't pinned | the trash      split by 1 px rules
// The package's first cell, the NixOS mark opening the launcher, is left out: the owner found it redundant beside the
// bar's mark, which opens the launcher already, as Super+Space does (15 October 2026).
// Centred, standing the window gap (Theme.bar.padX, 8 px) above the bottom edge, so its bottom edge lines up with the
// windows', with a 1 px line all round; on the bar's ground (bg at the bar's 85 %, not blurred: rule.conf). Icons centred in
// the 80 px cell, 16 px above and below, the running mark 4 px under the icon. All the owner's picks, 15 October 2026,
// over the package's flush, solid dock with its 12 / 20 px cell (option C of three rendered). Each app on a 48 px tile
// in the hover grey (the owner's pick of three rendered, 16 October 2026: the tiles line up drawings of different
// shapes), its icon 36 px inside: an app in the Swiss app icons (design/app-icons, the owner's set of 16 October 2026,
// over design/dock's "own icons, full colour, never tinted") is its pictogram in ink; any other app keeps its own icon
// in full colour. Under the tile: a 16 x 2 px ink bar = running, the ink triangle = needs attention, nothing = not
// running. Hover: the tile takes the line colour, and after 150 ms the app's name and its tags rise above the dock in
// a label box.
// When: the bottom edge (the owner's choice, 15 October 2026, over the package's "no hover-to-reveal"): pushing the
// pointer against the screen's bottom edge under the dock for hoverDelay (150 ms) brings it up, sliding cellH and
// fading in over 180 ms, over any windows; it goes again hoverDelay after the pointer leaves it, at once after a click
// on an app, when its menu closes with the pointer elsewhere, and when a window maps on an empty tag. Only the bottom
// edge under the dock wakes it, so it always comes up under the pointer. The window list (Mango.clients) is read only
// while a dock is shown or about to be.
// Click: not running -> launch; running -> its newest window (mango switches to its tag, so the dock hides); windows
// on several tags -> the menu. Middle click: a new window. Right click: the menu (the app's windows, its desktop
// actions, pin / unpin, quit). Drag a pinned app sideways to reorder it, or up off the dock to unpin it. Keyboard,
// after `qs ipc call dock focus`: left / right, Enter, Esc.
// The trash (the owner's ask, 15 October 2026, "like the macOS dock"; not in design/dock): last, after its own rule, the
// Swiss app icons' bin in ink on its tile, like the apps beside it (the owner's choice, 16 October 2026 ~13:30, over the
// icon theme's own full-colour bin chosen at 12:08; that bin is still the fallback where the set has no drawing):
// user-trash (outline) while empty, user-trash-full (solid) with something in it. Click: open it in Files; right click: the menu, whose Empty Trash asks once ("erase N items for
// good?") before it deletes anything. Files dropped on it go into it. Over windows, a drag held against the bottom edge
// brings the dock up as the pointer does, and the dock stays while the drag is on it.
// Three layers per output, all on the top layer with no exclusive zone (the dock never moves a window): the dock itself
// ("swiss-dock-body", as big as the dock; no blur, rule.conf); a full-screen transparent one for
// the name label and the menu ("swiss-dock", unblurred: rule.conf), taking input only while the menu is open, then
// everywhere but the dock, so a click outside closes the menu; and the bottom-edge strip ("swiss-dock" too).
PanelWindow {
    id: dock
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "swiss-dock"
    // The keyboard only while it is asked for (qs ipc call dock focus) or the menu is open (Esc closes it); mango
    // grants on-demand focus only from a click, which comes too late here, so both take it exclusively.
    WlrLayershell.keyboardFocus: keys || menuKey !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: menuKey !== "" ? everywhere : underDock
    Region { id: underDock; item: gap }
    Region {
        id: everywhere
        item: catcher
        Region { item: rest; intersection: Intersection.Subtract }
    }

    // ---- When -------------------------------------------------------------------------------------------------
    readonly property var mon: Mango.monitor(screen ? screen.name : "")
    readonly property bool empty: {
        if (!mon || !mon.tags) return false;
        const viewed = mon.tags.filter(t => t.is_active);
        return viewed.length > 0 && viewed.every(t => t.client_count === 0);
    }
    property bool shown: false
    property bool peek: false              // shown from the bottom edge (it goes when the pointer leaves)
    property real enter: 0                 // 0 -> 1 as it slides up and fades in
    // A window mapping on an empty tag (an app the dock launched) puts it away at once.
    onEmptyChanged: if (!empty) hide()
    // The slide stops too: left running, it would carry `enter` back towards 1 under a hidden dock.
    function hide() { slideIn.stop(); shown = false; peek = false; enter = 0; menuKey = ""; keys = false; hovering = false; tipShown = false; }
    // From the bottom edge: up over anything; gone once the pointer is off it and nothing of it is in use.
    function reveal() {
        if (shown) return;
        peek = true;
        shown = true;
        slideIn.restart();
    }
    property bool dragging: false          // a pinned cell is being dragged (the pointer may be off the dock)
    // The pointer is on the dock or still on the edge strip under it. mango hands a surface that maps under a still
    // pointer nothing until the pointer moves, so right after coming up the pointer is still the strip's: leaving
    // that counts too, and a jump straight off the dock is seen.
    readonly property bool pointerOn: bodyHover.hovered || edgeArea.containsMouse || gapHover.hovered || dragOn
    // A drag (files from Files) is not the pointer to Wayland: no hover reaches the dock while one passes over it, so
    // the drop areas say where it is. The trash's own takes the drag from the dock's while over it.
    readonly property bool dragOn: edgeDrop.containsDrag || gapDrop.containsDrag || bodyDrop.containsDrag || trashDrag
    property bool trashDrag: false
    // hoverDelay's grace: crossing from the strip onto the dock is a leave and an enter, in either order.
    function settle() {
        if (peek && menuKey === "" && !keys && !dragging && !pointerOn) leaveTimer.restart();
        else leaveTimer.stop();
    }
    onPointerOnChanged: settle()
    onMenuKeyChanged: { confirmEmpty = false; settle(); }
    onKeysChanged: settle()
    onDraggingChanged: settle()
    Timer {
        id: leaveTimer
        interval: Theme.dock.hoverDelay
        onTriggered: if (dock.peek && dock.menuKey === "" && !dock.keys && !dock.dragging && !dock.pointerOn) dock.hide()
    }
    Timer {
        id: peekTimer
        interval: Theme.dock.hoverDelay
        onTriggered: if (edgeArea.containsMouse || edgeDrop.containsDrag) dock.reveal()
    }
    NumberAnimation { id: slideIn; target: dock; property: "enter"; from: 0; to: 1; duration: Theme.dock.slide; easing.type: Easing.OutCubic }
    // While shown, any change in mango's state may be a window opening or closing on another tag: read the list again.
    Connections {
        target: Mango
        function onMonitorsChanged() { if (dock.shown) Mango.refreshClients() }
    }
    // The bottom edge under the dock: a 1 px strip as wide as the dock, always mapped (the dock, mapped after it, stacks
    // above it). The same namespace, so mango's no_blur rule (rule.conf) covers it. A fullscreen window lies above the
    // top layer, so the edge never brings the dock over one.
    PanelWindow {
        screen: dock.screen
        anchors { bottom: true }
        implicitWidth: dock.dockWidth
        implicitHeight: Theme.size.rule
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "swiss-dock"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea {
            id: edgeArea
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: {
                if (containsMouse) { Mango.refreshClients(); peekTimer.restart(); }
                else peekTimer.stop();
            }
        }
        // A drag of files held here brings it up too, for the trash; nothing is dropped on the strip itself.
        HoldDrop {
            id: edgeDrop
            onContainsDragChanged: {
                if (containsDrag) { Mango.refreshClients(); peekTimer.restart(); }
                else if (!edgeArea.containsMouse) peekTimer.stop();
            }
        }
    }

    // ---- What -------------------------------------------------------------------------------------------------
    // Running apps by key (the desktop id when mango's app id finds an entry, else the app id itself):
    // { entry, appid, windows: [mango client, newest first] }.
    readonly property var running: {
        DesktopEntries.applications.values;   // read again once the entries have loaded
        const m = {};
        for (const c of Mango.clients) {
            const e = DesktopEntries.heuristicLookup(c.appid);
            const k = e ? e.id : c.appid;
            if (!m[k]) m[k] = { entry: e, appid: c.appid, windows: [] };
            m[k].windows.push(c);
        }
        return m;
    }
    readonly property var pinnedKeys: { DesktopEntries.applications.values; return Prefs.dockPinned.filter(id => DesktopEntries.byId(id) !== null) }
    readonly property var runningKeys: Theme.dock.showRunning ? Object.keys(running).filter(k => !Prefs.dockPinned.includes(k)) : []
    // Every cell in order, for the keyboard; ":trash" is the trash (no desktop id starts with a colon).
    readonly property var allKeys: pinnedKeys.concat(runningKeys, [":trash"])
    function info(key) {
        const r = running[key];
        return { entry: r ? r.entry : DesktopEntries.byId(key), appid: r ? r.appid : key, windows: r ? r.windows : [] };
    }
    function nameOf(key) {
        if (key === ":trash") return "Trash";
        const i = info(key);
        return i.entry ? i.entry.name : i.appid;
    }
    function tagsOf(windows) {            // the tags these windows are on, sorted (no Array.flatMap in Qt's engine)
        const s = [];
        for (const w of windows) for (const t of w.tags) if (!s.includes(t)) s.push(t);
        return s.sort((a, b) => a - b);
    }
    function detailOf(key) {
        if (key === ":trash") return Trash.count === 0 ? "empty" : Trash.count + (Trash.count === 1 ? " item" : " items");
        const w = info(key).windows;
        if (w.length === 0) return "not running";
        const t = tagsOf(w);
        return (t.length === 1 ? "tag " : "tags ") + t.join(", ") + " · " + w.length + (w.length === 1 ? " window" : " windows");
    }

    // ---- Acting -----------------------------------------------------------------------------------------------
    function launch(entry) {
        if (!entry) return;
        Busy.start(entry);                // "starting" in the bar's title until its window opens
    }
    function activate(key, cellX) {
        if (key === ":trash") { Trash.open(); return; }
        const i = info(key);
        if (i.windows.length === 0) launch(i.entry);
        else if (tagsOf(i.windows).length > 1) openMenu(key, cellX);
        else Mango.focusClient(i.windows[0].id);
    }
    function quit(key) { for (const w of info(key).windows) Mango.closeClient(w.id); }

    // ---- The trash: services/Trash (its folder, bins, open / empty / put) --------------------------------------
    property bool confirmEmpty: false      // the menu asks once before the trash is emptied for good

    // ---- The dock ---------------------------------------------------------------------------------------------
    // Fills the screen under the dock: catches the click outside an open menu (the mask makes it live only then).
    MouseArea {
        id: catcher
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: dock.menuKey = ""
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (dock.menuKey !== "") dock.menuKey = ""; else dock.keys = false;
            } else if (dock.keys && event.key === Qt.Key_Left) {
                dock.focusIndex = Math.max(0, dock.focusIndex - 1);
            } else if (dock.keys && event.key === Qt.Key_Right) {
                dock.focusIndex = Math.min(dock.allKeys.length - 1, dock.focusIndex + 1);
            } else if (dock.keys && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                const k = dock.allKeys[dock.focusIndex];
                dock.keys = false;
                if (k !== undefined) dock.activate(k, dock.cellXOf(dock.focusIndex));
            } else return;
            event.accepted = true;
        }
    }
    property bool keys: false              // keyboard mode (qs ipc call dock focus)
    property int focusIndex: 0
    Connections {
        target: Panels
        function onDockFocusRequested() {
            if (dock.screen !== Panels.focusedScreen) return;
            Mango.refreshClients();
            dock.reveal();
            dock.focusIndex = 0;
            dock.keys = true;
        }
    }
    // The dock's width, counted rather than read from its row: a Row lays out only while its window is shown, so the
    // edge strip (mapped all the time) stayed one cell wide after a restart over windows, until the dock first came up.
    readonly property int dockWidth: {
        const pins = pinnedKeys.length, runs = runningKeys.length;
        return 2 * Theme.dock.padX + (Math.min(pins, Theme.dock.maxPinned) + runs + 1) * Theme.dock.cellW
            + (pins > 0 && runs > 0 ? Theme.dock.groupGap : 0) + (pins + runs > 0 ? Theme.dock.groupGap : 0);
    }
    // A cell's left edge in the window, by its index in allKeys (the groups' separators counted).
    function cellXOf(i) {
        const pins = pinnedKeys.length, runs = runningKeys.length;
        let x = rest.x + Theme.dock.padX + i * Theme.dock.cellW;
        if (i >= pins && pins > 0 && runs > 0) x += Theme.dock.groupGap;            // the rule after the pinned
        if (i === allKeys.length - 1 && pins + runs > 0) x += Theme.dock.groupGap;  // the rule before the trash
        return x - (i < pins ? pinned.contentX : 0);
    }

    // Where the dock rests once up, in this window: the label and the menu stand on its top edge.
    Item {
        id: rest
        x: Math.round((dock.width - width) / 2)
        y: dock.height - Theme.bar.padX - height
        width: body.width
        height: Theme.dock.cellH
    }
    // The window gap under the dock: still the dock's to the pointer (this window's input there), so the way up from
    // the edge strip to the dock, or a rest in between, does not put it away.
    Item {
        id: gap
        x: rest.x
        y: rest.y + rest.height
        width: rest.width
        height: dock.height - y
        HoverHandler { id: gapHover }
        HoldDrop { id: gapDrop }
    }

    // The dock's own layer, centred, the window gap above the bottom edge. It slides up by growing from there with the
    // dock pinned to its top (mango does not move a mapped layer when only its margin changes).
    PanelWindow {
        screen: dock.screen
        anchors { bottom: true }
        margins.bottom: Theme.bar.padX
        implicitWidth: dock.dockWidth
        implicitHeight: Math.max(1, Math.round(dock.enter * Theme.dock.cellH))
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: dock.shown
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "swiss-dock-body"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            id: body
            width: dock.dockWidth
            height: Theme.dock.cellH
            opacity: dock.enter
            HoverHandler { id: bodyHover }
            // A drag of files over the dock holds it up; only the trash takes the drop.
            HoldDrop { id: bodyDrop }

            Rectangle { anchors.fill: parent; color: Theme.tint(Theme.colors.bg, Theme.bar.opacity) }
            // A 1 px line all round.
            Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
            Rectangle { y: parent.height - height; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
            Rectangle { width: Theme.size.rule; height: parent.height; color: Theme.colors.line }
            Rectangle { x: parent.width - width; width: Theme.size.rule; height: parent.height; color: Theme.colors.line }

            Row {
                id: row
                x: Theme.dock.padX
                // Pinned apps; past maxPinned the group scrolls sideways (the wheel scrolls it).
                Flickable {
                    id: pinned
                    width: Math.min(dock.pinnedKeys.length, Theme.dock.maxPinned) * Theme.dock.cellW
                    height: Theme.dock.cellH
                    contentWidth: dock.pinnedKeys.length * Theme.dock.cellW
                    interactive: contentWidth > width
                    clip: contentWidth > width
                    flickableDirection: Flickable.HorizontalFlick
                    Row {
                        Repeater {
                            model: ScriptModel { values: dock.pinnedKeys }
                            Cell { required property string modelData; required property int index; key: modelData; pinIndex: index; cellIndex: index }
                        }
                    }
                }
                Separator { visible: dock.pinnedKeys.length > 0 && dock.runningKeys.length > 0 }
                Repeater {
                    model: ScriptModel { values: dock.runningKeys }
                    Cell { required property string modelData; required property int index; key: modelData; cellIndex: dock.pinnedKeys.length + index }
                }
                Separator { visible: dock.pinnedKeys.length + dock.runningKeys.length > 0 }
                TrashCell { cellIndex: dock.allKeys.length - 1 }
            }
        }
    }

    // Where a drag of files keeps the dock up but cannot be dropped: taken on entering, so containsDrag says it is here
    // (a refused enter never sets it), and refused at every move, so the file manager shows "no drop" there.
    component HoldDrop: DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: drag => drag.accept(Qt.IgnoreAction)
        onPositionChanged: drag => drag.accepted = false
        onDropped: drop => drop.accepted = false
    }

    // A group separator: groupGap wide, its 1 px line centred, inset s5 top and bottom.
    component Separator: Item {
        width: Theme.dock.groupGap
        height: Theme.dock.cellH
        Rectangle {
            x: Math.floor(parent.width / 2)
            y: Theme.space.s5
            width: Theme.size.rule
            height: parent.height - 2 * Theme.space.s5
            color: Theme.colors.line
        }
    }

    // One app.
    component Cell: Item {
        id: cell
        property string key: ""
        property int pinIndex: -1          // its place among the pinned apps (-1: not pinned)
        property int cellIndex: 0          // its place in allKeys (keyboard focus)
        readonly property var app: dock.info(key)
        readonly property var windows: app ? app.windows : []
        readonly property bool urgent: windows.some(w => w.is_urgent)
        // Dragging a pinned app: how far it has moved from where it was pressed.
        property real dragX: 0
        property real dragY: 0
        property bool dragging: false
        width: Theme.dock.cellW
        height: Theme.dock.cellH
        z: dragging ? 1 : 0

        Item {
            x: (cell.width - width) / 2 + cell.dragX
            y: Theme.space.s4 + cell.dragY
            width: Theme.dock.icon
            height: Theme.dock.icon
            // The tile: every app on one square, so drawings of different shapes line up by it; hovered, it takes
            // the line colour (the cell no longer fills). An app with no icon anywhere shows the tile alone.
            Rectangle {
                anchors.fill: parent
                color: area.containsMouse && !cell.dragging ? Theme.colors.line : Theme.colors.surfaceAlt
                Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
            }
            // The app's Swiss drawing in ink (design/app-icons, the 48 px master, drawn at Theme.dock.pictogram)
            // when the set has one; otherwise the app's own icon, in its own colours, at the same size.
            AppIcon {
                id: drawing
                anchors.centerIn: parent
                name: cell.app.entry ? (cell.app.entry.icon ?? "") : ""
                size: Theme.dock.pictogram
            }
            Image {
                id: img
                anchors.centerIn: parent
                width: Theme.dock.pictogram
                height: Theme.dock.pictogram
                visible: status === Image.Ready && !drawing.available
                source: cell.app.entry && !drawing.available ? Quickshell.iconPath(cell.app.entry.icon ?? "", true) : ""
                sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                asynchronous: true
                smooth: true
            }
        }
        // Running: the occupied-tag mark, 16 x 2 px in ink, s1 under the icon.
        Rectangle {
            visible: cell.windows.length > 0 && !cell.urgent
            x: (cell.width - width) / 2
            y: Theme.space.s4 + Theme.dock.icon + Theme.space.s1
            width: Theme.dock.mark
            height: Theme.size.marker
            color: Theme.colors.text
        }
        // Needs attention: the ink triangle in the running mark's place, standing on its baseline.
        Mark {
            visible: cell.urgent
            kind: "triangle"
            x: (cell.width - width) / 2
            y: Theme.space.s4 + Theme.dock.icon + Theme.space.s1 + Theme.size.marker - height
        }
        // Keyboard focus: a 2 px ink outline inside the cell.
        Rectangle {
            anchors.fill: parent
            visible: dock.keys && dock.focusIndex === cell.cellIndex
            color: "transparent"
            border.width: Theme.size.marker
            border.color: Theme.colors.text
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            property point press
            property bool wasDrag: false       // the press that ends a drag is not a click
            onContainsMouseChanged: {
                if (containsMouse) { dock.hoverKey = cell.key; dock.hoverX = rest.x + cell.mapToItem(body, 0, 0).x; dock.hovering = true; tipTimer.restart(); }
                else if (dock.hoverKey === cell.key) { dock.hovering = false; dock.tipShown = false; tipTimer.stop(); }
            }
            onPressed: mouse => { press = Qt.point(mouse.x, mouse.y); wasDrag = false; dock.tipShown = false; tipTimer.stop(); }
            onPositionChanged: mouse => {
                if (!pressed || cell.pinIndex < 0 || !(mouse.buttons & Qt.LeftButton)) return;
                const dx = mouse.x - press.x, dy = mouse.y - press.y;
                if (!cell.dragging && Math.hypot(dx, dy) > Theme.space.s2) { cell.dragging = true; dock.dragging = true; }
                if (cell.dragging) { cell.dragX = dx; cell.dragY = Math.min(0, dy); }
            }
            onReleased: mouse => {
                if (!cell.dragging) return;
                // Up off the dock (more than half its height): unpin; sideways: a new place among the pinned.
                const unpin = cell.dragY < -Theme.dock.cellH / 2;
                const to = cell.pinIndex + Math.round(cell.dragX / Theme.dock.cellW);
                const key = cell.key;
                cell.dragging = false; cell.dragX = 0; cell.dragY = 0; wasDrag = true;
                dock.dragging = false;
                // Last: the change rebuilds the pinned row, and this cell with it.
                if (unpin) Prefs.toggleDockPin(key); else Prefs.moveDockPin(key, to);
            }
            onCanceled: { cell.dragging = false; cell.dragX = 0; cell.dragY = 0; dock.dragging = false; }
            onClicked: mouse => {
                if (wasDrag) return;
                const x = rest.x + cell.mapToItem(body, 0, 0).x;
                if (mouse.button === Qt.RightButton) dock.openMenu(cell.key, x);
                else if (mouse.button === Qt.MiddleButton) dock.launch(cell.app.entry);
                else dock.activate(cell.key, x);
                // Over windows, an app chosen is the dock's job done (a menu opened keeps it).
                if (dock.peek && dock.menuKey === "") dock.hide();
            }
        }
    }

    // The trash's cell: hover, the name label, keyboard focus and the menu as an app's; no running mark, no drag. Files
    // dropped on it go into the trash.
    component TrashCell: Item {
        id: tcell
        readonly property string key: ":trash"
        property int cellIndex: 0
        readonly property bool full: Trash.count > 0
        width: Theme.dock.cellW
        height: Theme.dock.cellH
        // On its tile like the apps (hovered, or with files dragged over it, the tile takes the line colour). The Swiss
        // app icons' bin in ink (user-trash, outline; user-trash-full, solid: the owner's choice, 16 October 2026
        // ~13:30, over the theme's own bin chosen at 12:08); where the set has no drawing, the icon theme's own bin.
        // Both bins stay loaded, so filling or emptying swaps them without a blank frame.
        Item {
            x: (tcell.width - width) / 2
            y: Theme.space.s4
            width: Theme.dock.icon
            height: Theme.dock.icon
            Rectangle {
                anchors.fill: parent
                color: tarea.containsMouse || tdrop.containsDrag ? Theme.colors.line : Theme.colors.surfaceAlt
                Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
            }
            AppIcon {
                id: emptySwiss
                anchors.centerIn: parent
                size: Theme.dock.pictogram
                name: "user-trash"
                visible: available && !tcell.full
            }
            AppIcon {
                id: fullSwiss
                anchors.centerIn: parent
                size: Theme.dock.pictogram
                name: "user-trash-full"
                visible: available && tcell.full
            }
            Image {
                id: emptyBin
                anchors.centerIn: parent
                width: Theme.dock.pictogram
                height: Theme.dock.pictogram
                visible: !tcell.full && status === Image.Ready && !emptySwiss.available
                source: Trash.icons[0] ? "file://" + Trash.icons[0] : ""
                sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
                smooth: true
            }
            Image {
                id: fullBin
                anchors.centerIn: parent
                width: Theme.dock.pictogram
                height: Theme.dock.pictogram
                visible: tcell.full && status === Image.Ready && !fullSwiss.available
                source: Trash.icons[1] ? "file://" + Trash.icons[1] : ""
                sourceSize: emptyBin.sourceSize
                smooth: true
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: dock.keys && dock.focusIndex === tcell.cellIndex
            color: "transparent"
            border.width: Theme.size.marker
            border.color: Theme.colors.text
        }
        MouseArea {
            id: tarea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onContainsMouseChanged: {
                if (containsMouse) { dock.hoverKey = tcell.key; dock.hoverX = rest.x + tcell.mapToItem(body, 0, 0).x; dock.hovering = true; tipTimer.restart(); }
                else if (dock.hoverKey === tcell.key) { dock.hovering = false; dock.tipShown = false; tipTimer.stop(); }
            }
            onPressed: { dock.tipShown = false; tipTimer.stop(); }
            onClicked: mouse => {
                const x = rest.x + tcell.mapToItem(body, 0, 0).x;
                if (mouse.button === Qt.RightButton) dock.openMenu(tcell.key, x);
                else dock.activate(tcell.key, x);
                if (dock.peek && dock.menuKey === "") dock.hide();
            }
        }
        // Taken as a copy, so the app that sent them never deletes anything itself (some delete their files after a
        // move); trash-put moves them into the trash.
        DropArea {
            id: tdrop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => drag.accept(Qt.CopyAction)
            onContainsDragChanged: dock.trashDrag = containsDrag
            onDropped: drop => {
                const paths = Trash.localPaths(drop.urls);
                if (paths.length === 0) { drop.accepted = false; return; }
                drop.accept(Qt.CopyAction);
                Trash.put(paths);
            }
        }
    }

    // ---- The name label: the hovered app's name and tags, dockLift above the dock, left on the cell ----------
    property string hoverKey: ""          // the hovered cell (`hovering` says whether any is)
    property bool hovering: false
    property real hoverX: 0
    property bool tipShown: false
    Timer { id: tipTimer; interval: Theme.dock.hoverDelay; onTriggered: dock.tipShown = dock.hovering }
    TipBox {
        visible: dock.tipShown && dock.menuKey === "" && dock.enter === 1
        x: dock.hoverX
        y: rest.y - Theme.dock.lift - height
        Row {
            spacing: Theme.space.s2
            Txt { id: tipName; variant: Theme.font.label; text: dock.nameOf(dock.hoverKey); color: Theme.colors.text }
            Txt { anchors.baseline: tipName.baseline; variant: Theme.font.mono; text: dock.detailOf(dock.hoverKey); color: Theme.colors.textMuted }
        }
    }

    // ---- The menu (right click): rising from the dock's top edge, left on the cell -------------------------------
    property string menuKey: ""
    property real menuX: 0
    function openMenu(key, x) { tipShown = false; menuX = x; menuKey = key; }
    Rectangle {
        id: menu
        visible: dock.menuKey !== ""
        x: Math.min(dock.menuX, dock.width - width)
        y: rest.y - height
        width: Theme.dock.menuWidth
        height: menuCol.height + 2 * Theme.space.s2
        color: Theme.colors.surface
        // A 1 px line on three sides; it stands on the dock's top edge.
        Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
        Rectangle { width: Theme.size.rule; height: parent.height; color: Theme.colors.line }
        Rectangle { x: parent.width - width; width: Theme.size.rule; height: parent.height; color: Theme.colors.line }
        // Takes the clicks inside it (the catcher behind closes the menu on a click elsewhere).
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        readonly property bool isTrash: dock.menuKey === ":trash"
        readonly property var app: dock.menuKey !== "" && !isTrash ? dock.info(dock.menuKey) : null
        readonly property var windows: app ? app.windows : []
        readonly property var actions: app && app.entry ? app.entry.actions : []
        Column {
            id: menuCol
            y: Theme.space.s2
            width: parent.width
            Caps {
                leftPadding: Theme.space.s4
                topPadding: Theme.space.s1
                bottomPadding: Theme.space.s2
                width: parent.width
                elide: Text.ElideRight
                color: Theme.colors.textMuted
                text: menu.isTrash
                      ? (dock.confirmEmpty ? "Erase " + dock.detailOf(":trash") + " for good?" : "Trash · " + dock.detailOf(":trash"))
                      : dock.nameOf(dock.menuKey) + " · " + (menu.windows.length === 0 ? "not running"
                      : menu.windows.length + (menu.windows.length === 1 ? " window" : " windows"))
            }
            Repeater {
                model: menu.windows
                MenuRow {
                    required property var modelData
                    text: "tag " + dock.tagsOf([modelData]).join(", ") + " · " + Mango.cleanTitle(modelData.title)
                    onChosen: Mango.focusClient(modelData.id)
                }
            }
            MenuRule { visible: menu.actions.length > 0 }
            Repeater {
                model: menu.actions
                MenuRow {
                    required property var modelData
                    text: modelData.name
                    // A desktop action ("New Window") starts the app as a click does: "starting" until its window opens.
                    onChosen: Busy.start(menu.app.entry, modelData)
                }
            }
            MenuRule { visible: !menu.isTrash }
            MenuRow {
                visible: !menu.isTrash
                text: Prefs.dockPinned.includes(dock.menuKey) ? "Unpin" : "Pin"
                onChosen: Prefs.toggleDockPin(dock.menuKey)
            }
            MenuRow {
                visible: menu.windows.length > 0
                text: "Quit"
                onChosen: dock.quit(dock.menuKey)
            }
            // The trash: open it; empty it, asked once.
            MenuRow { visible: menu.isTrash && !dock.confirmEmpty; text: "Open"; onChosen: Trash.open() }
            MenuRule { visible: menu.isTrash && !dock.confirmEmpty && Trash.count > 0 }
            MenuRow {
                visible: menu.isTrash && !dock.confirmEmpty && Trash.count > 0
                text: "Empty Trash…"
                keepOpen: true
                onChosen: dock.confirmEmpty = true
            }
            MenuRow { visible: menu.isTrash && dock.confirmEmpty; text: "Empty Trash"; onChosen: Trash.empty() }
            MenuRow { visible: menu.isTrash && dock.confirmEmpty; text: "Cancel" }
        }
    }
    // A row of the menu: the shell's list row, its text 16 px in (the menu's own inset).
    component MenuRow: RowItem {
        id: mrow
        property string text
        property bool keepOpen: false      // a step that leaves the menu open (Empty Trash… -> its question)
        signal chosen()
        inset: Theme.space.s4
        onActivated: { mrow.chosen(); if (!mrow.keepOpen) dock.menuKey = ""; }      // act first: closing the menu destroys this row
        Txt {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            variant: Theme.font.body
            elide: Text.ElideRight
            text: mrow.text
        }
    }
}
