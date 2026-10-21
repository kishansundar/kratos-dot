import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// One vital of the instrument sheet (design/dashboard v2 Vitals): a 40 px row whose four cells are the panel's four
// columns, on a 1 px rule that runs the full width.
//   cpu                 14 %   ├───▌┼────┼────┤      ~~~~~~~~~~~~~~~~~~~~~~·      i7-8700K · 2.8 GHz
//   label (body), value (20/24 600, tabular) and unit · the ruler · the last ten minutes · metadata (mono)
// The ruler: a 1 px tick baseline, 4 px ticks every division (8 px every `majorEvery`), a 3 px ink fill and a 2 x 16 px
// ink value tick; the warn and critical limits as 8 px muted ticks. Warn: an ink triangle on the value tick and the
// metadata in ink, led by `word`. Critical: the value, fill and tick in the error colour, the error glyph, "critical".
// `bars` (the threads row): an ink bar per thread in the ruler's cell, as tall as its load (16 px at 100 %), no
// sparkline. `table`: the ruler, sparkline and metadata cells give min, max and mean instead.
// Both change every second: the bars are one per thread by index and read their load by it, the table's cells are keyed
// by name (ScriptModel), so a new sample changes them in place instead of rebuilding them (a tooltip stays up).
Item {
    id: row
    property string label: ""
    property string value: "–"
    property string unit: ""
    property real level: -1                // 0-1 on the ruler; < 0: none
    property real warnAt: -1               // 0-1 places of the limits on the ruler; < 0: none
    property real critAt: -1
    property bool warn: false
    property bool crit: false
    property string word: ""               // what warn means here ("hot", "near full")
    property int divisions: 10
    property int majorEvery: 5
    property string sparkKey: ""           // the history column; "" for none
    property string meta: ""
    property var bars: []                  // the threads row: % per thread
    property bool table: false
    property var stats: null               // {min, max, mean} for the table
    property var format: v => String(Math.round(v))     // a value of the table, with its unit

    readonly property int step: Theme.dash.col + Theme.dash.gutter
    readonly property int base: Math.round(height / 2) + Theme.space.s2          // the ruler's baseline
    readonly property color ink: crit ? Theme.colors.error : Theme.colors.text

    width: parent ? parent.width : 1104
    height: Theme.dash.vitalRowH

    // ---- 1. The label, and the value right-aligned to the column's edge -----------------------------------------------
    Txt {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: Theme.dash.col / 2
        text: row.label
    }
    Row {
        id: valueRow
        x: Theme.dash.col - width
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.s1
        Icon {
            visible: row.crit
            anchors.verticalCenter: number.verticalCenter
            name: Theme.icons.error
            color: Theme.colors.error
        }
        Txt {
            id: number
            variant: row.bars.length > 0 ? Theme.font.label : Theme.font.h2
            text: row.value
            color: row.bars.length > 0 ? Theme.colors.textMuted : row.ink
        }
        Txt {
            visible: row.unit !== ""
            anchors.baseline: number.baseline
            variant: Theme.font.label
            text: row.unit
            color: Theme.colors.textMuted
        }
    }

    // ---- 2. The ruler (or the threads' bars) -----------------------------------------------------------------------
    Item {
        id: gauge
        visible: !row.table
        x: row.step
        width: Theme.dash.col
        height: row.height
        readonly property bool hasBars: row.bars.length > 0
        function xOf(f) { return Math.round(Math.max(0, Math.min(1, f)) * (width - Theme.ruler.tickW)) }
        readonly property real slot: width / row.bars.length            // a thread's share of the cell

        Rectangle { y: row.base; width: parent.width; height: Theme.ruler.tickW; color: Theme.colors.tick }
        Repeater {
            model: gauge.hasBars ? 0 : row.divisions + 1
            Rectangle {
                required property int index
                x: gauge.xOf(index / row.divisions)
                y: row.base - height
                width: Theme.ruler.tickW
                height: index % row.majorEvery === 0 ? Theme.ruler.tickMajor : Theme.ruler.tickMinor
                color: Theme.colors.tick
            }
        }
        Repeater {
            model: gauge.hasBars ? [] : [row.warnAt, row.critAt].filter(f => f >= 0)
            Rectangle {
                required property real modelData
                x: gauge.xOf(modelData)
                y: row.base - height
                width: Theme.ruler.tickW
                height: Theme.ruler.tickMajor
                color: Theme.colors.textMuted
            }
        }
        Rectangle {
            visible: !gauge.hasBars && row.level >= 0
            y: row.base - 1
            width: gauge.xOf(row.level)
            height: Theme.ruler.fill
            color: row.ink
        }
        Rectangle {
            visible: !gauge.hasBars && row.level >= 0
            x: gauge.xOf(row.level)
            y: row.base + 2 - height
            width: Theme.size.marker
            height: row.warn && !row.crit ? Theme.ruler.tickValue - Theme.size.markTriangle : Theme.ruler.tickValue
            color: row.ink
        }
        Mark {
            visible: !gauge.hasBars && row.level >= 0 && row.warn && !row.crit
            kind: "triangle"
            x: gauge.xOf(row.level) + Theme.size.marker / 2 - width / 2
            y: row.base + 2 - Theme.ruler.tickValue
        }
        // The threads: a bar each, side by side across the cell, standing on the baseline.
        Repeater {
            model: row.bars.length
            Rectangle {
                id: bar
                required property int index
                readonly property real load: row.bars[index] ?? 0
                readonly property real slot: gauge.slot
                x: Math.round(index * slot)
                y: row.base - height
                width: Math.round(slot) - Theme.size.marker
                height: Math.max(Theme.ruler.tickW, Math.round(Math.max(0, Math.min(100, load)) / 100 * Theme.ruler.tickValue))
                color: Theme.colors.text
                MouseArea {
                    x: 0; y: -(Theme.ruler.tickValue - bar.height)
                    width: bar.width; height: Theme.ruler.tickValue
                    hoverEnabled: true
                    onContainsMouseChanged: containsMouse ? Tip.show(bar, bar.width / 2, bar.height, "thread " + bar.index + " · " + Math.round(bar.load) + " %")
                                                          : Tip.hide(bar)
                }
            }
        }
    }

    // ---- 3. The last ten minutes -------------------------------------------------------------------------------------
    Sparkline {
        visible: !row.table && row.sparkKey !== ""
        x: 2 * row.step
        y: Math.round((row.height - height) / 2)
        width: Theme.dash.col
        key: row.sparkKey
        tick: Metrics.historyTick
    }

    // ---- 4. Metadata ---------------------------------------------------------------------------------------------------
    Row {
        visible: !row.table
        x: 3 * row.step
        width: Theme.dash.col
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.s1
        Mark { visible: row.warn && !row.crit; anchors.verticalCenter: parent.verticalCenter; kind: "triangle" }
        Annot {
            width: parent.width - (row.warn && !row.crit ? Theme.size.markTriangle + Theme.space.s1 : 0)
            text: [row.crit ? "critical" : row.warn ? row.word : "", row.meta].filter(s => s !== "").join(" · ")
            color: row.crit ? Theme.colors.error : row.warn ? Theme.colors.text : Theme.colors.textMuted
        }
    }

    // ---- The table: min, max and mean over the ten minutes ------------------------------------------------------------
    Repeater {
        model: ScriptModel { values: row.table && row.stats ? ["min", "max", "mean"] : [] }
        Annot {
            required property int index
            required property var modelData        // "min", "max" or "mean"
            readonly property real v: row.stats ? row.stats[modelData] : -1
            x: (index + 1) * row.step
            width: Theme.dash.col
            anchors.verticalCenter: parent.verticalCenter
            text: modelData + " " + (v >= 0 ? row.format(v) : "–")
            color: Theme.colors.text
        }
    }

    Rectangle { y: row.height - height; width: row.width; height: Theme.size.rule; color: Theme.colors.line }
}
