import QtQuick
import qs
import qs.services

// One notification in the notification centre (design/panels NotificationsPanel "Item"); toasts use NotificationCard.
//   Backup failed                          14:02  ×     summary body 600; the time mono textFaint; dismiss
//   restic: repository locked by another                body textMuted, notifBodyLines lines, then an ellipsis;
//   process. Run restic unlock if no oth…               a click on a cut body shows all of it
//   ━━━━━━━━━━━━━━━━━━━──────────────────  64 %        a progress the sender reports ("value" hint), while live
//   open log                                            the sender's actions as text buttons
// A 1 px line rule above each item (no cards). Critical: a 2 px accent bar on the left edge AND the error glyph before
// the summary. An image, when the sender gave one, square-cropped at notifImage left of the text. A click brings
// the sender's window, runs the default action and dismisses (Notifs.invoke); a middle click dismisses. `record` is a Notifs record (a live notification may stand
// behind it, or none after a restart: then there are no actions).
Item {
    id: item
    required property var record
    readonly property var live: Notifs.live(record)
    readonly property bool critical: record.urgency === 2
    readonly property var actions: live ? live.actions.filter(a => a.identifier !== "default") : []
    property bool expanded: false

    readonly property int pad: Theme.space.s3
    width: parent ? parent.width : 0
    height: content.implicitHeight + 2 * pad + Theme.size.rule

    function when(t) {
        const d = new Date(t), now = new Date();
        const day = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (t >= day) return Qt.formatTime(d, "HH:mm");
        if (t >= day - 86400000) return "yesterday " + Qt.formatTime(d, "HH:mm");
        return Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy") + " " + Qt.formatTime(d, "HH:mm");
    }

    Rectangle {
        width: parent.width
        height: Theme.size.rule
        color: Theme.colors.line
    }
    Rectangle {
        visible: item.critical
        y: Theme.size.rule
        width: Theme.size.marker
        height: parent.height - Theme.size.rule
        color: Theme.colors.accent
    }
    // Under the content, so the actions and × take their own presses.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => mouse.button === Qt.MiddleButton ? Notifs.dismiss(item.record) : Notifs.invoke(item.record)
    }

    Image {
        id: image
        readonly property string url: item.live && item.live.image ? item.live.image : item.record.image
        visible: url !== "" && status === Image.Ready
        x: item.pad
        y: Theme.size.rule + item.pad
        width: Theme.panel.notifImage
        height: Theme.panel.notifImage
        source: url
        fillMode: Image.PreserveAspectCrop
        sourceSize { width: Theme.panel.notifImage; height: Theme.panel.notifImage }
        asynchronous: true
    }

    Column {
        id: content
        x: image.visible ? image.x + image.width + item.pad : item.pad
        y: Theme.size.rule + item.pad
        width: parent.width - x - item.pad

        // Summary, time, ×. The × reaches past the column into the padding, as a 32 px target.
        Item {
            width: parent.width
            height: Theme.font.body.lineHeight
            Icon {
                id: glyph
                visible: item.critical
                anchors.verticalCenter: parent.verticalCenter
                name: Theme.icons.error
                color: Theme.colors.error
            }
            Txt {
                anchors { left: glyph.visible ? glyph.right : parent.left; leftMargin: glyph.visible ? Theme.space.s2 : 0
                          right: time.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                text: item.record.summary || item.record.app || "Notification"
                variant: Theme.font.bodyStrong
            }
            Annot {
                id: time
                anchors { right: close.left; verticalCenter: parent.verticalCenter }
                text: item.when(item.record.time)
                color: Theme.colors.textFaint
            }
            GlyphButton {
                id: close
                anchors { right: parent.right; rightMargin: -Theme.space.s2; verticalCenter: parent.verticalCenter }
                name: Theme.icons.close
                color: Theme.colors.textMuted
                onClicked: Notifs.dismiss(item.record)
            }
        }
        Txt {
            id: body
            width: parent.width
            visible: text.length > 0
            text: item.record.body
            color: Theme.colors.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: item.expanded ? 100 : Theme.panel.notifBodyLines
            lineHeightMode: Text.FixedHeight
            lineHeight: Theme.font.body.lineHeight
            // At most the line limit: implicitHeight counts a line too many when the body wraps to exactly the limit.
            height: Math.min(implicitHeight, maximumLineCount * Theme.font.body.lineHeight)
            // A cut body opens on a click instead of acting.
            MouseArea {
                anchors.fill: parent
                enabled: body.truncated
                cursorShape: Qt.PointingHandCursor
                onClicked: item.expanded = true
            }
        }
        NotifExtras {
            progress: Notifs.progress(item.live)
            actions: item.actions
            onActed: action => Notifs.act(item.record, action)
        }
    }
}
