import QtQuick
import Quickshell
import qs
import qs.components
import qs.services
import qs.dashboard
import "../services/Format.js" as Format

// The dashboard, version 2 (design/dashboard: the instrument sheet). One 1152 px panel centred on the screen (PanelHost),
// floating; Super+D, a right click on the NixOS mark, or `qs ipc call dash toggle`; Esc or a click outside closes.
//   ❄                                            kratos · NixOS 26.11 · up 21h 22m · t tables · esc close
//   COMPUTE ──────────────────────────────────────────────────────────────────────── % · last 10 min
//   cpu            14 %   ├──▌┼────┼────┤   ~~~~~~~~~~~~~~~~~~~·   i7-8700K · 2.8 GHz
//   threads          12   ▁▂▄▁▁▃▂▁▂▃▁▂                              busiest t2 · 91 %
//   gpu            44 %   ...                                        GTX 1070 · 0.8 GHz
//   MEMORY (memory, vram) · HEAT (cpu package, gpu: 20-100 °C) · NETWORK (down, up: full scale the 10-minute peak)
//   PROCESSES (two columns) ............... STORAGE ................ CONTROLS
// Every vital is one 40 px row on the same four 258 px columns (label and value · ruler · sparkline · metadata), so any
// two compare at a glance; the lower band's three lists are a header and 8 rows of 32 px and end on one line. Ink only:
// the error colour for something critical, and the two-tone mark. The header is the mark alone (the owner's choice:
// the host name is in the metadata). The cheap vitals are sampled in the background (Metrics), so the sparklines are
// full when it opens; the GPU, the processes and the drives only while it is open (dashboard/Dashboard.qml).
// Keys: t turns the sheet into min / max / mean, Page Up / Page Down scroll (on a short screen), Tab goes through the
// controls.
FocusScope {
    id: dash
    readonly property var scr: Panels.screen
    width: Theme.dash.width - 2 * Theme.dash.margin
    // On a short screen: 48 px (s7) from the edges, and it scrolls inside.
    height: Math.min(sheet.implicitHeight, (scr ? scr.height : 1440) - Theme.bar.height - 2 * Theme.space.s7 - 2 * Theme.dash.margin)
    focus: true
    readonly property int cardPadding: Theme.dash.margin

    property bool tables: false
    // Below 1200 px the lower band stacks: Processes, then Storage and Controls side by side.
    readonly property bool narrow: (scr ? scr.width : 2560) < 1200
    function cols(n) { return n * Theme.dash.col + (n - 1) * Theme.dash.gutter }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_T && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) dash.tables = !dash.tables;
        else if (event.key === Qt.Key_PageDown) flick.contentY = Math.min(flick.contentHeight - flick.height, flick.contentY + flick.height * 0.8);
        else if (event.key === Qt.Key_PageUp) flick.contentY = Math.max(0, flick.contentY - flick.height * 0.8);
        else return;
        event.accepted = true;
    }

    // Formats for the rows.
    function share(a, b) { return b > 0 ? Math.round(a / b * 100) : 0 }
    readonly property var down: Metrics.stats("down", Metrics.historyTick)
    readonly property var up: Metrics.stats("up", Metrics.historyTick)
    readonly property int busiest: Metrics.threads.reduce((best, v, i, a) => v > a[best] ? i : best, 0)

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: sheet.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        onContentYChanged: Tip.hide()

        Column {
            id: sheet
            width: dash.width

            // ---- The masthead: the NixOS mark; the host, the system and the keys at the right ----------------------
            Item {
                width: parent.width
                height: Theme.size.hitTarget
                NixMark { id: mark; anchors.verticalCenter: parent.verticalCenter; size: 2 * Theme.size.icon }   // as the bar's, 32 px
                Annot {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: [Metrics.host, Metrics.os, Metrics.uptime > 0 ? "up " + Format.span(Metrics.uptime) : "",
                           "t tables", "esc close"].filter(s => s !== "").join(" · ")
                }
            }
            Item { width: 1; height: Theme.space.s4 }

            // ---- The headline: cpu, gpu, memory and heat at the posters' scale (dashboard/Headline) --------------
            Headline {}
            Item { width: 1; height: Theme.space.s5 }

            // ---- The vitals ---------------------------------------------------------------------------------------
            Column {
                width: parent.width
                spacing: Theme.space.s4

                Section {
                    width: parent.width
                    title: "Compute"
                    meta: "% · last 10 min"
                    VitalRow {
                        label: "cpu"
                        value: Format.pct(Metrics.cpu)
                        unit: "%"
                        level: Metrics.cpu < 0 ? -1 : Metrics.cpu / 100
                        sparkKey: "cpu"
                        meta: [Metrics.cpuModel, Metrics.ghz > 0 ? Metrics.ghz.toFixed(1) + " GHz" : ""].filter(s => s !== "").join(" · ")
                        table: dash.tables
                        stats: dash.tables ? Metrics.stats("cpu", Metrics.historyTick) : null
                        format: v => Math.round(v) + " %"
                    }
                    VitalRow {
                        label: "threads"
                        value: String(Metrics.threads.length)
                        bars: Metrics.threads
                        meta: Metrics.threads.length > 0 ? "busiest t" + dash.busiest + " · " + Math.round(Metrics.threads[dash.busiest]) + " %" : ""
                        table: dash.tables
                        stats: {
                            const t = Metrics.threads;
                            return t.length > 0 ? { min: Math.min(...t), max: Math.max(...t), mean: t.reduce((a, b) => a + b, 0) / t.length } : null;
                        }
                        format: v => Math.round(v) + " %"
                    }
                    VitalRow {
                        label: "gpu"
                        value: Format.pct(Metrics.gpu)
                        unit: "%"
                        level: Metrics.gpu < 0 ? -1 : Metrics.gpu / 100
                        sparkKey: "gpu"
                        meta: !Metrics.hasGpu ? "no nvidia-smi"
                            : [Metrics.gpuName, Metrics.gpuGhz > 0 ? Metrics.gpuGhz.toFixed(1) + " GHz" : ""].filter(s => s !== "").join(" · ")
                        table: dash.tables
                        stats: dash.tables ? Metrics.stats("gpu", Metrics.historyTick) : null
                        format: v => Math.round(v) + " %"
                    }
                }

                Section {
                    width: parent.width
                    title: "Memory"
                    meta: "used of total"
                    VitalRow {
                        readonly property int p: dash.share(Metrics.memUsed, Metrics.memTotal)
                        label: "memory"
                        value: Metrics.memTotal > 0 ? Metrics.bytes(Metrics.memUsed)[0] : "–"
                        unit: Metrics.memTotal > 0 ? Metrics.bytes(Metrics.memUsed)[1] : ""
                        level: Metrics.memTotal > 0 ? Metrics.memUsed / Metrics.memTotal : -1
                        warnAt: Theme.threshold.memWarn / 100
                        warn: p >= Theme.threshold.memWarn
                        word: "near full"
                        sparkKey: "mem"
                        meta: Metrics.memTotal > 0 ? "of " + Metrics.bytes(Metrics.memTotal).join(" ") + " · " + p + " %" : ""
                        table: dash.tables
                        stats: dash.tables ? Metrics.stats("mem", Metrics.historyTick) : null
                        format: v => Metrics.bytes(v).join(" ")
                    }
                    VitalRow {
                        readonly property int p: dash.share(Metrics.vramUsed, Metrics.vramTotal)
                        label: "vram"
                        value: Metrics.vramTotal > 0 && Metrics.gpu >= 0 ? Metrics.bytes(Metrics.vramUsed)[0] : "–"
                        unit: Metrics.vramTotal > 0 && Metrics.gpu >= 0 ? Metrics.bytes(Metrics.vramUsed)[1] : ""
                        level: Metrics.vramTotal > 0 && Metrics.gpu >= 0 ? Metrics.vramUsed / Metrics.vramTotal : -1
                        warnAt: Theme.threshold.memWarn / 100
                        warn: p >= Theme.threshold.memWarn
                        word: "near full"
                        sparkKey: "vram"
                        meta: Metrics.vramTotal > 0 ? "of " + Metrics.bytes(Metrics.vramTotal).join(" ") + " · " + p + " %" : ""
                        table: dash.tables
                        stats: dash.tables ? Metrics.stats("vram", Metrics.historyTick) : null
                        format: v => Metrics.bytes(v).join(" ")
                    }
                }

                Section {
                    width: parent.width
                    title: "Heat"
                    meta: "20–100 °C · warn " + Theme.threshold.cpuTempWarn + " · critical " + Theme.threshold.cpuTempCrit
                    VitalRow {
                        readonly property real t: Metrics.cpuTemp
                        label: "cpu package"
                        value: t < 0 ? "–" : String(Math.round(t))
                        unit: "°C"
                        level: t < 0 ? -1 : (t - 20) / 80
                        divisions: 8
                        majorEvery: 2
                        warnAt: (Theme.threshold.cpuTempWarn - 20) / 80
                        critAt: (Theme.threshold.cpuTempCrit - 20) / 80
                        warn: t >= Theme.threshold.cpuTempWarn && t < Theme.threshold.cpuTempCrit
                        crit: t >= Theme.threshold.cpuTempCrit
                        word: "hot"
                        sparkKey: "cpuTemp"
                        meta: [Metrics.fan >= 0 ? "fan " + Math.round(Metrics.fan) + " rpm" : "",
                               Metrics.pump >= 0 ? "pump " + Math.round(Metrics.pump) : ""].filter(s => s !== "").join(" · ")
                        table: dash.tables
                        stats: dash.tables ? Metrics.stats("cpuTemp", Metrics.historyTick) : null
                        format: v => Math.round(v) + " °C"
                    }
                    VitalRow {
                        readonly property real t: Metrics.gpuTemp
                        visible: Metrics.hasGpu
                        label: "gpu"
                        value: t < 0 ? "–" : String(Math.round(t))
                        unit: "°C"
                        level: t < 0 ? -1 : (t - 20) / 80
                        divisions: 8
                        majorEvery: 2
                        warnAt: (Theme.threshold.gpuTempWarn - 20) / 80
                        critAt: (Theme.threshold.gpuTempCrit - 20) / 80
                        warn: t >= Theme.threshold.gpuTempWarn && t < Theme.threshold.gpuTempCrit
                        crit: t >= Theme.threshold.gpuTempCrit
                        word: "hot"
                        sparkKey: "gpuTemp"
                        meta: Metrics.gpuFan >= 0 ? "fan " + Math.round(Metrics.gpuFan) + " %" : ""
                        table: dash.tables
                        stats: dash.tables ? Metrics.stats("gpuTemp", Metrics.historyTick) : null
                        format: v => Math.round(v) + " °C"
                    }
                }

                Section {
                    width: parent.width
                    title: "Network"
                    meta: [Metrics.iface, "full scale = 10-min peak"].filter(s => s !== "").join(" · ")
                    VitalRow {
                        label: "down"
                        value: Metrics.mbps(Metrics.down)
                        unit: "MB/s"
                        level: Metrics.down < 0 ? -1 : dash.down.max > 0 ? Metrics.down / dash.down.max : 0
                        sparkKey: "down"
                        meta: dash.down.max >= 0 ? "peak " + Metrics.mbps(dash.down.max) + " MB/s" : ""
                        table: dash.tables
                        stats: dash.down
                        format: v => Metrics.mbps(v) + " MB/s"
                    }
                    VitalRow {
                        label: "up"
                        value: Metrics.mbps(Metrics.up)
                        unit: "MB/s"
                        level: Metrics.up < 0 ? -1 : dash.up.max > 0 ? Metrics.up / dash.up.max : 0
                        sparkKey: "up"
                        meta: dash.up.max >= 0 ? "peak " + Metrics.mbps(dash.up.max) + " MB/s" : ""
                        table: dash.tables
                        stats: dash.up
                        format: v => Metrics.mbps(v) + " MB/s"
                    }
                }
            }

            Item { width: 1; height: Theme.dash.sectionGap }

            // ---- The lower band: Processes (two columns), Storage, Controls: three lists that end on one line ----------
            Flow {
                width: parent.width
                spacing: Theme.dash.gutter
                Section {
                    width: dash.narrow ? dash.width : dash.cols(2)
                    title: "Processes"
                    meta: "top 8 by " + ({ cpu: "cpu", rss: "memory", pid: "pid", name: "name" })[processTable.sortKey]
                    ProcessTable { id: processTable; width: parent.width; processes: Processes.list }
                }
                Section {
                    width: dash.narrow ? (dash.width - Theme.dash.gutter) / 2 : Theme.dash.col
                    title: "Storage"
                    meta: Metrics.disks.length + " filesystems" + (Metrics.disks.length > 4 ? " · +" + (Metrics.disks.length - 4) + " more" : "")
                    StorageList { width: parent.width; disks: Metrics.disks; max: 4 }
                }
                Section {
                    width: dash.narrow ? (dash.width - Theme.dash.gutter) / 2 : Theme.dash.col
                    title: "Controls"
                    meta: "4"
                    ControlList { width: parent.width }
                }
            }
        }
    }

    // ---- The one tooltip, over everything --------------------------------------------------------------
    TipBox {
        id: tip
        visible: Tip.shown
        readonly property int pad: Theme.space.s2
        padY: pad
        // As wide as its text, up to twice tipW.
        width: Math.min(2 * Theme.dash.tipW, tipText.implicitWidth + 2 * pad)
        height: tipColumn.implicitHeight + 2 * pad
        // Tip.at is in the window; this tip is drawn in the panel.
        readonly property point p: dash.mapFromItem(null, Tip.at.x, Tip.at.y)
        x: Math.round(Math.max(0, Math.min(dash.width - width, p.x - width / 2)))
        y: Math.round(p.y + Theme.space.s1)
        Column {
            id: tipColumn
            width: tip.width - 2 * tip.pad
            Txt {
                id: tipText
                visible: Tip.text !== ""
                width: tipColumn.width
                variant: Theme.font.label
                wrapMode: Text.Wrap
                maximumLineCount: 4
                text: Tip.text
            }
        }
    }
}
