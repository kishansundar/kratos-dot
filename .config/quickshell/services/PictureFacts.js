.pragma library

// The wallpaper picker's facts about a picture (overlays/WallpaperPicker.qml), checked by tests/PictureFactsTest.qml.
// After skwd-wall, which sorts and filters a library by colour: a picture's colour is one of twelve hues 30° apart
// (red at 0°) or neutral, read from its pixels, never its name, so a picture added later finds its place by itself.
//
// A file is { dir, path, url, name, suffix, size, modified, key } as the picker reads it out of its FolderListModel;
// `key` names its facts (the small copy's name: path and modification time), and factsOf(key) gives them:
//   { colour: 0-11 | 12 (neutral), sat, light, w, h }, or undefined while they are not read yet.

const names = ["red", "orange", "yellow", "lime", "green", "teal", "cyan", "azure", "blue", "violet", "magenta", "rose"];
const neutral = 12;
// A pixel whose strongest and weakest channels are closer than this (a fraction of the range, about 31 of 255) has no
// hue: black, white, grey, cream.
const chromaMin = 0.12;

function colourName(c) {
    return c === neutral ? "neutral" : names[c] ?? "";
}

// The hue (0-11) of one pixel, or neutral.
function bucket(r, g, b) {
    const max = Math.max(r, g, b) / 255, min = Math.min(r, g, b) / 255, c = max - min;
    if (c < chromaMin) return neutral;
    r /= 255; g /= 255; b /= 255;
    let h = max === r ? ((g - b) / c) % 6 : max === g ? (b - r) / c + 2 : (r - g) / c + 4;
    if (h < 0) h += 6;
    return Math.round(h * 2) % 12;          // h is in sixths of the circle; a bucket is a twelfth, centred on its hue
}

// A small copy's pixels (RGBA, as a Canvas gives them) -> { colour, sat, light }: the colour that covers most of the
// picture (neutral counts as one), how strong that hue is there (the mean chroma of its pixels, 0 for neutral) and
// how light the whole picture is (the mean of (max + min) / 2).
function colour(data) {
    const counts = new Array(13).fill(0), chroma = new Array(13).fill(0);
    let light = 0, n = 0;
    for (let i = 0; i + 3 < data.length; i += 4) {
        const r = data[i], g = data[i + 1], b = data[i + 2];
        const max = Math.max(r, g, b) / 255, min = Math.min(r, g, b) / 255;
        const k = bucket(r, g, b);
        counts[k]++;
        chroma[k] += max - min;
        light += (max + min) / 2;
        n++;
    }
    if (n === 0) return null;
    let best = neutral;
    for (let k = 0; k < 12; k++) if (counts[k] > counts[best]) best = k;
    return {
        colour: best,
        sat: best === neutral ? 0 : Math.round(chroma[best] / counts[best] * 1000) / 1000,
        light: Math.round(light / n * 1000) / 1000
    };
}

// The colours found in `files` with how many pictures have each, in colour order (the filter's swatches).
function colours(files, factsOf) {
    const counts = {};
    for (const f of files) {
        const x = factsOf(f.key);
        if (x && x.colour !== undefined) counts[x.colour] = (counts[x.colour] || 0) + 1;
    }
    return Object.keys(counts).map(Number).sort((a, b) => a - b).map(c => ({ colour: c, count: counts[c] }));
}

// "wide", "tall" or "" (square, or not read yet).
function shapeOf(x) {
    if (!x || !x.w || !x.h) return "";
    return x.w > x.h * 1.05 ? "wide" : x.h > x.w * 1.05 ? "tall" : "";
}

// The pictures a filter lets through: { colour: -1 (any) or 0-12, shape: "all" | "wide" | "tall", favourites: bool }.
// A picture not read yet passes a colour or shape filter only when that filter is off.
function filter(files, by, factsOf, favourites) {
    return files.filter(f => {
        const x = factsOf(f.key);
        if (by.favourites && !favourites.includes(f.path)) return false;
        if (by.colour >= 0 && (!x || x.colour !== by.colour)) return false;
        if (by.shape !== "all" && shapeOf(x) !== by.shape) return false;
        return true;
    });
}

