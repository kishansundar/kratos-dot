import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import "../services/PictureFacts.js" as Facts
import "../services/Format.js" as Format

// The wallpaper picker (Super+W), after skwd-wall's (liixini/skwd-wall: its Slices and Wall pickers, its colour sort
// and its filters) in this shell's look: the pictures of a folder on a band across the middle of the screen.
//
//   WALLPAPER                                     ~/pictures/wallpapers/swiss-typography · for dark mode · 7 / 32
//   ├┴┴┴┴
//   SORT colour date name size   COLOUR any ■ 8 □ 24   SHAPE all wide tall   ○ favourites 2   random r
//
//          ╱▒▒╱╱▒▒╱╱▒▒╱ ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╱ ╱▒▒╱╱▒▒╱╱▒▒╱
//         ╱▒▒╱╱▒▒╱╱▒▒╱ ╱                      ╱ ╱▒▒╱╱▒▒╱╱▒▒╱
//   ─────────────────────────────▌─────────────────────────────────── the cards stand on a line
//                      think-more-design-less-black.png
//                      png · 108 kB · 5120 × 2880 · 20 oct 2026 · neutral · in use      ←→ move · enter set · tab …
//
// Two arrangements, M switches them (kept in Prefs.wallLayout):
// - "slices", skwd-wall's Slices: every card a parallelogram leaning like italics (its top edge `skew` right of its
//   foot), the marked one wide, the others narrow slices 8 px apart along the slant, grey until marked or pointed at,
//   and fading out towards the screen's edges (skwd-wall's fade: whole within 60 % of the way from the middle, gone at
//   120 %). They stand on one line, like the marks of the bar on its baseline; the red index under the marked one's
//   foot is "here". skwd-wall's small preset: 360 px tall, slices 90, skew 25.
// - "wall", skwd-wall's Wall: the pictures as a contact sheet of 16:9 tiles, eight across and up to three rows high
//   (fewer when a filter leaves fewer pictures), grey like the slices, the marked one in colour with the red index
//   under it; ↑↓ move by rows.
// The filter row is skwd-wall's chip bar as words: sort (colour, as skwd-wall starts; date, name, size), colour (the
// swatches of the colours this folder has, each with its count), shape (wide, tall), favourites only, a random pick.
// A picture's colour is read from its pixels (services/PictureFacts.js): one of twelve hues or neutral, whichever
// covers most of it, so a picture added later sorts and filters by itself, whatever its name. Its size comes from the
// file's first bytes. Both are read once per picture, one after the other while the picker is open, the cards nearest
// the marked one first ("reading colours n / N" in the heading), and kept in picture-facts.json beside the small
// copies; the order settles when the reading ends. F marks the marked picture a favourite (a filled circle on its
// card; Prefs.wallFavourites).
//
// Each mode has its own picture: Enter sets the marked one for the mode named in the heading (the one in use when the
// picker opens; Tab switches to the other). Folders are cards too, always first: Enter goes in, Backspace goes back up
// (never above ~/Pictures). Left/Right or the wheel move, Page Up/Down by a page, Home/End to the ends; Shift+Left/Right
// step through the colours, Alt+Left/Right the sorts, Shift+F favourites only, R marks a random picture. A click on a
// card marks it, a click on the marked card sets it. Esc or a click outside closes.
//
// Pictures can be large (8K) and take up to a second to decode, so each is decoded once, by that reading, into a
// 640 px copy in ~/.cache/swiss-desktop/thumbs, named after the file's path and modification time (a changed file gets
// a new copy); the cards show only copies (a card stays blank until its picture is read). One cache: picture-facts.json
// holds, per copy, the picture's path, its facts and the strips under the bar (below). Copies and facts of pictures
// that are gone, or have changed, are dropped when the picker opens; a copy that went missing is made again. A folder
// that does not exist says so; a picture that cannot be decoded says "can't be read".
//
// The bar is Theme.bar.opacity of the mode's background over the picture's top strip, so a picture can make it hard
// to read: a marked picture whose strip would put the bar's faint text under Theme.bar.minTextContrast or its ticks
// under minTickContrast, in the mode the picker sets it for, carries the attention mark and "low contrast under the
// bar" in its caption; one smaller than the screen (drawn enlarged) carries "smaller than the screen". The strip is read
// once per picture (kept in `facts[key].strips`, read through strip()), not on every opening.
Scope {
    id: root

    readonly property string home: Theme.home
    readonly property string thumbDir: Theme.cacheDir + "/thumbs"
    readonly property url topFolder: "file://" + home + "/Pictures"
    readonly property int thumbWidth: 640
    readonly property int probeWidth: 64        // the copy a picture's colour is read from (64 x 36 for 16:9)

    readonly property bool open: Panels.current === "wallpaper"
    property url folder: ""                 // kept while the shell runs: the picker reopens where it was left
    property string target: "dark"          // the mode Enter sets the picture for
    // skwd-wall's sort and filters, kept while the shell runs.
    readonly property var sorts: ["colour", "date", "name", "size"]
    property string sortBy: "colour"
    property int colour: -1                 // -1 any; 0-11 a hue, 12 neutral (PictureFacts)
    property string shape: "all"            // "all", "wide", "tall"
    property bool favouritesOnly: false

    // The picture each mode uses now, as an absolute path.
    function inUse(mode) {
        const p = mode === "light" ? Theme.lightPalette : Theme.darkPalette;
        return p && p.wallpaper ? (p.wallpaper.startsWith("/") ? p.wallpaper : home + "/" + p.wallpaper) : "";
    }
    function apply(path) {
        Quickshell.execDetached([Theme.desktopDir + "/bin/swiss-wallpaper", path, root.target]);
        Panels.close();
    }


    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.thumbDir])
    onOpenChanged: {
        if (!open) return;
        target = Theme.mode;
        const current = inUse(target);
        if (String(folder) === "")
            folder = current !== "" ? "file://" + current.replace(/\/[^\/]*$/, "") : root.topFolder;
    }

    // A card: the picture (or a folder's name) cut to a parallelogram whose top edge leans `skew` right of its foot (a
    // rectangle at 0), grey until marked or pointed at, a hairline frame (ink when marked), a filled circle when a
    // favourite. Clicks count only inside the shape, so leaning neighbours never take each other's.
    component Face: Item {
        id: face
        property var picker                     // the picker's view: its small copies (copied, lost, thumbDir, thumbWidth)
        property var entry: null
        property bool marked: false
        property bool favourite: false
        property real skew: 0
        signal picked()
        readonly property real foot: width - skew
        readonly property bool pointed: mouse.containsMouse

        // The small copy, once the reading has made it; nothing before (the original is never decoded here).
        readonly property bool copied: !!entry && !entry.dir && picker.copied(entry.key)

        Shape {
            id: ground
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            containsMode: Shape.FillContains
            ShapePath {
                strokeWidth: -1
                fillColor: Theme.colors.surfaceAlt
                startX: 0; startY: face.height
                PathLine { x: face.foot; y: face.height }
                PathLine { x: face.width; y: 0 }
                PathLine { x: face.skew; y: 0 }
                PathLine { x: 0; y: face.height }
            }
        }
        // The picture's mask: the same shape, out of sight.
        Item {
            id: cut
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: "white"
                    startX: 0; startY: face.height
                    PathLine { x: face.foot; y: face.height }
                    PathLine { x: face.width; y: 0 }
                    PathLine { x: face.skew; y: 0 }
                    PathLine { x: 0; y: face.height }
                }
            }
        }

        // A folder: set as a label in the card's lower left corner.
        Column {
            anchors { left: parent.left; bottom: parent.bottom; margins: Theme.space.s3 }
            visible: !!face.entry && face.entry.dir
            spacing: 0
            Annot { text: "folder" }
            Txt {
                visible: face.marked
                text: face.entry ? face.entry.name : ""
                variant: Theme.font.h2
            }
        }

        Image {
            id: picture
            anchors.fill: parent
            visible: !!face.entry && !face.entry.dir
            source: face.copied ? "file://" + face.picker.thumbDir + "/" + face.entry.key : ""
            sourceSize.width: face.picker.thumbWidth
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.med } }
            layer.enabled: true
            layer.effect: MultiEffect {
                saturation: face.marked || face.pointed ? 0 : -1
                Behavior on saturation { NumberAnimation { duration: Theme.motion.med } }
                maskEnabled: face.skew > 0
                maskSource: cut
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            // The copy is gone (a cache clean-up): read the picture again.
            onStatusChanged: if (status === Image.Error && face.copied) face.picker.lost(face.entry)
        }

        // A favourite: the filled circle on a plate of the surface, in the top left corner.
        Rectangle {
            visible: face.favourite
            x: Math.round(face.skew) + Theme.space.s2
            y: Theme.space.s2
            width: Theme.space.s4
            height: Theme.space.s4
            color: Theme.colors.surface
            Mark { anchors.centerIn: parent; kind: "circle" }
        }

        // A hairline frame, ink on the marked card (on whole pixels where it runs straight).
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: Theme.size.rule
                strokeColor: face.marked ? Theme.colors.text : Theme.colors.line
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                startX: 0.5; startY: face.height - 0.5
                PathLine { x: face.foot - 0.5; y: face.height - 0.5 }
                PathLine { x: face.width - 0.5; y: 0.5 }
                PathLine { x: face.skew + 0.5; y: 0.5 }
                PathLine { x: 0.5; y: face.height - 0.5 }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            containmentMask: ground
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: face.picked()
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: window
            screen: Panels.screen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "swiss-wallpaper"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // A click outside the band closes; a click on its empty parts does nothing.
            MouseArea { anchors.fill: parent; onClicked: Panels.close() }

            Rectangle {
                id: band
                readonly property int margin: Theme.bar.padX
                // Slices: skwd-wall's small preset.
                readonly property int cardHeight: 360
                readonly property int bigWidth: Math.round(cardHeight * 16 / 9)
                readonly property int sliceWidth: 90
                readonly property int skew: 25
                readonly property int gap: Theme.space.s2       // between two slices, along the slant
                readonly property int lead: Math.round((width - bigWidth - skew) / 2)   // the marked card's left edge
                // Wall: skwd-wall's grid, about its 300 px tiles, eight across and three rows high.
                readonly property int wallColumns: 8
                readonly property int wallRows: 3
                readonly property int wallGap: Theme.space.s4
                readonly property int tileWidth: Math.floor((width - 2 * margin - (wallColumns - 1) * wallGap) / wallColumns)
                readonly property int tileHeight: Math.round(tileWidth * 9 / 16)
                readonly property bool wall: Prefs.wallLayout === "wall"

                width: parent.width
                height: column.implicitHeight + 2 * Theme.space.s5
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.bar.height / 2
                color: Theme.colors.surface
                MouseArea { anchors.fill: parent }
                Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
                Rectangle { y: parent.height - height; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }

                Item {
                    id: view
                    anchors.fill: parent
                    focus: true

                    readonly property string mode: root.target          // the mode Enter sets the picture for
                    readonly property string thumbDir: root.thumbDir
                    readonly property int thumbWidth: root.thumbWidth
                    readonly property bool atTop: String(root.folder) === String(root.topFolder)
                    // (A folder that does not exist has no parentFolder: its path's.)
                    function goUp() {
                        if (!atTop) root.folder = missing ? String(root.folder).replace(/\/[^\/]+\/?$/, "") : pictures.parentFolder;
                    }
                    function open(entry) {
                        if (!entry) return;
                        if (entry.dir) root.folder = entry.url;
                        else root.apply(entry.path);
                    }
                    function thumbName(path, modified) {
                        return Qt.md5(path) + "-" + Math.floor(modified.getTime() / 1000) + ".jpg";
                    }

                    // ---- The cards: the folder's entries, filtered and sorted ----------------------------------
                    property var entries: []        // { dir, path, url, name, suffix, size, modified, key }
                    property var files: []          // the folder's pictures before the filters
                    property var swatches: []       // the colours among them: [{ colour, count }]
                    readonly property var list: layout.item ? layout.item.list : null
                    readonly property int index: list ? list.currentIndex : -1
                    readonly property var current: index >= 0 && index < entries.length ? entries[index] : null
                    readonly property int across: band.wall ? band.wallColumns : 1
                    readonly property int page: band.wall ? band.wallColumns * band.wallRows : 10

                    function markAt(i) {
                        if (list && entries.length > 0) list.currentIndex = Math.max(0, Math.min(entries.length - 1, i));
                    }
                    function step(count) { if (index >= 0) markAt(index + count) }
                    function random() {
                        const pool = [];
                        for (let i = 0; i < entries.length; i++) if (!entries[i].dir && i !== index) pool.push(i);
                        if (pool.length > 0) markAt(pool[Math.floor(Math.random() * pool.length)]);
                    }
                    function favourites(list) { return list.filter(f => Prefs.wallFavourites.includes(f.path)).length }

                    // The folder's rows as entries. FolderListModel can say Ready while it still holds the last
                    // folder's rows: rows from elsewhere are skipped, and it is read again on every change.
                    function read() {
                        if (missing) { folders = []; files = []; entries = []; swatches = []; return; }
                        if (!ready) return;
                        const dir = decodeURIComponent(String(pictures.folder)).replace("file://", "").replace(/\/$/, "") + "/";
                        const dirs = [], found = [];
                        for (let i = 0; i < pictures.count; i++) {
                            const path = pictures.get(i, "filePath");
                            if (path.slice(0, path.lastIndexOf("/") + 1) !== dir) continue;
                            const e = {
                                dir: pictures.get(i, "fileIsDir"), path: path, url: pictures.get(i, "fileUrl"),
                                name: pictures.get(i, "fileName"), suffix: pictures.get(i, "fileSuffix"),
                                size: pictures.get(i, "fileSize"), modified: pictures.get(i, "fileModified"), key: ""
                            };
                            if (!e.dir) e.key = thumbName(e.path, e.modified);
                            (e.dir ? dirs : found).push(e);
                        }
                        // A folder read for the first time starts on the picture in use.
                        const fresh = String(shownFolder) !== String(pictures.folder);
                        shownFolder = pictures.folder;
                        folders = dirs;
                        files = found;
                        name(found);
                        study(arrange(fresh ? root.inUse(root.target) : current ? current.path : ""));
                    }
                    property var folders: []
                    property url shownFolder: ""
                    // The entries in the filters' order, the marked one kept where it still shows.
                    function arrange(keep) {
                        const of = k => facts[k];
                        const narrowed = Facts.filter(files, { colour: -1, shape: root.shape, favourites: root.favouritesOnly },
                                                      of, Prefs.wallFavourites);
                        swatches = Facts.colours(narrowed, of);
                        const shown = Facts.filter(narrowed, { colour: root.colour, shape: "all", favourites: false }, of, []);
                        entries = folders.concat(Facts.order(shown, root.sortBy, of));
                        const at = Math.max(0, entries.findIndex(e => e.path === keep));
                        Qt.callLater(() => { if (layout.item) layout.item.jump(at); });
                        return at;
                    }
                    function rearrange() { arrange(current ? current.path : "") }
                    function sortTo(by) { root.sortBy = by; rearrange(); }
                    function colourTo(c) { root.colour = c; rearrange(); }
                    function shapeTo(s) { root.shape = s; rearrange(); }
                    function cycle(list, now, by) { return list[(list.indexOf(now) + by + list.length) % list.length] }
                    Connections {
                        target: Prefs
                        function onWallFavouritesChanged() { if (root.favouritesOnly) view.rearrange() }
                    }

                    Keys.onPressed: event => {
                        const shift = event.modifiers & Qt.ShiftModifier, alt = event.modifiers & Qt.AltModifier;
                        switch (event.key) {
                        case Qt.Key_Escape: Panels.close(); break;
                        case Qt.Key_Left:
                        case Qt.Key_Right: {
                            const by = event.key === Qt.Key_Left ? -1 : 1;
                            if (shift) colourTo(cycle([-1].concat(swatches.map(s => s.colour)), root.colour, by));
                            else if (alt) sortTo(cycle(root.sorts, root.sortBy, by));
                            else step(by);
                            break;
                        }
                        case Qt.Key_Up: if (!band.wall) return; step(-across); break;
                        case Qt.Key_Down: if (!band.wall) return; step(across); break;
                        case Qt.Key_PageUp: step(-page); break;
                        case Qt.Key_PageDown: step(page); break;
                        case Qt.Key_Home: markAt(0); break;
                        case Qt.Key_End: markAt(entries.length - 1); break;
                        case Qt.Key_Backspace: goUp(); break;
                        case Qt.Key_Tab: root.target = root.target === "dark" ? "light" : "dark"; break;
                        case Qt.Key_M:
                            layout.keep = current ? current.path : "";
                            Prefs.set("wallLayout", band.wall ? "slices" : "wall");
                            break;
                        case Qt.Key_F:
                            if (shift) { root.favouritesOnly = !root.favouritesOnly; rearrange(); }
                            else if (current && !current.dir) Prefs.toggleWallFavourite(current.path);
                            break;
                        case Qt.Key_R: random(); break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter: open(current); break;
                        default: return;
                        }
                        event.accepted = true;
                    }

                    FolderListModel {
                        id: pictures
                        folder: root.folder
                        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                        caseSensitive: false
                        showDirs: true
                        showDirsFirst: true
                        showDotAndDotDot: false
                    }
                    // A folder that does not exist (deleted, or the picture in use was in it): FolderListModel goes
                    // Null for it, or, made with it, lists the shell's working folder instead.
                    readonly property bool missing: String(root.folder) !== ""
                        && (pictures.status === FolderListModel.Null || String(pictures.folder) !== String(root.folder))
                    readonly property bool ready: pictures.status === FolderListModel.Ready && !missing && loaded
                    onReadyChanged: Qt.callLater(read)
                    Connections {
                        target: pictures
                        function onStatusChanged() { Qt.callLater(view.read) }
                        function onCountChanged() { Qt.callLater(view.read) }
                    }

                    // ---- What a picture is: its small copy, colour and size (PictureFacts) ----------------------
                    // One cache, picture-facts.json beside the small copies, by the copy's name:
                    //   { path, colour, sat, light, w, h, strips: { <screen width>: { dark, light } } }
                    // or { path, failed: true } for a picture that cannot be decoded (kept until the file changes);
                    // an entry with only path and strips has its strip measured, its picture not read yet.
                    property var facts: ({})
                    function known(key) { const x = facts[key]; return !!x && (x.colour !== undefined || !!x.failed) }
                    function copied(key) { const x = facts[key]; return !!x && x.colour !== undefined }
                    // Nothing is read or forgotten before the cache is in (or found missing).
                    property bool loaded: false
                    property int loading: 1
                    FileView {
                        id: factsFile
                        path: root.thumbDir + "/picture-facts.json"
                        blockLoading: true
                        atomicWrites: true
                        printErrors: false          // no file yet: nothing read
                        onLoaded: view.begin()
                        onLoadFailed: view.begin()
                    }
                    function save() { factsFile.setText(JSON.stringify(facts) + "\n") }
                    Component.onCompleted: forceActiveFocus()
                    function begin() {
                        if (--loading > 0) return;
                        // A cache that does not parse is read afresh, and nothing on disk is forgotten this time.
                        let f = {}, whole = true;
                        if (factsFile.loaded) try { f = JSON.parse(factsFile.text()); } catch (e) { f = {}; whole = false; }
                        facts = f;
                        loaded = true;
                        if (!whole) return;
                        tidy.asked = Object.keys(f).map(k => f[k].path).filter(p => !!p);
                        tidy.command = ["sh", "-c", 'dir=$1; shift; stat -L -c "%Y %n" -- "$@" 2>/dev/null; '
                                        + 'cd "$dir" 2>/dev/null && for t in *.jpg; do [ -e "$t" ] && printf "copy %s\\n" "$t"; done; true',
                                        "sh", root.thumbDir].concat(tidy.asked);
                        tidy.running = true;
                    }

                    // Forgetting, on opening: the entries whose picture is gone or has changed since (its copy's name
                    // is no longer its path and modification time), and the copies with no entry (older ones). Only the
                    // copies' own names (md5-seconds.jpg) are ever removed, and never the one being made.
                    Process {
                        id: tidy
                        property var asked: []          // the paths it looks at (entries named later are not judged)
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const now = {}, copies = [];
                                for (const line of text.split("\n")) {
                                    const sp = line.indexOf(" "), head = line.slice(0, sp), rest = line.slice(sp + 1);
                                    if (head === "copy") copies.push(rest);
                                    else if (/^[0-9]+$/.test(head)) now[rest] = view.thumbName(rest, new Date(Number(head) * 1000));
                                }
                                const f = view.facts;
                                const asked = new Set(tidy.asked);
                                const keys = Object.keys(f).filter(k => asked.has(f[k].path) && now[f[k].path] !== k);
                                view.discard(keys, copies.filter(n => !f[n] || keys.includes(n)));
                            }
                        }
                    }
                    function discard(keys, copies) {
                        const name = /^[0-9a-f]{32}-[0-9]+\.jpg$/;
                        const drop = copies.filter(n => name.test(n) && (!probing || n !== probing.key));
                        if (keys.length > 0) {
                            const o = Object.assign({}, facts);
                            for (const k of keys) delete o[k];
                            facts = o;
                            save();
                        }
                        if (drop.length > 0)
                            Quickshell.execDetached(["rm", "-f", "--"].concat(drop.map(n => root.thumbDir + "/" + n)));
                    }
                    // Entries from before they carried their path take it when their picture is seen.
                    function name(found) {
                        let named = false;
                        for (const f of found) {
                            const x = facts[f.key];
                            if (x && x.path !== f.path) { x.path = f.path; named = true; }
                        }
                        if (named) save();
                    }

                    // One picture at a time, nearest the marked card first: decoded once at the copy's width, grabbed
                    // and saved as its small copy; the copy decoded at 64 px (a smooth scale: a Canvas drawing it
                    // smaller samples instead, and averaging it in JavaScript took 0.25 s a picture), grabbed, saved
                    // and read by a Canvas (which can read neither an Image item nor a grab's own url); then the file's
                    // first bytes for its size. Off screen, in a 1 px window. A picture that fails at any step is
                    // learnt as failed; one that takes longer than `patience` is let go (read again next time), so
                    // nothing stops the queue.
                    property var queue: []
                    property var probing: null
                    property int studied: 0
                    property int studying: 0
                    readonly property int patience: 10000
                    // The folder's pictures not read yet; a folder changed mid-reading takes over the queue (the picture
                    // being read finishes first).
                    function study(at) {
                        const here = f => files.some(g => g.key === f.key);
                        const away = {};
                        entries.forEach((e, i) => away[e.path] = Math.abs(i - at));
                        queue = files.filter(f => !known(f.key) && (!probing || f.key !== probing.key))
                                     .sort((a, b) => (away[a.path] ?? 1e9) - (away[b.path] ?? 1e9));
                        studied = 0;
                        studying = queue.length + (probing && here(probing) ? 1 : 0);
                        if (!probing) next();
                    }
                    function next() {
                        if (probing) return;
                        if (queue.length === 0) {
                            const was = studying;
                            probing = null;
                            studying = 0;
                            if (was > 0) rearrange();
                            return;
                        }
                        probing = queue[0];
                        queue = queue.slice(1);
                        patienceTimer.restart();
                        copier.source = probing.url;
                    }
                    // A reading's answer; one given up on answers too late and is ignored.
                    function learn(key, value) {
                        if (!probing || probing.key !== key) return;
                        const o = Object.assign({}, facts), x = o[key];
                        o[key] = Object.assign({ path: probing.path }, x && x.strips ? { strips: x.strips } : {}, value);
                        facts = o;
                        save();
                        done();
                    }
                    function done() {
                        patienceTimer.stop();
                        if (files.some(f => f.key === probing.key)) studied++;
                        copier.source = "";
                        probe.source = "";
                        probeCanvas.key = "";
                        probing = null;
                        Qt.callLater(next);
                    }
                    Timer { id: patienceTimer; interval: view.patience; onTriggered: if (view.probing) view.done() }
                    // A card whose copy has gone: read again.
                    function lost(entry) {
                        if (!copied(entry.key)) return;
                        const o = Object.assign({}, facts), x = o[entry.key];
                        if (x.strips) o[entry.key] = { path: entry.path, strips: x.strips };
                        else delete o[entry.key];
                        facts = o;
                        save();
                        study(Math.max(0, index));
                    }
                    Item {
                        width: 1
                        height: 1
                        clip: true
                        Image {
                            id: copier
                            width: root.thumbWidth
                            height: implicitWidth > 0 ? Math.round(root.thumbWidth * implicitHeight / implicitWidth) : 1
                            sourceSize.width: root.thumbWidth
                            asynchronous: true
                            cache: false
                            onStatusChanged: {
                                if (!view.probing || String(source) === "") return;
                                const key = view.probing.key;
                                if (status === Image.Error) { view.learn(key, { failed: true }); return; }
                                if (status !== Image.Ready) return;
                                const grabbed = grabToImage(result => {
                                    if (!view.probing || view.probing.key !== key) return;
                                    if (!result.saveToFile(root.thumbDir + "/" + key)) { view.learn(key, { failed: true }); return; }
                                    probe.source = "file://" + root.thumbDir + "/" + key;
                                }, Qt.size(width, height));
                                if (!grabbed) view.learn(key, { failed: true });
                            }
                        }
                        Image {
                            id: probe
                            sourceSize.width: root.probeWidth
                            asynchronous: true
                            cache: false
                            onStatusChanged: {
                                if (!view.probing || String(source) === "") return;
                                const key = view.probing.key;
                                if (status === Image.Error) { view.learn(key, { failed: true }); return; }
                                if (status !== Image.Ready) return;
                                const grabbed = grabToImage(result => {
                                    if (!view.probing || view.probing.key !== key) return;
                                    if (!result.saveToFile(root.thumbDir + "/facts-probe.png")) { view.learn(key, { failed: true }); return; }
                                    probeCanvas.key = key;
                                    probeCanvas.width = probe.width;
                                    probeCanvas.height = probe.height;
                                    // A new url each time: the Canvas never reads an older picture.
                                    probeCanvas.picture = "file://" + root.thumbDir + "/facts-probe.png?" + Date.now();
                                    probeCanvas.loadImage(probeCanvas.picture);
                                });
                                if (!grabbed) view.learn(key, { failed: true });
                            }
                        }
                        Canvas {
                            id: probeCanvas
                            property string key: ""
                            property string picture: ""
                            property var found: null
                            onImageLoaded: requestPaint()
                            onPaint: {
                                if (picture === "" || !isImageLoaded(picture)) return;
                                const p = view.probing, url = picture;
                                picture = "";
                                if (p && p.key === key) {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.drawImage(url, 0, 0);
                                    found = Facts.colour(ctx.getImageData(0, 0, width, height).data);
                                    sizeReader.running = false;
                                    sizeReader.key = p.key;
                                    sizeReader.command = ["od", "-An", "-v", "-tu1", "-N",
                                        /^jpe?g$/i.test(p.suffix) ? "65536" : "32", p.path];
                                    sizeReader.running = true;
                                }
                                unloadImage(url);
                            }
                        }
                    }
                    Process {
                        id: sizeReader
                        property string key: ""
                        stdout: StdioCollector {
                            onStreamFinished: {
                                const d = Facts.dimensions(text.trim().split(/\s+/).map(Number));
                                const x = Object.assign({}, probeCanvas.found || { failed: true });
                                if (d) { x.w = d.w; x.h = d.h; }
                                view.learn(sizeReader.key, x);
                            }
                        }
                    }

                    // ---- The bar over the marked picture --------------------------------------------------------
                    // The strip under the bar (the picture as Background draws it: covering the screen, centred), read
                    // once per picture after its card has stayed marked a moment: its darkest and lightest pixels, kept
                    // in the picture's entry by the screen's width ({ dark: "#rrggbb", light: "#rrggbb" }). The worse
                    // of the two decides, as in the design audit (the bar's blur only evens the strip out).
                    readonly property var marked: current && !current.dir ? current : null
                    readonly property var markedFacts: marked && known(marked.key) ? facts[marked.key] : null
                    readonly property string stripKey: marked ? marked.key + "@" + window.width : ""
                    readonly property var strip: {
                        const x = marked ? facts[marked.key] : null;
                        return x && x.strips ? x.strips[window.width] ?? null : null;
                    }
                    onStripKeyChanged: if (stripKey !== "" && !strip) stripWait.restart(); else stripWait.stop()
                    Timer {
                        id: stripWait
                        interval: Theme.motion.med * 2          // as long as the row takes to move to a card
                        onTriggered: {
                            stripPicture.key = view.marked.key;
                            stripPicture.path = view.marked.path;
                            stripPicture.source = view.marked.url;
                        }
                    }
                    // Decoded as Background decodes it (the screen's size, covering, centred) and cut to the strip
                    // under the bar; that is grabbed, saved beside the small copies (bar-strip.png) and read by a
                    // Canvas. Off screen, like the reading: in a 1 px window, never seen.
                    Item {
                        width: 1
                        height: 1
                        clip: true
                        Item {
                            id: stripArea
                            width: window.width
                            height: Theme.bar.height
                            clip: true
                            Image {
                                id: stripPicture
                                property string key: ""
                                property string path: ""
                                width: window.width
                                height: window.height
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(window.width, window.height)
                                asynchronous: true
                                cache: false
                                onStatusChanged: {
                                    if (key === "") return;
                                    if (status === Image.Error) { key = ""; source = ""; return; }
                                    if (status !== Image.Ready) return;
                                    // This picture's, whichever card is marked by the time the grab and the Canvas
                                    // are done: a grab another picture has taken over from is dropped (its own
                                    // reading follows), so one picture's strip is never kept under another's name.
                                    const grabKey = stripPicture.key, grabPath = stripPicture.path;
                                    const grabbed = stripArea.grabToImage(result => {
                                        if (stripPicture.key !== grabKey) return;
                                        if (!result.saveToFile(root.thumbDir + "/bar-strip.png")) {
                                            stripPicture.key = "";
                                            stripPicture.source = "";
                                            return;
                                        }
                                        stripCanvas.key = grabKey;
                                        stripCanvas.path = grabPath;
                                        // A new url each time: the Canvas never draws an older strip.
                                        stripCanvas.strip = "file://" + root.thumbDir + "/bar-strip.png?" + Date.now();
                                        stripCanvas.loadImage(stripCanvas.strip);
                                    });
                                    if (!grabbed) { key = ""; source = ""; }
                                }
                            }
                        }
                        Canvas {
                            id: stripCanvas
                            property string strip: ""          // the saved grab, as a url
                            property string key: ""            // the picture it is of (set with the grab)
                            property string path: ""
                            width: window.width
                            height: Theme.bar.height
                            onImageLoaded: requestPaint()
                            onPaint: {
                                if (strip === "" || !isImageLoaded(strip) || key === "") return;
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.drawImage(strip, 0, 0);
                                const px = ctx.getImageData(0, 0, width, height).data;
                                const lin = [];
                                for (let c = 0; c < 256; c++) lin.push(Facts.linear(c));
                                let lo = 2, hi = -1, dark = 0, light = 0;
                                for (let i = 0; i < px.length; i += 4) {
                                    const l = 0.2126 * lin[px[i]] + 0.7152 * lin[px[i + 1]] + 0.0722 * lin[px[i + 2]];
                                    if (l < lo) { lo = l; dark = i; }
                                    if (l > hi) { hi = l; light = i; }
                                }
                                const hex = i => "#" + [px[i], px[i + 1], px[i + 2]]
                                    .map(v => v.toString(16).padStart(2, "0")).join("");
                                const o = Object.assign({}, view.facts);
                                const x = o[key] = Object.assign({ path: path }, o[key]);
                                x.strips = Object.assign({}, x.strips);
                                x.strips[window.width] = { dark: hex(dark), light: hex(light) };
                                view.facts = o;
                                view.save();
                                unloadImage(strip);
                                strip = "";
                                // Done with this picture; a newer one already being read is left to finish.
                                if (stripPicture.key === key) { stripPicture.key = ""; stripPicture.source = ""; }
                                key = "";
                            }
                        }
                    }
                    // The marked picture under the bar of the mode Enter sets it for: the faint text and the ticks
                    // against the bar's ground (sRGB blending) over the strip's darkest and lightest pixel, the worse.
                    readonly property var barCheck: {
                        const pal = mode === "light" ? Theme.lightPalette : Theme.darkPalette;
                        if (!strip || !pal.background) return null;
                        const bg = Facts.rgbOf(pal.background), a = Theme.bar.opacity;
                        const grounds = [strip.dark, strip.light]
                            .map(p => Facts.rgbOf(p).map((c, i) => a * bg[i] + (1 - a) * c));
                        const worst = ink => Math.min(...grounds.map(g => Facts.contrast(Facts.rgbOf(ink), g)));
                        const faint = worst(pal.muted), tick = worst(pal.borderStrong);
                        return { faint: faint, tick: tick,
                                 low: faint < Theme.bar.minTextContrast || tick < Theme.bar.minTickContrast };
                    }
                    // What the caption warns of: the bar over it, a picture drawn enlarged.
                    readonly property var warnings: {
                        const out = [];
                        const x = markedFacts;
                        if (x && x.failed) out.push("can't be read");
                        if (barCheck && barCheck.low) out.push("low contrast under the bar");
                        if (x && x.w && Math.max(window.width / x.w, window.height / x.h) > 1) out.push("smaller than the screen");
                        return out;
                    }

                    Column {
                        id: column
                        x: band.margin
                        y: Theme.space.s5
                        width: parent.width - 2 * band.margin
                        spacing: 0

                        // ---- Heading: the eyebrow, the folder, the mode, the count, the reading ----
                        SectionHead {
                            title: "Wallpaper"
                            annotation: decodeURIComponent(String(root.folder)).replace("file://" + root.home, "~")
                                + " · for " + view.mode + " mode"
                                + (view.entries.length > 0 ? " · " + (view.index + 1) + " / " + view.entries.length : "")
                                + (view.studying > 0 ? " · reading colours " + view.studied + " / " + view.studying : "")
                            TextButton {
                                visible: !view.atTop
                                text: "↑ Up"
                                onClicked: view.goUp()
                            }
                        }

                        // ---- The filters: skwd-wall's chip bar as words ----
                        Row {
                            height: Theme.size.hitTarget
                            spacing: Theme.space.s6

                            Row {
                                height: parent.height
                                spacing: Theme.space.s1
                                Caps { anchors.verticalCenter: parent.verticalCenter; text: "Sort" }
                                Segment {
                                    options: root.sorts
                                    current: root.sortBy
                                    onPicked: v => view.sortTo(v)
                                }
                            }
                            Row {
                                height: parent.height
                                spacing: Theme.space.s1
                                Caps { anchors.verticalCenter: parent.verticalCenter; text: "Colour" }
                                Segment {
                                    options: ["any"]
                                    current: root.colour < 0 ? "any" : ""
                                    onPicked: view.colourTo(-1)
                                }
                                // A swatch per colour the folder has (skwd-wall's colour circles as squares, the
                                // mark size), with its count; neutral is an empty square. The chosen one is
                                // underlined like a chosen word.
                                Repeater {
                                    model: view.swatches
                                    Item {
                                        id: swatch
                                        required property var modelData
                                        readonly property bool chosen: modelData.colour === root.colour
                                        width: swatchRow.implicitWidth + 2 * Theme.space.s2
                                        height: Theme.size.hitTarget
                                        HoverFill { pressed: swatchMouse.pressed; hovered: swatchMouse.containsMouse }
                                        Row {
                                            id: swatchRow
                                            anchors.centerIn: parent
                                            spacing: Theme.space.s1
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Theme.size.markCircle
                                                height: Theme.size.markCircle
                                                // Red is the one red; the other hues at one strength and lightness.
                                                color: swatch.modelData.colour === Facts.neutral ? "transparent"
                                                     : swatch.modelData.colour === 0 ? Theme.colors.accent
                                                     : Qt.hsla(swatch.modelData.colour / 12, 0.65, 0.45, 1)
                                                border.width: swatch.modelData.colour === Facts.neutral ? Theme.size.rule : 0
                                                border.color: Theme.colors.text
                                            }
                                            Annot {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: swatch.modelData.count
                                                color: swatch.chosen ? Theme.colors.text : Theme.colors.textMuted
                                            }
                                        }
                                        Rectangle {
                                            visible: swatch.chosen
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: Theme.size.marker
                                            color: Theme.colors.text
                                        }
                                        MouseArea {
                                            id: swatchMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.colourTo(swatch.chosen ? -1 : swatch.modelData.colour)
                                        }
                                    }
                                }
                            }
                            Row {
                                height: parent.height
                                spacing: Theme.space.s1
                                Caps { anchors.verticalCenter: parent.verticalCenter; text: "Shape" }
                                Segment {
                                    options: ["all", "wide", "tall"]
                                    current: root.shape
                                    onPicked: v => view.shapeTo(v)
                                }
                            }
                            // Favourites only: the on / off mark, the word, how many this folder has.
                            Item {
                                width: favRow.implicitWidth + 2 * Theme.space.s2
                                height: parent.height
                                HoverFill { pressed: favMouse.pressed; hovered: favMouse.containsMouse }
                                Row {
                                    id: favRow
                                    anchors.centerIn: parent
                                    spacing: Theme.space.s2
                                    Mark {
                                        anchors.verticalCenter: parent.verticalCenter
                                        kind: root.favouritesOnly ? "circle" : "ring"
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        variant: root.favouritesOnly ? Theme.font.labelStrong : Theme.font.label
                                        text: "favourites"
                                        color: root.favouritesOnly ? Theme.colors.text : Theme.colors.textMuted
                                    }
                                    Annot {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: view.favourites(view.files)
                                    }
                                }
                                MouseArea {
                                    id: favMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.favouritesOnly = !root.favouritesOnly; view.rearrange(); }
                                }
                            }
                            TextButton {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "random"
                                hint: "r"
                                onClicked: view.random()
                            }
                        }

                        Item { width: 1; height: Theme.space.s4 }

                        // ---- The cards: slices or the wall ----
                        Loader {
                            id: layout
                            x: band.wall ? 0 : -band.margin
                            sourceComponent: band.wall ? wallLayout : slicesLayout
                            // The marked picture stays marked across a switch (M sets it first).
                            property string keep: ""
                            onLoaded: {
                                const at = Math.max(0, view.entries.findIndex(e => e.path === keep));
                                Qt.callLater(() => { if (item) item.jump(at); });
                            }
                        }

                        Item { width: 1; height: Theme.space.s2 }

                        // ---- Caption, flush with the marked card's foot (the wall's left edge); keys on the right ----
                        Item {
                            width: parent.width
                            height: Math.max(caption.implicitHeight, keys.implicitHeight)
                            Column {
                                id: caption
                                x: band.wall ? 0 : band.lead - band.margin
                                width: band.bigWidth
                                spacing: 0
                                readonly property var item: view.current
                                Txt {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: caption.item ? caption.item.name
                                        : view.missing ? "No such folder"
                                        : !view.ready ? "Reading…"
                                        : view.files.length > 0 || view.folders.length > 0 ? "Nothing here with these filters"
                                        : "No pictures here"
                                    variant: Theme.font.bodyStrong
                                }
                                // The facts, then the attention mark and its words for each warning.
                                Row {
                                    width: parent.width
                                    spacing: Theme.space.s1
                                    Annot {
                                        id: factsLine
                                        readonly property var known: view.markedFacts
                                        readonly property bool inUse: !!view.marked && view.marked.path === root.inUse(root.target)
                                        text: (!caption.item ? "png, jpg or webp in " + decodeURIComponent(String(root.folder)).replace("file://" + root.home, "~")
                                            : caption.item.dir ? "folder · enter to open"
                                            : [caption.item.suffix.toLowerCase(), Format.fileSize(caption.item.size),
                                               known && known.w ? known.w + " × " + known.h : "",
                                               Qt.formatDate(caption.item.modified, "d MMM yyyy").toLowerCase(),
                                               known && known.colour !== undefined ? Facts.colourName(known.colour) : "",
                                               inUse ? "in use" : "",
                                               Prefs.wallFavourites.includes(caption.item.path) ? "favourite" : ""]
                                               .filter(s => s !== "").join(" · ")) + (view.warnings.length > 0 ? " ·" : "")
                                        color: inUse ? Theme.colors.textMuted : Theme.colors.textFaint
                                    }
                                    Repeater {
                                        model: view.warnings
                                        Row {
                                            id: warning
                                            required property string modelData
                                            required property int index
                                            spacing: Theme.space.s1
                                            Mark {
                                                y: Math.round((factsLine.height - Theme.size.markTriangle) / 2)
                                                kind: "triangle"
                                            }
                                            Annot {
                                                text: warning.modelData + (warning.index < view.warnings.length - 1 ? " ·" : "")
                                                color: Theme.colors.text
                                            }
                                        }
                                    }
                                }
                            }
                            Column {
                                id: keys
                                anchors { right: parent.right; top: parent.top; topMargin: 2 }
                                Annot {
                                    anchors.right: parent.right
                                    text: (band.wall ? "←→↑↓" : "←→") + " move · enter set" + (view.atTop ? "" : " · backspace up")
                                        + " · tab " + (view.mode === "dark" ? "light" : "dark") + " mode · esc close"
                                }
                                Annot {
                                    anchors.right: parent.right
                                    text: "m " + (band.wall ? "slices" : "wall") + " · shift ←→ colour · alt ←→ sort · f favourite · r random"
                                }
                            }
                        }
                    }

                    // ---- Slices: the cards standing on one line, the marked one in the middle ----
                    Component {
                        id: slicesLayout
                        Item {
                            readonly property alias list: row
                            function jump(i) {
                                row.highlightMoveDuration = 0;
                                row.currentIndex = i;
                                row.positionViewAtIndex(i, ListView.Center);
                                Qt.callLater(() => row.highlightMoveDuration = Theme.motion.med * 2);
                            }
                            width: band.width
                            height: band.cardHeight + Theme.space.s3

                            ListView {
                                id: row
                                width: parent.width
                                height: band.cardHeight
                                orientation: ListView.Horizontal
                                // The slant runs parallel: the next card's foot starts `gap` after this one's.
                                spacing: band.gap - band.skew
                                model: view.entries
                                cacheBuffer: 800
                                boundsBehavior: Flickable.StopAtBounds
                                highlightRangeMode: ListView.StrictlyEnforceRange
                                preferredHighlightBegin: band.lead
                                preferredHighlightEnd: band.lead + band.bigWidth + band.skew
                                highlightMoveDuration: Theme.motion.med * 2
                                header: Item { width: band.lead - row.spacing }
                                footer: Item { width: band.lead - row.spacing }

                                delegate: Item {
                                    id: cell
                                    required property var modelData
                                    required property int index
                                    readonly property bool marked: ListView.isCurrentItem
                                    property real foot: marked ? band.bigWidth : band.sliceWidth
                                    Behavior on foot { NumberAnimation { duration: Theme.motion.med; easing.type: Easing.OutCubic } }
                                    width: foot + band.skew
                                    height: row.height
                                    // skwd-wall's fade towards the ends of the strip.
                                    readonly property real off: Math.abs(x - row.contentX + width / 2 - row.width / 2) / (row.width / 2)
                                    opacity: Math.max(0, Math.min(1, 1 - (off - 0.6) / 0.6))

                                    Face {
                                        anchors.fill: parent
                                        picker: view
                                        entry: cell.modelData
                                        marked: cell.marked
                                        favourite: Prefs.wallFavourites.includes(cell.modelData.path)
                                        skew: band.skew
                                        onPicked: cell.marked ? view.open(cell.modelData) : view.markAt(cell.index)
                                    }
                                }
                            }
                            // The wheel moves along the row, a card per notch.
                            MouseArea {
                                anchors.fill: row
                                acceptedButtons: Qt.NoButton
                                property real accumulated: 0
                                onWheel: event => {
                                    accumulated += event.angleDelta.y || event.angleDelta.x;
                                    const steps = Math.trunc(accumulated / 120);
                                    if (steps !== 0) { accumulated -= steps * 120; view.step(-steps); }
                                }
                            }
                            // The line the cards stand on, with the red index under the marked one's foot.
                            Item {
                                y: band.cardHeight
                                width: parent.width
                                height: Theme.space.s3
                                Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.tick }
                                IndexMark {
                                    x: band.lead + Math.round((band.bigWidth - width) / 2)
                                    height: Theme.ruler.tickMajor
                                }
                            }
                        }
                    }

                    // ---- The wall: a contact sheet, three rows high ----
                    Component {
                        id: wallLayout
                        Item {
                            readonly property alias list: grid
                            function jump(i) {
                                grid.highlightMoveDuration = 0;
                                grid.currentIndex = i;
                                grid.positionViewAtIndex(i, GridView.Contain);
                                Qt.callLater(() => grid.highlightMoveDuration = Theme.motion.med * 2);
                            }
                            width: band.width - 2 * band.margin
                            height: grid.height

                            GridView {
                                id: grid
                                width: parent.width + band.wallGap
                                // As many rows as there are pictures for, three at most (one when there are none).
                                height: Math.max(1, Math.min(band.wallRows, Math.ceil(count / band.wallColumns))) * cellHeight
                                cellWidth: band.tileWidth + band.wallGap
                                cellHeight: band.tileHeight + band.wallGap
                                clip: true
                                model: view.entries
                                cacheBuffer: 400
                                boundsBehavior: Flickable.StopAtBounds
                                // The marked row kept off the edges: in the middle row once there is a row above.
                                highlightRangeMode: GridView.ApplyRange
                                preferredHighlightBegin: cellHeight
                                preferredHighlightEnd: 2 * cellHeight
                                highlightMoveDuration: Theme.motion.med * 2

                                delegate: Item {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    readonly property bool marked: GridView.isCurrentItem
                                    width: grid.cellWidth
                                    height: grid.cellHeight
                                    Face {
                                        width: band.tileWidth
                                        height: band.tileHeight
                                        picker: view
                                        entry: tile.modelData
                                        marked: tile.marked
                                        favourite: Prefs.wallFavourites.includes(tile.modelData.path)
                                        onPicked: tile.marked ? view.open(tile.modelData) : view.markAt(tile.index)
                                    }
                                    IndexMark {
                                        visible: tile.marked
                                        x: Math.round((band.tileWidth - width) / 2)
                                        y: band.tileHeight + Theme.space.s1
                                        height: Theme.ruler.tickMajor
                                    }
                                }
                            }
                            // The wheel moves a row per notch.
                            MouseArea {
                                anchors.fill: grid
                                acceptedButtons: Qt.NoButton
                                property real accumulated: 0
                                onWheel: event => {
                                    accumulated += event.angleDelta.y || event.angleDelta.x;
                                    const steps = Math.trunc(accumulated / 120);
                                    if (steps !== 0) { accumulated -= steps * 120; view.step(-steps * view.across); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
