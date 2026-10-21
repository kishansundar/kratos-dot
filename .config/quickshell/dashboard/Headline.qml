import QtQuick
import qs
import qs.components
import qs.services
import "../services/Format.js" as Format

// The headline band (the wallpaper posters' hierarchy, a huge figure over small text, on the sheet's own grid): the
// four figures looked for first, one per 258 px column, in Geist Bold at Theme.font.headline, each over its name and
// unit in mono. Ink; the error colour only for a critical heat, and "hot" beside the name for a warm one, as the rows
// below say it. The rows keep every detail; this band only leads.
//   16          1           42            81
//   cpu %       gpu %       memory % used cpu package °C
Row {
    id: band
    spacing: Theme.dash.gutter
    // The figures' baseline from the band's top, and the names' under it: from the spacing scale (80 and 104).
    readonly property int figureBase: Theme.space.s8 + Theme.space.s4
    readonly property int nameBase: figureBase + Theme.space.s5
    height: nameBase + Theme.space.s2

    component Figure: Item {
        property string value: "–"
        property string name: ""
        property bool crit: false
        width: Theme.dash.col
        height: band.height
        Txt {
            anchors { left: parent.left; baseline: parent.top; baselineOffset: band.figureBase }
            variant: Theme.font.headline
            color: parent.crit ? Theme.colors.error : Theme.colors.text
            text: parent.value
        }
        Txt {
            anchors { left: parent.left; baseline: parent.top; baselineOffset: band.nameBase }
            width: parent.width
            variant: Theme.font.mono
            color: Theme.colors.textMuted
            text: parent.name
        }
    }

    Figure { value: Format.pct(Metrics.cpu); name: "cpu %" }
    Figure { value: Metrics.hasGpu ? Format.pct(Metrics.gpu) : "–"; name: "gpu %" }
    Figure {
        value: Metrics.memTotal > 0 ? String(Math.round(Metrics.memUsed / Metrics.memTotal * 100)) : "–"
        name: "memory % used" + (Metrics.memTotal > 0 && Metrics.memUsed / Metrics.memTotal * 100 >= Theme.threshold.memWarn ? " · near full" : "")
    }
    Figure {
        readonly property real t: Metrics.cpuTemp
        value: t < 0 ? "–" : String(Math.round(t))
        crit: t >= Theme.threshold.cpuTempCrit
        name: "cpu package °C" + (t >= Theme.threshold.cpuTempCrit ? " · critical" : t >= Theme.threshold.cpuTempWarn ? " · hot" : "")
    }
}
