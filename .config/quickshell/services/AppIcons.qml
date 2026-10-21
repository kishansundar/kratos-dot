pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// The Swiss app icons (design/app-icons): which apps the folder assets/app-icons draws. It is laid out as an icon
// theme (index.theme; scalable/ holds the 48 px masters, 16x16/ the 16 px drawings, each in apps/, places/ or status/),
// one file per icon name, the name an app's desktop entry gives. The shell still sets no icon theme: AppIcon loads
// these files by path, so icons outside the set (and every app outside the shell) stay their own. The folders are
// watched: a file added draws that app at once, a file deleted gives the app its own icon back.
Singleton {
    id: root

    readonly property string dir: Quickshell.shellDir + "/assets/app-icons"
    property var masters: ({})     // icon name -> file URL of the 48 px master
    property var smalls: ({})      // icon name -> file URL of the 16 px drawing

    // The drawing for `name` at `size` px, "" when the set has none: the 16 px drawing at 16 and under (the master
    // when an app has no 16 px one), the master above.
    function file(name, size) {
        if (!name) return "";
        if (size <= 16 && smalls[name]) return smalls[name];
        return masters[name] ?? "";
    }

    // Tray items that send pixels or a picture file instead of an icon name, known by their id or title (as they were
    // on 16 October 2026: 1Password sends pixels, RustDesk a PNG and an id with its process number in it); any other
    // item by the icon name it sends.
    readonly property var trayIds: [[/^1Password/i, "1password"], [/^rustdesk$/i, "rustdesk"], [/^steam/i, "steam"]]
    function trayName(item) {
        if (!item) return "";
        const id = String(item.id ?? ""), title = String(item.title ?? "");
        for (const [re, name] of trayIds)
            if (re.test(id) || re.test(title)) return name;
        const m = /^image:\/\/icon\/([^?\/][^?]*)/.exec(String(item.icon ?? ""));
        return m ? m[1] : "";
    }

    // Tray items outside the set whose picture is one colour made for one kind of panel, known by their id or title:
    // the tray draws their own picture in ink. CoolerControl sends only white pixels (RGB 249-255), which vanished on
    // the Light bar (19 October 2026). Known by name, not by reading the pixels: a Canvas reads them through Qt's image
    // reader thread, where Quickshell's icon provider is not thread-safe (a hot reload crashed the shell).
    readonly property var trayInk: [/^CoolerControl$/i]
    function trayInked(item) {
        if (!item) return false;
        const id = String(item.id ?? ""), title = String(item.title ?? "");
        return trayInk.some(re => re.test(id) || re.test(title));
    }

    Instantiator {
        id: folders
        model: ["scalable/apps", "scalable/places", "scalable/status", "16x16/apps", "16x16/places", "16x16/status"]
        delegate: FolderListModel {
            required property string modelData
            readonly property bool small: modelData.startsWith("16x16")
            folder: "file://" + root.dir + "/" + modelData
            nameFilters: ["*.svg"]
            showDirs: false
            onStatusChanged: collect.restart()
            onCountChanged: collect.restart()
            onDataChanged: collect.restart()        // a file renamed over another keeps the count
            onRowsInserted: collect.restart()
            onRowsRemoved: collect.restart()
            onModelReset: collect.restart()
        }
        onObjectAdded: collect.restart()
    }
    // A folder's watch sees files come and go (and renamed over), not a file written over in place (cp onto it): each
    // file is watched as well, and a write counts `revision` on. It goes into every URL with the file's time, so a
    // drawing saved over an old one is loaded again rather than taken from the image cache.
    property int revision: 0
    property var files: []
    Instantiator {
        model: root.files
        delegate: FileView {
            required property string modelData
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: { root.revision++; collect.restart(); }
        }
    }
    // One pass over every folder after a burst of changes.
    Timer {
        id: collect
        interval: 50
        onTriggered: {
            const masters = {}, smalls = {}, files = [];
            for (let i = 0; i < folders.count; i++) {
                const f = folders.objectAt(i);
                if (!f || f.status !== FolderListModel.Ready) continue;
                for (let j = 0; j < f.count; j++) {
                    const url = f.get(j, "fileUrl") + "?" + f.get(j, "fileModified").getTime() + "-" + root.revision;
                    // fileBaseName stops at the first dot ("org" for org.gnome.Nautilus.svg): strip the suffix instead.
                    (f.small ? smalls : masters)[String(f.get(j, "fileName")).replace(/\.svg$/i, "")] = url;
                    files.push(f.get(j, "filePath"));
                }
            }
            root.masters = masters;
            root.smalls = smalls;
            if (JSON.stringify(files) !== JSON.stringify(root.files)) root.files = files;
        }
    }
}
