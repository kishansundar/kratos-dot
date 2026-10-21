.pragma library
// The launcher's matching (design/launcher README, Principles 2 and 5): which apps match a query, in what order, and
// which letters to underline. Plain functions over an app's name, genericName, keywords and id, so
// tests/AppMatchTest.qml runs them on a fixed list of apps (`sh tests/run.sh`).
// Tiers, best first:
//   0  the name starts with the query                                          "fi"   Files
//   1  a word in the name starts with it                                       "fi"   Yazi File Manager
//   2  initials of words in a row, from `fuzzyMin` letters                     "fm"   Yazi File Manager
//   3  anywhere in the name, from `fuzzyMin` letters                           "ile"  Files
//   4  a word of the generic name, a keyword or the desktop id starts with it, from `fuzzyMin` letters
//                                                                              "web"  Helium (Web Browser)
// One letter matches only by 0 and 1, so "f" lists the apps whose name or a word in it starts with f. Ties: the
// most recently opened first, then by name. Words start after a space or a sign, at a lower-to-capital step
// ("CoolerControl") and after a figure ("1Password").

function isLetter(c) { return c.toLowerCase() !== c.toUpperCase() }
function isFigure(c) { return c >= "0" && c <= "9" }
function isWordChar(c) { return isLetter(c) || isFigure(c) }

function normalise(query) { return (query || "").trim().replace(/\s+/g, " ").toLowerCase() }

// The indices in `s` where words start.
function wordStarts(s) {
    const starts = [];
    for (let i = 0; i < s.length; i++) {
        const c = s[i], p = i > 0 ? s[i - 1] : "";
        if (!isWordChar(c)) continue;
        if (p === "" || !isWordChar(p)
            || (c !== c.toLowerCase() && p !== p.toUpperCase())     // lower to capital: Cooler|Control
            || (isLetter(c) && isFigure(p)))                        // figure to letter: 1|Password
            starts.push(i);
    }
    return starts;
}

// The positions from..from+n in `s`, without the spaces (an underline runs under letters only).
function span(s, from, n) {
    const out = [];
    for (let i = from; i < from + n; i++) if (s[i] !== " ") out.push(i);
    return out;
}

// Where `q` (normalised) starts at a word start of `s`, or -1.
function atWordStart(s, q) {
    const low = s.toLowerCase();
    for (const i of wordStarts(s)) if (low.startsWith(q, i)) return i;
    return -1;
}

function list(v) {
    const out = [];
    if (v) for (let i = 0; i < v.length; i++) out.push(String(v[i]));
    return out;
}

// How `app` matches the query: null, or { tier, marks (indices in the name), genericMarks (in the generic name) }.
function match(app, query, fuzzyMin) {
    const q = normalise(query);
    if (q === "") return null;
    const name = app.name || "";
    const low = name.toLowerCase();
    const starts = wordStarts(name);

    if (low.startsWith(q)) return { tier: 0, marks: span(name, 0, q.length), genericMarks: [] };
    for (const i of starts)
        if (i > 0 && low.startsWith(q, i)) return { tier: 1, marks: span(name, i, q.length), genericMarks: [] };
    if (q.length < fuzzyMin) return null;

    const initials = starts.map(i => low[i]).join("");
    const k = q.includes(" ") ? -1 : initials.indexOf(q);
    if (k >= 0) return { tier: 2, marks: starts.slice(k, k + q.length), genericMarks: [] };

    const at = low.indexOf(q);
    if (at >= 0) return { tier: 3, marks: span(name, at, q.length), genericMarks: [] };

    const generic = app.genericName || "";
    const g = atWordStart(generic, q);
    if (g >= 0) return { tier: 4, marks: [], genericMarks: span(generic, g, q.length) };
    const details = list(app.keywords).concat([String(app.id || "").split(".").pop()]);
    for (const d of details)
        if (atWordStart(d, q) >= 0) return { tier: 4, marks: [], genericMarks: [] };
    return null;
}

function byName(a, b) {
    const x = a.name.toLowerCase(), y = b.name.toLowerCase();
    return x < y ? -1 : x > y ? 1 : 0;
}

// The apps that match, best first: [{ app, tier, marks, genericMarks }]. `recent`: desktop ids, the last opened first.
function rank(apps, query, recent, fuzzyMin) {
    const order = id => { const i = recent.indexOf(id); return i < 0 ? recent.length : i };
    const out = [];
    for (const app of apps) {
        const m = match(app, query, fuzzyMin);
        if (m) out.push({ app: app, tier: m.tier, marks: m.marks, genericMarks: m.genericMarks });
    }
    out.sort((a, b) => a.tier - b.tier || order(a.app.id) - order(b.app.id) || byName(a.app, b.app));
    return out;
}

// The last `count` apps opened that are still installed, in the shape rank() gives (nothing underlined).
function recentApps(apps, recent, count) {
    const out = [];
    for (const id of recent) {
        const app = apps.find(a => a.id === id);
        if (app) out.push({ app: app, tier: -1, marks: [], genericMarks: [] });
        if (out.length === count) break;
    }
    return out;
}

// The row's short description: the generic name in lower case ("web browser"), keeping words in capitals ("RGB");
// nothing when there is none or it only repeats the name (Volume Control).
function shortGeneric(app) {
    const g = (app.genericName || "").trim();
    if (g === "" || g.toLowerCase() === (app.name || "").toLowerCase()) return "";
    return g.replace(/\S+/g, w => w === w.toUpperCase() && w.length > 1 ? w : w.toLowerCase());
}
