import QtQuick
import qs
import qs.services

// A vital's last ten minutes (design/dashboard v2): a 1 px faint line across the column, the current value as an ink
// dot. Time runs left to right over historyWindow, so a stretch without samples (the GPU while the dashboard was
// closed) is a gap. The line spans its own minimum to maximum (the ruler beside it gives the absolute value); at most
// 120 points are drawn, each the mean of its stretch of time.
Canvas {
    id: line
    property string key: ""                // the history column (Metrics.history)
    property int tick: 0                   // a new sample (Metrics.historyTick)
    readonly property color faint: Theme.colors.textFaint
    readonly property color ink: Theme.colors.text

    height: Theme.dash.vitalSparkH
    onTickChanged: requestPaint()
    onFaintChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const now = Date.now(), span = Theme.motion.historyWindow, buckets = 120, size = span / buckets;
        const sum = new Array(buckets).fill(0), count = new Array(buckets).fill(0);
        for (const s of Metrics.history) {
            const v = s[key];
            if (v === undefined || v < 0) continue;
            const b = Math.floor((s.t - (now - span)) / size);
            if (b < 0 || b >= buckets) continue;
            sum[b] += v; count[b]++;
        }
        const pts = [];
        for (let b = 0; b < buckets; b++) if (count[b] > 0) pts.push([b, sum[b] / count[b]]);
        if (pts.length === 0) return;
        let lo = Infinity, hi = -Infinity;
        for (const p of pts) { lo = Math.min(lo, p[1]); hi = Math.max(hi, p[1]); }
        if (hi - lo < 1e-9) { lo -= 1; hi += 1; }
        const r = Theme.dash.dotD / 4;            // the dot inside the box
        const x = b => r + b / (buckets - 1) * (width - 2 * r);
        const y = v => r + (1 - (v - lo) / (hi - lo)) * (height - 2 * r);
        ctx.strokeStyle = faint;
        ctx.lineWidth = 1;
        ctx.lineJoin = "round";
        ctx.beginPath();
        let prev = -2;
        for (const p of pts) {
            if (p[0] === prev + 1) ctx.lineTo(x(p[0]), y(p[1])); else ctx.moveTo(x(p[0]), y(p[1]));
            prev = p[0];
        }
        ctx.stroke();
        const last = pts[pts.length - 1];
        if (last[0] >= buckets - 2) {
            ctx.fillStyle = ink;
            ctx.beginPath();
            ctx.arc(x(last[0]), y(last[1]), r, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
}
