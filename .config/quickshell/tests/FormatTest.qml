import QtQuick
import Quickshell
import "../services/Format.js" as Format

// services/Format.js: ISO weeks across year ends, m:ss, clocks, spans, percents and file sizes. Run with `sh tests/run.sh`.
Scope {
    property int failures: 0
    function eq(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok) failures++;
        console.log((ok ? "ok    " : "FAIL  ") + what + (ok ? "" : "\n        got  " + JSON.stringify(got) + "\n        want " + JSON.stringify(want)));
    }

    Component.onCompleted: {
        eq("20 Oct 2026 is week 43", Format.isoWeek(new Date(2026, 9, 20)), 43);
        eq("1 Jan 2026 (a Thursday) is week 1", Format.isoWeek(new Date(2026, 0, 1)), 1);
        eq("1 Jan 2027 (a Friday) is week 53 of 2026", Format.isoWeek(new Date(2027, 0, 1)), 53);
        eq("30 Dec 2024 (a Monday) is week 1 of 2025", Format.isoWeek(new Date(2024, 11, 30)), 1);
        eq("Sunday 4 Jan 2026 is still week 1", Format.isoWeek(new Date(2026, 0, 4)), 1);
        eq("Monday 5 Jan 2026 is week 2", Format.isoWeek(new Date(2026, 0, 5)), 2);

        eq("0:00", Format.mmss(0), "0:00");
        eq("65 s", Format.mmss(65), "1:05");
        eq("a fraction rounds down", Format.mmss(59.9), "0:59");
        eq("past an hour stays minutes", Format.mmss(4503), "75:03");
        eq("below zero is 0:00", Format.mmss(-3), "0:00");

        eq("clock 0:00", Format.clock(0), "0:00");
        eq("clock 3:25", Format.clock(205.7), "3:25");
        eq("clock past an hour", Format.clock(3729), "1:02:09");
        eq("clock of nothing", Format.clock(NaN), "–");
        eq("clock below zero", Format.clock(-1), "–");

        eq("12m", Format.span(720), "12m");
        eq("4h 12m", Format.span(4 * 3600 + 720), "4h 12m");
        eq("3d 4h", Format.span(3 * 86400 + 4 * 3600 + 59), "3d 4h");
        eq("below zero is empty", Format.span(-1), "");

        eq("42.4 %", Format.pct(42.4), "42");
        eq("42.5 % rounds up", Format.pct(42.5), "43");
        eq("none", Format.pct(-1), "–");

        eq("1.2 MB", Format.fileSize(1234567), "1.2 MB");
        eq("34 kB", Format.fileSize(34499), "34 kB");
        eq("a tiny file is 1 kB", Format.fileSize(20), "1 kB");

        console.log(failures === 0 ? "PASS" : "FAIL: " + failures);
    }
}
