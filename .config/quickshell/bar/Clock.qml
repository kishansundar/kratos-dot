import QtQuick
import Quickshell
import qs
import qs.components
import qs.services
import "ClockInk.js" as ClockInk
import "../services/Format.js" as Format

// The ruled clock, on one line and the bar's baseline (Clock):
//     Thursday  02 ┃ 34  15 October
// The weekday and the date in label, muted; hours and minutes in count (22 / 700, tabular), split by a 2 x 16 px
// stroke; 8 px between the inks on both sides of the stroke and of each numeral, measured, not estimated: every
// string's real ink edges come from bar/ClockInk.js (tools/clock-ink renders and measures them; Qt's own tight box is
// about 1 px off against the hinted glyphs, so "18 | 13" read 9.1 | 8.9 and the flanks 10.6 and 9.6). Each side then
// takes the whole-pixel position that leaves its two gaps most nearly equal (within half a pixel; the grid allows no
// better). Kept from "Measure" by the owner's choice: the clock sits on the screen's centre (the package puts
// it at the right edge) and its stroke is red, the "now" mark; the Bar places this item by `strokeX`, so neither the
// flanks' widths nor anything to the left or right can move it. The left flank is as wide as the longest weekday.
// Click for the date and time panel (panels/DateTimePanel), which hangs from the stroke (`anchorX`).
BarSlot {
    id: clock

    readonly property int gap: Theme.space.s2
    readonly property real strokeX: stroke.x + stroke.width / 2     // children are placed from the slot's edge
    anchorX: strokeX

    panel: "calendar"
    padding: Theme.space.s3
    fixedWidth: Math.ceil(dateText.x + dateText.implicitWidth) + padding
    tooltip: Qt.formatDate(time.date, "dddd d MMMM yyyy") + " · week " + Format.isoWeek(time.date) + " · Super+Ctrl+C"

    SystemClock { id: time; precision: SystemClock.Minutes }

    // Ink edges in px from a Text's x: measured (bar/ClockInk.js) when the table has the string, else TextMetrics'
    // tight box (relative to the text's origin: x where the ink starts, width how far it runs).
    function leftOf(table, key, m) { const v = table[key]; return v !== undefined ? v : m.tightBoundingRect.x }
    function rightOf(table, key, m) { const v = table[key]; return v !== undefined ? v : m.tightBoundingRect.x + m.tightBoundingRect.width }
    // Two whole-pixel positions a and b (each may round down or up from its exact value) whose gaps come out most
    // nearly equal; among equals, the pair nearest `gap`. gapA(a) and gapB(b) give the gaps a position leaves.
    function evenPair(exactA, exactB, gapA, gapB) {
        let best = null;
        for (const a of [Math.floor(exactA), Math.ceil(exactA)])
            for (const b of [Math.floor(exactB), Math.ceil(exactB)]) {
                const ga = gapA(a), gb = gapB(b);
                const score = Math.abs(ga - gb) * 10 + Math.abs(ga + gb - 2 * gap);
                if (best === null || score < best.score) best = { score: score, a: a, b: b };
            }
        return best;
    }
    readonly property var layout: {
        const s = stroke.x, w = stroke.width, g = gap;
        const hL = leftOf(ClockInk.countLeft, hours.text, hoursInk), hR = rightOf(ClockInk.countRight, hours.text, hoursInk);
        const mL = leftOf(ClockInk.countLeft, minutes.text, minutesInk), mR = rightOf(ClockInk.countRight, minutes.text, minutesInk);
        const nums = evenPair(s - g - hR, s + w + g - mL, hx => s - (hx + hR), mx => (mx + mL) - (s + w));
        const dR = rightOf(ClockInk.dayRight, dayName.text, dayInk), tL = leftOf(ClockInk.dateLeft, dateText.text.charAt(0), dateInk);
        const hInkL = nums.a + hL, mInkR = nums.b + mR;
        const flanks = evenPair(hInkL - g - dR, mInkR + g - tL, dx => hInkL - (dx + dR), tx => (tx + tL) - mInkR);
        return { hours: nums.a, minutes: nums.b, day: flanks.a, date: flanks.b };
    }
    TextMetrics { id: dayInk; font: dayName.font; text: dayName.text }
    TextMetrics { id: hoursInk; font: hours.font; text: hours.text }
    TextMetrics { id: minutesInk; font: minutes.font; text: minutes.text }
    TextMetrics { id: dateInk; font: dateText.font; text: dateText.text }
    // The hours' room: tabular figures, so any two digits take this advance and the stroke never moves.
    TextMetrics { id: digitsWidth; font: hours.font; text: "00" }

    Txt {
        id: dayName
        x: clock.layout.day
        anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline }
        variant: Theme.font.label
        text: Qt.formatDate(time.date, "dddd")
        color: Theme.colors.textMuted
    }
    // The left flank is as wide as the longest weekday, so the clock does not move from Tuesday to Wednesday.
    TextMetrics { id: weekdayWidth; font: dayName.font; text: "Wednesday" }

    Txt {
        id: hours
        x: clock.layout.hours
        anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline }
        variant: Theme.font.count
        text: Qt.formatTime(time.date, "HH")
    }
    IndexMark {
        id: stroke
        x: clock.padding + Math.ceil(weekdayWidth.advanceWidth) + clock.gap + Math.ceil(digitsWidth.advanceWidth) + clock.gap
        y: Theme.bar.baseline - height
    }
    Txt {
        id: minutes
        x: clock.layout.minutes
        anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline }
        variant: Theme.font.count
        text: Qt.formatTime(time.date, "mm")
    }
    Txt {
        id: dateText
        x: clock.layout.date
        anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline }
        variant: Theme.font.label
        text: Qt.formatDate(time.date, "d MMMM")
        color: Theme.colors.textMuted
    }
}
