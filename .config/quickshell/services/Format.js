.pragma library

// Numbers and times written the same way wherever the shell shows them (checked by tests/FormatTest.qml).

// The ISO 8601 week of a date (weeks start on Monday; week 1 holds the year's first Thursday).
function isoWeek(d) {
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const day = t.getUTCDay() || 7;
    t.setUTCDate(t.getUTCDate() + 4 - day);
    return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
}

// "1:05", "12:00", "75:03" from seconds (minutes never roll over into hours).
function mmss(s) {
    s = Math.max(0, Math.floor(s));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
}

// "1:05", "1:02:09" from seconds: a track's position or length (Now Playing); "–" for none.
function clock(s) {
    if (!(s >= 0) || !isFinite(s)) return "–";
    s = Math.floor(s);
    const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
    return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec;
}

// "3d 4h", "4h 12m", "12m" from seconds; "" below zero.
function span(s) {
    if (s < 0) return "";
    const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
    return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m";
}

// A reading in percent as a whole number, "–" for none (below zero).
function pct(v) { return v < 0 ? "–" : String(Math.round(v)) }

// A file's size: "1.2 MB" from a megabyte up, else whole kilobytes, at least "1 kB" (the wallpaper picker).
function fileSize(bytes) {
    return bytes >= 1e6 ? (bytes / 1e6).toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1e3)) + " kB";
}
