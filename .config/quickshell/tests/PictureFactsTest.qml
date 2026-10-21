import QtQuick
import Quickshell
import "../services/PictureFacts.js" as Facts

// The wallpaper picker's facts (services/PictureFacts.js): colours read from pixels (the posters' own colours, measured
// on 20 October 2026 from swiss-typography-no-grid-v2: black #000000, grey #f5f5f5, cream #f7efe5, the red #e93f20),
// filters, orders and sizes from a file's first bytes. Run with `sh tests/run.sh`.
Scope {
    id: test

    property int failures: 0
    function eq(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok) failures++;
        console.log((ok ? "ok    " : "FAIL  ") + what + (ok ? "" : "\n        got  " + JSON.stringify(got) + "\n        want " + JSON.stringify(want)));
    }
    // RGBA pixels: `n` of each [r, g, b].
    function pixels(parts) {
        const out = [];
        for (const p of parts) for (let i = 0; i < p[1]; i++) out.push(p[0][0], p[0][1], p[0][2], 255);
        return out;
    }
    function file(name, key, modified) {
        return { dir: false, path: "/w/" + name, name: name, key: key, modified: modified || 0 };
    }

    Component.onCompleted: {
        // One pixel's bucket.
        eq("the posters' red is red", Facts.bucket(0xe9, 0x3f, 0x20), 0);
        eq("orange", Facts.bucket(255, 140, 0), 1);
        eq("blue", Facts.bucket(30, 60, 220), 8);
        eq("black is neutral", Facts.bucket(0, 0, 0), Facts.neutral);
        eq("cream is neutral", Facts.bucket(0xf7, 0xef, 0xe5), Facts.neutral);
        eq("a dark navy still has a hue", Facts.bucket(0x1a, 0x23, 0x40), 8);
        eq("rose wraps round to the end", Facts.bucket(230, 30, 120), 11);

        // A picture's colour: the one covering most of it, neutral counting as one.
        const black = Facts.colour(pixels([[[0, 0, 0], 70], [[0xe9, 0x3f, 0x20], 30]]));
        eq("a black poster with a red letter is neutral", black.colour, Facts.neutral);
        eq("  and dark", black.light < 0.2, true);
        const orange = Facts.colour(pixels([[[0xe9, 0x3f, 0x20], 70], [[255, 255, 255], 30]]));
        eq("an orange poster is red", orange.colour, 0);
        eq("  with its red's strength", orange.sat, 0.788);
        const forest = Facts.colour(pixels([[[40, 120, 50], 35], [[200, 200, 200], 45], [[90, 60, 30], 20]]));
        eq("a forest under a wide grey sky is neutral", forest.colour, Facts.neutral);
        const forest2 = Facts.colour(pixels([[[40, 120, 50], 50], [[200, 200, 200], 30], [[90, 60, 30], 20]]));
        eq("  and green when it does", forest2.colour, 4);
        eq("no pixels: nothing", Facts.colour([]), null);
        eq("names", [0, 4, 12].map(Facts.colourName), ["red", "green", "neutral"]);

        // Filters and orders.
        const facts = {
            a: { colour: 12, sat: 0, light: 0.9, w: 5120, h: 2880 },
            b: { colour: 0, sat: 0.6, light: 0.5, w: 1920, h: 1080 },
            c: { colour: 12, sat: 0, light: 0.1, w: 5120, h: 2880 },
            d: { colour: 0, sat: 0.9, light: 0.5, w: 1080, h: 1920 },
            e: { colour: 8, sat: 0.4, light: 0.3, w: 3840, h: 2160 }
        };
        const of = k => facts[k];
        const files = [file("cream.png", "a", 3), file("dusk.jpg", "b", 5), file("night.png", "c", 1),
                       file("phone.jpg", "d", 4), file("sea.webp", "e", 2), file("new.png", "z", 9)];
        const names = l => l.map(f => f.name);
        eq("colour: red strong first, blue, neutral dark to light, unread last",
           names(Facts.order(files, "colour", of)), ["phone.jpg", "dusk.jpg", "sea.webp", "night.png", "cream.png", "new.png"]);
        eq("date: newest first", names(Facts.order(files, "date", of)),
           ["new.png", "dusk.jpg", "phone.jpg", "cream.png", "sea.webp", "night.png"]);
        eq("size: most pixels first, unread last", names(Facts.order(files, "size", of)),
           ["cream.png", "night.png", "sea.webp", "dusk.jpg", "phone.jpg", "new.png"]);
        eq("name: numbers by value", names(Facts.order([file("w10.png"), file("w2.png"), file("W1.png")], "name", of)),
           ["W1.png", "w2.png", "w10.png"]);
        eq("filter: red only", names(Facts.filter(files, { colour: 0, shape: "all", favourites: false }, of, [])),
           ["dusk.jpg", "phone.jpg"]);
        eq("filter: tall", names(Facts.filter(files, { colour: -1, shape: "tall", favourites: false }, of, [])),
           ["phone.jpg"]);
        eq("filter: favourites", names(Facts.filter(files, { colour: -1, shape: "all", favourites: true }, of, ["/w/sea.webp"])),
           ["sea.webp"]);
        eq("filter: all, unread too", Facts.filter(files, { colour: -1, shape: "all", favourites: false }, of, []).length, 6);
        eq("swatches: colours present, with counts", Facts.colours(files, of),
           [{ colour: 0, count: 2 }, { colour: 8, count: 1 }, { colour: 12, count: 2 }]);

        // Sizes from the first bytes.
        const png = [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 20, 0, 0, 0, 11, 64];
        eq("png 5120 x 2880", Facts.dimensions(png), { w: 5120, h: 2880 });
        const jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 4, 0, 0, 0xFF, 0xC0, 0, 17, 8, 4, 56, 7, 128, 3, 1, 34, 0];
        eq("jpeg 1920 x 1080 after an APP0", Facts.dimensions(jpeg), { w: 1920, h: 1080 });
        eq("unknown: nothing", Facts.dimensions([1, 2, 3]), null);

        eq("#e93f20 as rgb", Facts.rgbOf("#e93f20"), [233, 63, 32]);
        eq("black on white is 21:1", Math.round(Facts.contrast([0, 0, 0], [255, 255, 255]) * 100) / 100, 21);
        eq("a colour on itself is 1:1", Facts.contrast([233, 63, 32], [233, 63, 32]), 1);
        eq("the order does not matter", Facts.contrast([13, 13, 13], [242, 242, 238]), Facts.contrast([242, 242, 238], [13, 13, 13]));
        eq("#767676 on white is 4.54:1 (WCAG's AA grey)", Math.round(Facts.contrast(Facts.rgbOf("#767676"), [255, 255, 255]) * 100) / 100, 4.54);

        console.log(failures === 0 ? "PASS" : "FAIL: " + failures);
    }
}
