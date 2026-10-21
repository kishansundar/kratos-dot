import QtQuick
import qs
import qs.components
import qs.services

// Storage (design/dashboard v2 Meter): a 32 px header row ("mount · used", "%"), then two 32 px rows per filesystem,
// at most `max` of them (the lower band's three lists end on one line; more drives are counted in the heading):
//   /boot 56.5 of 1022 MiB                                 6 %     the mount (body), used of total (mono), % (label 600)
//   ├▌──────────────────────────────────────────┼──────           the ruler, its baseline the row's rule; warn at 85 %
// Over warn: an ink triangle on the value tick and "near full"; over crit: fill, tick and % in the error colour, the
// error glyph and "full".
Column {
    id: list
    property var disks: []
    property int max: 4
    readonly property var shown: disks.slice(0, max)

    Item {
        width: list.width
        height: Theme.dash.listRow
        Txt { anchors.verticalCenter: parent.verticalCenter; variant: Theme.font.label; text: "mount · used"; color: Theme.colors.textMuted }
        Txt { anchors { right: parent.right; verticalCenter: parent.verticalCenter } variant: Theme.font.label; text: "%"; color: Theme.colors.textMuted }
        Rectangle { y: parent.height - height; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
    }
    Repeater {
        model: list.shown
        Column {
            id: disk
            required property var modelData
            readonly property real f: modelData.size > 0 ? modelData.used / modelData.size : 0
            readonly property bool crit: f * 100 >= Theme.threshold.diskCrit
            readonly property bool warn: f * 100 >= Theme.threshold.diskWarn && !crit
            readonly property var used: Metrics.bytes(modelData.used)
            readonly property var size: Metrics.bytes(modelData.size)
            width: list.width

            // The mount, how much is used, the share.
            Item {
                width: list.width
                height: Theme.dash.listRow
                Row {
                    anchors { left: parent.left; right: share.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s1
                    Txt { id: mount; text: disk.modelData.name }
                    Annot {
                        anchors.baseline: mount.baseline
                        width: Math.min(implicitWidth, parent.width - mount.implicitWidth - Theme.space.s1)
                        text: (disk.used[1] === disk.size[1] ? disk.used[0] : disk.used.join(" ")) + " of " + disk.size.join(" ")
                              + (disk.crit ? " · full" : disk.warn ? " · near full" : "")
                        color: disk.crit ? Theme.colors.error : disk.warn ? Theme.colors.text : Theme.colors.textMuted
                    }
                }
                Row {
                    id: share
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s1
                    Icon { visible: disk.crit; anchors.verticalCenter: pct.verticalCenter; name: Theme.icons.error; color: Theme.colors.error }
                    Txt {
                        id: pct
                        variant: Theme.font.labelStrong
                        text: Math.round(disk.f * 100) + " %"
                        color: disk.crit ? Theme.colors.error : Theme.colors.text
                    }
                }
            }
            // The ruler, standing on the row's bottom edge.
            Item {
                id: meter
                width: list.width
                height: Theme.dash.listRow
                readonly property int base: height - Theme.size.rule
                readonly property color ink: disk.crit ? Theme.colors.error : Theme.colors.text
                function xOf(f) { return Math.round(Math.max(0, Math.min(1, f)) * (width - Theme.ruler.tickW)) }
                Rectangle { y: meter.base; width: meter.width; height: Theme.ruler.tickW; color: Theme.colors.tick }
                Rectangle { y: meter.base - height + 1; width: Theme.ruler.tickW; height: Theme.ruler.tickMajor; color: Theme.colors.tick }
                Rectangle {
                    x: meter.xOf(Theme.threshold.diskWarn / 100)
                    y: meter.base - height + 1
                    width: Theme.ruler.tickW
                    height: Theme.ruler.tickMajor
                    color: Theme.colors.textMuted
                }
                Rectangle { y: meter.base - 1; width: meter.xOf(disk.f); height: Theme.ruler.fill; color: meter.ink }
                Rectangle {
                    x: meter.xOf(disk.f)
                    y: meter.base + 1 - height
                    width: Theme.size.marker
                    height: disk.warn ? Theme.ruler.tickValue - Theme.size.markTriangle : Theme.ruler.tickValue
                    color: meter.ink
                }
                Mark {
                    visible: disk.warn
                    kind: "triangle"
                    x: meter.xOf(disk.f) + Theme.size.marker / 2 - width / 2
                    y: meter.base + 1 - Theme.ruler.tickValue
                }
            }
        }
    }
}
