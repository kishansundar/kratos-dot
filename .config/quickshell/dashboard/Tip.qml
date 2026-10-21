pragma Singleton
import QtQuick
import Quickshell

// The dashboard's one tooltip, drawn by panels/DashboardPanel above every section (a tip inside a section would hide
// under the next one). A part shows it under a point of its own, in window coordinates, with a text; the part that
// asked last owns it.
Singleton {
    id: root
    property var owner: null
    property string text: ""
    property point at: Qt.point(0, 0)      // the point it hangs from, window coordinates
    readonly property bool shown: owner !== null

    function show(item, x, y, text) {
        const p = item.mapToItem(null, x, y);
        root.at = Qt.point(p.x, p.y);
        root.text = text ?? "";
        root.owner = item;
    }
    function hide(item) { if (!item || item === owner) owner = null }
}
