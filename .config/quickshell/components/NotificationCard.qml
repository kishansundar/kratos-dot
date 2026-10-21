import QtQuick
import qs
import qs.services

// One notification as a toast (overlays/Toasts; the notification centre's rows are components/NotifItem):
//   HELIUM                                        20:28     app name in caps; the time, faint, tabular, on the right
//   Download complete                                       summary, body semibold
//   swiss-desktop-spec.pdf was saved to Downloads           body, muted, up to four lines
//   ━━━━━━━━━━━━━━━━━━━──────────────────────  64 %          a progress the sender reports ("value" hint), if any
//   Open   Show in folder                                   actions, text buttons
// Critical: a 2 px accent bar on the left and the error glyph before the summary (never colour alone); it stays
// until dismissed. A click brings the sender's window (Notifs.goToSender), runs the default action (if any) and
// dismisses; × (shown on hover, where the time is) or a right click dismisses.
Rectangle {
    id: card
    required property var notification
    readonly property bool critical: Notifs.isCritical(notification)
    readonly property bool hovered: hover.hovered

    width: parent ? parent.width : Theme.size.popupWidth
    height: column.implicitHeight + 2 * Theme.space.s4
    color: Theme.colors.surface
    border.width: Theme.size.rule
    border.color: Theme.colors.line

    readonly property string received: Qt.formatTime(new Date(Notifs.received[notification.id] ?? Date.now()), "HH:mm")

    HoverHandler { id: hover }

    Rectangle {
        visible: card.critical
        width: Theme.size.marker
        height: parent.height
        color: Theme.colors.accent
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => {
            const r = Notifs.recordOf(card.notification);
            if (event.button === Qt.LeftButton) Notifs.invoke(r);
            else Notifs.dismiss(r);
        }
    }

    Column {
        id: column
        x: Theme.space.s5
        y: Theme.space.s4
        width: parent.width - 2 * Theme.space.s5
        spacing: 0

        Item {
            width: parent.width
            height: Theme.font.caps.lineHeight
            Caps {
                anchors { left: parent.left; right: time.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: card.notification.appName || "Notification"
            }
            Txt {
                id: time
                visible: !card.hovered
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                variant: Theme.font.label
                text: card.received
                color: Theme.colors.textFaint
            }
            GlyphButton {
                visible: card.hovered
                anchors { right: parent.right; rightMargin: -Theme.space.s2; verticalCenter: parent.verticalCenter }
                name: Theme.icons.close
                color: Theme.colors.textMuted
                onClicked: card.notification.dismiss()
            }
        }
        Item { width: 1; height: Theme.space.s1 }
        Row {
            width: parent.width
            spacing: Theme.space.s2
            Icon {
                visible: card.critical
                anchors.verticalCenter: parent.verticalCenter
                name: Theme.icons.error
                color: Theme.colors.error
            }
            Txt {
                width: parent.width - (card.critical ? Theme.size.icon + Theme.space.s2 : 0)
                text: card.notification.summary
                variant: Theme.font.bodyStrong
            }
        }
        Txt {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body
            color: Theme.colors.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: 4
            lineHeightMode: Text.FixedHeight
            lineHeight: Theme.font.body.lineHeight
        }
        NotifExtras {
            progress: Notifs.progress(card.notification)
            actions: card.notification.actions.filter(a => a.identifier !== "default")
            onActed: action => action.invoke()
        }
    }
}
