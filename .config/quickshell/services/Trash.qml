pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// The trash, for the dock's bin (overlays/Dock): what is in it, the icon theme's bins, and what the dock does with it
// (open it, empty it, put dropped files in). One for the whole shell: each screen's dock reads the same.
// The home trash (the freedesktop Trash spec; this machine has no other filesystem files are trashed on). Its
// files/ folder is watched, so the bin fills and empties as files come and go. SWISS_TRASH_DIR points a test shell
// at a stand-in.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("SWISS_TRASH_DIR")
        || (Quickshell.env("XDG_DATA_HOME") || Theme.home + "/.local/share") + "/Trash"
    readonly property int count: files.count
    // A test shell (SWISS_DRY_RUN) that has not pointed SWISS_TRASH_DIR at a stand-in only says what it would do.
    readonly property bool standIn: !!Quickshell.env("SWISS_TRASH_DIR")
    readonly property bool dry: Theme.dryRun && !standIn
    FolderListModel {
        id: files
        folder: "file://" + root.dir + "/files"
        showDirs: true
        showDotAndDotDot: false
        showHidden: true
        showOnlyReadable: false
    }
    // The bin where the Swiss app icons have none (the dock's TrashCell): the icon theme's, the one swiss-mode gives GTK
    // for this mode (the icon_theme token: Papirus-Dark or -Light), looked up as the icon spec does it
    // (scripts/icon-lookup.sh). The shell sets no icon theme of its own. [empty, full]; "" where the theme has none.
    property var icons: ["", ""]
    Process {
        id: iconLookup
        running: true
        command: ["sh", "-c", 't=$(sed -n "s/^icon_theme=//p" "$1" 2>/dev/null); exec "$2" "${t:-hicolor}" user-trash user-trash-full',
            "sh", Theme.desktopDir + "/tokens/" + Theme.mode + ".env", Quickshell.shellDir + "/scripts/icon-lookup.sh"]
        stdout: StdioCollector { onStreamFinished: { const l = text.split("\n"); root.icons = [l[0] || "", l[1] || ""]; } }
    }
    Connections {
        target: Theme
        function onModeChanged() { Qt.callLater(() => iconLookup.running = true) }    // once `command` has followed
    }
    function open() {
        if (DesktopEntries.byId("org.gnome.Nautilus")) Quickshell.execDetached(["nautilus", "trash:///"]);
        else Quickshell.execDetached(["xdg-open", "file://" + root.dir + "/files"]);
    }
    function empty() { if (!emptier.running) emptier.running = true }
    // Everything in files/ and info/ (and expunged/, what a file manager left half deleted), and the size cache.
    // Read-only folders inside trashed trees are made writable first, or rm cannot empty them.
    Process {
        id: emptier
        command: ["sh", "-c", 't=$1; [ -d "$t/files" ] || exit 0; '
            + 'if [ "$2" = dry ]; then echo "DRYRUN empty $t"; exit 0; fi; '
            + 'find "$t/files" -mindepth 1 -type d ! -perm -u+w -exec chmod u+w {} + 2>/dev/null; '
            + 'find "$t/files" "$t/info" "$t/expunged" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null; '
            + 'rm -f -- "$t/directorysizes"; exit 0',
            "sh", root.dir, root.dry ? "dry" : ""]
        stdout: SplitParser { onRead: data => console.log("Trash:", data) }
    }
    // Files dropped on the trash go into it through trash-put (trash-cli, the freedesktop spec, as Files does it), so
    // they can be restored. Local files only; a drop that comes while one is going in waits its turn.
    function localPaths(urls) {
        const paths = [];
        for (const u of urls) {
            const m = String(u).match(/^file:\/\/(?:localhost)?(\/.*)$/);
            if (!m) return [];
            paths.push(decodeURIComponent(m[1]));
        }
        return paths;
    }
    property var queue: []
    function put(paths) {
        if (root.dry) {
            console.log("Trash: DRYRUN trash", JSON.stringify(paths));
            return;
        }
        queue = queue.concat(paths);
        if (!trasher.running) next();
    }
    function next() {
        if (queue.length === 0) return;
        trasher.command = ["trash-put"].concat(root.standIn ? ["--trash-dir", root.dir] : [], ["--"], queue);
        queue = [];
        trasher.running = true;
    }
    Process {
        id: trasher
        stderr: SplitParser { onRead: data => console.log("Trash: trash-put:", data) }
        onExited: root.next()
    }
}