// Sorted copies of `files`:
//   "colour"  hue order (red first), neutral last; within a hue the stronger first, within neutral the darker first
//   "date"    the newest first
//   "name"    by name, numbers by value ("2" before "10")
//   "size"    the most pixels first
// Pictures not read yet go last (by name) wherever the order needs their facts.
// (By hand: Qt's localeCompare takes no options.)
function byName(a, b) {
    const x = a.name.toLowerCase().match(/\d+|\D+/g) || [], y = b.name.toLowerCase().match(/\d+|\D+/g) || [];
    for (let i = 0; i < Math.min(x.length, y.length); i++) {
        if (x[i] === y[i]) continue;
        const m = Number(x[i]), n = Number(y[i]);
        if (!isNaN(m) && !isNaN(n) && m !== n) return m - n;
        return x[i] < y[i] ? -1 : 1;
    }
    return (x.length - y.length) || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0);
}
function order(files, by, factsOf) {
    const known = f => { const x = factsOf(f.key); return x && x.colour !== undefined ? x : null; };
    const out = files.slice();
    if (by === "name") return out.sort(byName);
    if (by === "date") return out.sort((a, b) => (b.modified - a.modified) || byName(a, b));
    if (by === "size") return out.sort((a, b) => {
        const x = known(a), y = known(b);
        if (!x || !y) return (!x - !y) || byName(a, b);
        return (y.w * y.h - x.w * x.h) || byName(a, b);
    });
    return out.sort((a, b) => {
        const x = known(a), y = known(b);
        if (!x || !y) return (!x - !y) || byName(a, b);
        if (x.colour !== y.colour) return x.colour - y.colour;
        if (x.colour === neutral) return (x.light - y.light) || byName(a, b);
        return (y.sat - x.sat) || byName(a, b);
    });
}

// A picture's width and height from its first bytes (as `od -An -v -tu1` gives them), without decoding it: PNG, JPEG
// and WebP; null for anything else or too few bytes. (PNG and WebP say it in the first 30 bytes; a JPEG's start of
// frame can come after its metadata, so the picker reads 64 kB of one.)
function dimensions(b) {
    const be16 = i => b[i] * 256 + b[i + 1];
    const be32 = i => ((b[i] * 256 + b[i + 1]) * 256 + b[i + 2]) * 256 + b[i + 3];
    const le24 = i => b[i] + b[i + 1] * 256 + b[i + 2] * 65536;
    const ascii = (i, n) => String.fromCharCode.apply(null, b.slice(i, i + n));
    if (b.length >= 24 && b[0] === 137 && ascii(1, 3) === "PNG")
        return { w: be32(16), h: be32(20) };
    if (b.length >= 4 && b[0] === 0xFF && b[1] === 0xD8) {
        let i = 2;
        while (i + 8 < b.length) {
            if (b[i] !== 0xFF) { i++; continue; }
            const m = b[i + 1];
            if (m === 0xFF) { i++; continue; }                                   // fill
            if (m === 0x01 || (m >= 0xD0 && m <= 0xD9)) { i += 2; continue; }   // no length
            if (m >= 0xC0 && m <= 0xCF && m !== 0xC4 && m !== 0xC8 && m !== 0xCC)
                return { w: be16(i + 7), h: be16(i + 5) };                      // a start of frame
            i += 2 + be16(i + 2);
        }
        return null;
    }
    if (b.length >= 30 && ascii(0, 4) === "RIFF" && ascii(8, 4) === "WEBP") {
        const kind = ascii(12, 4);
        if (kind === "VP8X") return { w: 1 + le24(24), h: 1 + le24(27) };
        if (kind === "VP8 ") return { w: (b[26] + b[27] * 256) & 0x3FFF, h: (b[28] + b[29] * 256) & 0x3FFF };
        if (kind === "VP8L")
            return { w: 1 + (((b[22] & 0x3F) << 8) | b[21]), h: 1 + (((b[24] & 0x0F) << 10) | (b[23] << 2) | ((b[22] & 0xC0) >> 6)) };
    }
    return null;
}

// WCAG 2.x, for the bar's contrast over a picture: a channel (0-255) made linear, the relative luminance of [r, g, b],
// the contrast of two such colours (1 to 21), and "#rrggbb" as [r, g, b].
function linear(c) { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
function luminance(rgb) { return 0.2126 * linear(rgb[0]) + 0.7152 * linear(rgb[1]) + 0.0722 * linear(rgb[2]) }
function contrast(a, b) {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}
function rgbOf(hex) {
    const h = String(hex).replace("#", "");
    return [0, 2, 4].map(i => parseInt(h.substr(i, 2), 16));
}
