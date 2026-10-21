import QtQuick
import qs

// A search field over an indexed list: the clipboard history (the launcher has its own list).
//   the field     the search glyph and the query in h2; the count on the right in mono ("12 apps")
//   the list      rows of 32 px; the row Enter runs has the selected fill; rows are numbered 1-9 (mono, faint):
//                 Alt+number runs that row
// Keys: Up/Down or Ctrl+K/J move, Page Up/Down by a page, Enter runs, Alt+1-9 runs row n, Delete removes (if offered).
// The caller gives `results` and a `row` component; the row reads `entry`, `selected` and `query` from its parent.
// `rowHeightOf` (entry => px, a multiple of 32) makes some rows taller (the clipboard's images); the list stays at most
// visibleRows x 32 px, and the numbers 1-9 go to the rows wholly in view.
Column {
    id: list

    property string placeholder: ""
    property string emptyText: "Nothing here"
    property string countLabel: ""            // "apps": shown as the metadata "42 apps"
    property var results: []
    property Component row
    property var rowHeightOf: null
    property int visibleRows: 9
    property string hints: "enter open · alt+1-9 open row · esc close"
    property alias query: input.text
    readonly property var current: results[view.currentIndex]

    signal accepted(var item)
    signal deleteRequested(var item)

    width: Theme.size.launcherWidth
    spacing: 0

    // The text field holds the keyboard. (If this Column also asked for focus, it would win and typing would go
    // nowhere.) The list is made afresh each time it opens, so this runs on every open.
    Component.onCompleted: input.forceActiveFocus()

    function heightOf(entry) { return rowHeightOf ? rowHeightOf(entry) : Theme.size.hitTarget }
    function moveBy(by) {
        if (results.length > 0) {
            view.currentIndex = Math.max(0, Math.min(results.length - 1, view.currentIndex + by));
            Qt.callLater(reveal);
        }
    }
    // After a key move: the chosen row in view with a whole row at the top (rows of unequal height scrolled into view
    // by the ListView itself stop wherever the chosen row's edge is, cutting the top row).
    function reveal() {
        const i = view.currentIndex;
        if (i < 0 || i >= results.length) return;
        let top = 0;
        for (let k = 0; k < i; k++) top += heightOf(results[k]);
        const bottom = top + heightOf(results[i]);
        if (top <= view.contentY) { view.contentY = top; return; }
        let y = 0;
        for (let k = 0; bottom - y > view.height; k++) y += heightOf(results[k]);
        if (y > view.contentY || view.contentY + view.height < bottom) view.contentY = y;
    }
    // Row n as numbered on screen (counted from the first row wholly in view).
    function rowAt(n) {
        const i = view.firstShown + n - 1;
        return view.wholly(view.itemAtIndex(i)) ? results[i] : undefined;
    }

    // ---- The field --------------------------------------------------------------------------------
    Item {
        width: parent.width
        height: 40

        Icon {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            name: Theme.icons.search
            color: Theme.colors.textMuted
        }
        TextInput {
            id: input
            anchors { left: glyph.right; leftMargin: Theme.space.s3; right: count.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            font.family: Theme.font.h2.family
            font.pixelSize: Theme.font.h2.size
            font.weight: Theme.font.h2.weight
            font.letterSpacing: Theme.font.h2.spacing
            color: Theme.colors.text
            selectionColor: Theme.colors.selection
            selectedTextColor: Theme.colors.text
            renderType: Text.NativeRendering
            clip: true
            focus: true
            onTextChanged: view.currentIndex = 0

            Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                const alt = event.modifiers & Qt.AltModifier;
                if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) { const r = list.rowAt(event.key - Qt.Key_0); if (r !== undefined) list.accepted(r); }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (list.current !== undefined) list.accepted(list.current); }
                else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) list.moveBy(1);
                else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) list.moveBy(-1);
                else if (event.key === Qt.Key_PageDown) list.moveBy(list.visibleRows);
                else if (event.key === Qt.Key_PageUp) list.moveBy(-list.visibleRows);
                else if (event.key === Qt.Key_Delete && list.current !== undefined) list.deleteRequested(list.current);
                else return;
                event.accepted = true;
            }
            Txt {
                anchors.fill: parent
                visible: input.text.length === 0
                variant: Theme.font.h2
                font.weight: Font.Normal
                text: list.placeholder
                color: Theme.colors.textFaint
            }
        }
        Annot {
            id: count
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: list.countLabel !== ""
            text: list.results.length + " " + list.countLabel
        }
    }

    // ---- The list ----------------------------------------------------------------------------------
    Item { width: 1; height: Theme.space.s2 }
    Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
    Item { width: 1; height: Theme.space.s2 }
    ListView {
        id: view
        width: parent.width
        // The rows from the top that fit wholly in visibleRows x 32 px (at least one row's room, for "No matches").
        height: {
            const most = list.visibleRows * Theme.size.hitTarget;
            let h = 0;
            for (const e of list.results) { const r = list.heightOf(e); if (h + r > most) break; h += r; }
            return Math.max(Theme.size.hitTarget, h);
        }
        clip: true
        model: list.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: 0
        // The first row wholly in view, and whether a row is.
        function wholly(item) { return !!item && item.y >= contentY - 1 && item.y + item.height <= contentY + height + 1 }
        readonly property int firstShown: {
            const i = indexAt(1, contentY + 1);
            if (i < 0) return 0;
            return itemAtIndex(i) && itemAtIndex(i).y < contentY - 1 ? i + 1 : i;
        }

        delegate: RowItem {
            id: rowItem
            required property var modelData
            required property int index
            readonly property int number: view.wholly(rowItem) ? index - view.firstShown + 1 : 0
            width: view.width
            height: list.heightOf(modelData)
            selected: ListView.isCurrentItem
            onHoveredIn: view.currentIndex = index
            onActivated: list.accepted(modelData)

            Annot {
                id: numberLabel
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 16
                text: rowItem.number >= 1 && rowItem.number <= 9 ? rowItem.number : ""
                color: Theme.colors.textFaint
            }
            Loader {
                anchors { left: numberLabel.right; leftMargin: Theme.space.s2; right: parent.right; top: parent.top; bottom: parent.bottom }
                sourceComponent: list.row
                property var entry: rowItem.modelData
                property bool selected: rowItem.selected
                property string query: list.query
            }
        }

        Txt {
            anchors.fill: parent
            leftPadding: Theme.space.s3
            visible: list.results.length === 0
            text: list.query.length > 0 ? "No matches" : list.emptyText
            color: Theme.colors.textMuted
        }
    }

    // Key hints, in mono.
    Item { width: 1; height: Theme.space.s2 }
    Annot {
        width: parent.width
        text: list.hints
        color: Theme.colors.textFaint
    }
}
