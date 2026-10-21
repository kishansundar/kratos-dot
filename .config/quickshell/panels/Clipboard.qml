import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Clipboard history (Super+V), from cliphist: type to narrow, Enter copies the entry again, Delete forgets it.
// The history is read when the panel opens; nothing runs while it is closed.
// Images (cliphist's preview "[[ binary data 7 KiB png 438x43 ]]") get a row of two hit targets: the picture fitted
// into Theme.size.clipThumbW x clipThumbH, never enlarged, in a hairline frame, then "438 × 43 · png · 7 KiB" in mono.
// Each is decoded once into `thumbs`, newest first, after the list is shown; its frame holds the place meanwhile, so
// nothing moves. Files of entries no longer in the history are removed there on every open.
SearchList {
    id: history

    property var entries: []      // cliphist lines: "<id>\t<preview>"
    readonly property string thumbs: Theme.cacheDir + "/clipboard"
    property var ready: ({})       // decoded image file names

    // An image entry: { id, file, format, size, w, h }, or null for text (and for binary data that is not a picture).
    function imageOf(line) {
        const tab = line.indexOf("\t");
        const id = line.slice(0, tab);
        const m = /^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/.exec(line.slice(tab + 1));
        if (tab < 0 || !m || !/^\d+$/.test(id) || Number(m[3]) < 1 || Number(m[4]) < 1) return null;
        return { id: id, file: id + "-" + m[3] + "x" + m[4] + "." + m[2], format: m[2], size: m[1], w: Number(m[3]), h: Number(m[4]) };
    }
    rowHeightOf: line => imageOf(line) ? 2 * Theme.size.hitTarget : Theme.size.hitTarget

    placeholder: "Search clipboard"
    emptyText: "Clipboard history is empty"
    hints: "enter copy · alt+1-9 copy row · delete forget · esc close"
    countLabel: results.length === 1 ? "item" : "items"
    results: {
        const q = query.trim().toLowerCase();
        return q ? entries.filter(l => l.toLowerCase().includes(q)) : entries;
    }

    // Only the entry's id reaches cliphist ("<id>\t", the way its list starts each line), on standard input through
    // "$1": the preview, which may be a copied password, never stands on a command line (/proc shows those to every
    // local user), and nothing in it is ever run.
    function idOf(line) { const id = String(line).split("\t")[0]; return /^\d+$/.test(id) ? id : "" }
    onAccepted: line => {
        Panels.close();
        const id = idOf(line);
        if (id !== "") Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist decode | wl-copy', "sh", id]);
    }
    onDeleteRequested: line => {
        const id = idOf(line);
        if (id !== "") Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "sh", id]);
        entries = entries.filter(l => l !== line);
    }

    Process {
        running: true
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                history.entries = text.split("\n").filter(l => l.includes("\t"));
                const images = history.entries.map(l => history.imageOf(l)).filter(i => i);
                decoder.command = ["sh", "-c", decoder.script, "sh", history.thumbs].concat(images.map(i => i.id + ":" + i.file));
                decoder.running = true;
            }
        }
    }
    // Decodes the images not yet in `thumbs` (each through cliphist on standard input, the name built only from the
    // entry's digits, size and format) and prints each name once its file is there.
    Process {
        id: decoder
        readonly property string script: [
            'dir=$1; shift',
            'mkdir -p "$dir" && chmod 700 "$dir" || exit 1',
            'keep=" "; for a in "$@"; do keep="$keep${a#*:} "; done',
            'for f in "$dir"/* "$dir"/.[!.]*; do',
            '    [ -e "$f" ] || continue',
            '    case "$keep" in *" ${f##*/} "*) ;; *) rm -f -- "$f" ;; esac',
            'done',
            'for a in "$@"; do',
            '    id=${a%%:*}; f=${a#*:}',
            '    if [ ! -s "$dir/$f" ]; then',
            '        printf "%s\\t\\n" "$id" | cliphist decode > "$dir/.$f" && mv -f -- "$dir/.$f" "$dir/$f" || { rm -f -- "$dir/.$f"; continue; }',
            '    fi',
            '    printf "%s\\n" "$f"',
            'done'
        ].join("\n")
        stdout: SplitParser {
            onRead: line => { const r = Object.assign({}, history.ready); r[line] = true; history.ready = r; }
        }
    }

    row: Item {
        id: r
        readonly property var entry: parent ? parent.entry : null
        readonly property var img: entry ? history.imageOf(entry) : null
        readonly property real k: img ? Math.min(1, Theme.size.clipThumbW / img.w, Theme.size.clipThumbH / img.h) : 1
        Txt {
            visible: !r.img
            anchors.fill: parent
            text: (r.entry ?? "").split("\t").slice(1).join(" ").replace(/\s+/g, " ")
        }
        Item {
            id: thumb
            visible: !!r.img
            anchors.verticalCenter: parent.verticalCenter
            width: r.img ? Math.max(1, Math.round(r.img.w * r.k)) : 0
            height: r.img ? Math.max(1, Math.round(r.img.h * r.k)) : 0
            Image {
                anchors.fill: parent
                source: r.img && history.ready[r.img.file] ? "file://" + history.thumbs + "/" + r.img.file : ""
                sourceSize: Qt.size(thumb.width, thumb.height)
                asynchronous: true
                smooth: true
            }
            Rectangle {
                anchors { fill: parent; margins: -Theme.size.rule }
                color: "transparent"
                border.width: Theme.size.rule
                border.color: Theme.colors.line
            }
        }
        Annot {
            visible: !!r.img
            anchors { left: thumb.right; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            text: r.img ? r.img.w + " × " + r.img.h + " · " + r.img.format + " · " + r.img.size : ""
        }
    }
}
