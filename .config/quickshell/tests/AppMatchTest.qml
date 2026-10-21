import QtQuick
import Quickshell
import "../services/AppMatch.js" as AppMatch

// The launcher's ranking (services/AppMatch.js) on the 24 apps NixDesk listed on 15 October 2026, as their desktop
// files give them. Run with `sh tests/run.sh` (it prints each check, then PASS or "FAIL: n", and exits 0 or 1).
// The package's examples: "f" lists the apps whose name or a word in it starts with f, and "fm" finds Yazi File
// Manager by its initials. (The package's picture also lists Advanced Network Configuration for "f", with the g
// underlined; no word of it starts with f, and its own rule says one letter matches only name and word starts, so
// the rule wins.)
Scope {
    id: test

    readonly property int fuzzyMin: 2      // design/launcher/tokens.json control.fuzzyMin
    readonly property var apps: [
        { id: "btop", name: "btop++", genericName: "System Monitor", keywords: ["system", "process", "task"] },
        { id: "com.onepassword.OnePassword", name: "1Password", genericName: "", keywords: [] },
        { id: "dev.zed.Zed", name: "Zed", genericName: "Text Editor", keywords: ["zed"] },
        { id: "emacsclient", name: "Emacs (Client)", genericName: "Text Editor", keywords: ["emacsclient"] },
        { id: "emacs", name: "Emacs", genericName: "Text Editor", keywords: [] },
        { id: "helium", name: "Helium", genericName: "Web Browser", keywords: [] },
        { id: "kitty", name: "kitty", genericName: "Terminal emulator", keywords: [] },
        { id: "md.obsidian.Obsidian", name: "Obsidian", genericName: "", keywords: [] },
        { id: "mpv", name: "mpv Media Player", genericName: "Multimedia player", keywords: ["mpv", "media", "player", "video", "audio", "tv"] },
        { id: "nixos-manual", name: "NixOS Manual", genericName: "System Manual", keywords: [] },
        { id: "nm-connection-editor", name: "Advanced Network Configuration", genericName: "", keywords: [] },
        { id: "nvidia-settings", name: "NVIDIA X Server Settings", genericName: "", keywords: [] },
        { id: "nvim", name: "Neovim wrapper", genericName: "Text Editor", keywords: ["Text", "editor"] },
        { id: "org.coolercontrol.CoolerControl", name: "CoolerControl", genericName: "", keywords: ["cooling", "fan control", "pump control"] },
        { id: "org.freedesktop.Piper", name: "Piper", genericName: "", keywords: ["gaming", "configuration", "mouse", "mice"] },
        { id: "org.gnome.Nautilus", name: "Files", genericName: "", keywords: ["folder", "manager", "explore", "disk", "filesystem", "nautilus"] },
        { id: "org.openrgb.OpenRGB", name: "OpenRGB", genericName: "", keywords: [] },
        { id: "org.pulseaudio.pavucontrol", name: "Volume Control", genericName: "Volume Control", keywords: ["pavucontrol", "PulseAudio", "Microphone", "Volume", "Fade", "Balance", "Headset", "Speakers", "Headphones", "Audio", "Mixer", "Output", "Input", "Devices", "Playback", "Recording", "System Sounds", "Sound Card", "Settings", "Preferences"] },
        { id: "polychromatic", name: "Polychromatic", genericName: "Device Manager for RGB Lighting", keywords: ["RGB", "Razer", "Chroma"] },
        { id: "qimgv", name: "qimgv", genericName: "Image Viewer", keywords: ["image", "view", "qimgv", "picture", "gif", "jpeg", "webm"] },
        { id: "rustdesk", name: "RustDesk", genericName: "Remote Desktop", keywords: ["internet"] },
        { id: "spotify", name: "Spotify", genericName: "Music Player", keywords: [] },
        { id: "yazi", name: "Yazi File Manager", genericName: "", keywords: ["File", "Manager", "Explorer", "Browser", "Launcher"] },
        { id: "zen", name: "Zen Browser", genericName: "Web Browser", keywords: [] }
    ]

    property int failures: 0
    function names(q, recent) { return AppMatch.rank(apps, q, recent || [], fuzzyMin).map(r => r.app.name) }
    function first(q) { return AppMatch.rank(apps, q, [], fuzzyMin)[0] }
    function eq(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok) failures++;
        console.log((ok ? "ok    " : "FAIL  ") + what + (ok ? "" : "\n        got  " + JSON.stringify(got) + "\n        want " + JSON.stringify(want)));
    }

    Component.onCompleted: {
        // The package's examples.
        eq("f: only name and word starts, the name start first", names("f"), ["Files", "Yazi File Manager"]);
        eq("f: Files underlines its F", first("f").marks, [0]);
        eq("fm: initials", names("fm"), ["Yazi File Manager"]);
        eq("fm: underlines F and M", first("fm").marks, [5, 10]);
        eq("fm: tier 2 (initials)", first("fm").tier, 2);
        eq("qzx: nothing", names("qzx"), []);

        // The order of the tiers.
        eq("fi: name start, word start, then anywhere in the name", names("fi"), ["Files", "Yazi File Manager", "Advanced Network Configuration"]);
        eq("fi: Configuration underlines its fi", AppMatch.rank(apps, "fi", [], fuzzyMin)[2].marks, [20, 21]);
        eq("fi: Yazi underlines Fi", AppMatch.rank(apps, "fi", [], fuzzyMin)[1].marks, [5, 6]);
        eq("ile: anywhere in the name, then by name", names("ile"), ["Files", "Yazi File Manager"]);
        eq("c: name start, then word starts by name", names("c"),
           ["CoolerControl", "Advanced Network Configuration", "Emacs (Client)", "Volume Control"]);
        eq("control: a lower-to-capital step starts a word", names("control"), ["CoolerControl", "Volume Control"]);
        eq("pass: a figure-to-letter step starts a word", names("pass"), ["1Password"]);
        eq("web: generic names and keywords come last", names("web"), ["Helium", "qimgv", "Zen Browser"]);
        eq("web: Helium underlines its generic name", first("web").genericMarks, [0, 1, 2]);
        eq("web: no letters of the name underlined", first("web").marks, []);
        eq("nautilus: a keyword", names("nautilus"), ["Files"]);
        eq("pavucontrol: a keyword (and the desktop id)", names("pavucontrol"), ["Volume Control"]);
        eq("editor: generic names, keywords and desktop ids (nm-connection-editor)", names("editor"), ["Advanced Network Configuration", "Emacs", "Emacs (Client)", "Neovim wrapper", "Zed"]);
        eq("x: one letter never matches keywords", names("x"), ["NVIDIA X Server Settings"]);
        eq("n: one letter, name and word starts only", names("n"),
           ["Neovim wrapper", "NixOS Manual", "NVIDIA X Server Settings", "Advanced Network Configuration"]);

        // The query as typed.
        eq("F: case does not matter", names("F"), names("f"));
        eq("  fm  : spaces around do not matter", names("  fm  "), ["Yazi File Manager"]);
        eq("file man: a query across words", names("file man"), ["Yazi File Manager"]);
        eq("file man: the space is not underlined", first("file man").marks, [5, 6, 7, 8, 10, 11, 12]);
        eq("empty: nothing ranked", names(""), []);

        // Ties: the most recently opened first.
        eq("e: by name", names("e"), ["Emacs", "Emacs (Client)"]);
        eq("e: the recent one first", names("e", ["kitty", "emacsclient"]), ["Emacs (Client)", "Emacs"]);
        eq("fi: recency never beats a better tier", names("fi", ["nm-connection-editor", "yazi"]), ["Files", "Yazi File Manager", "Advanced Network Configuration"]);

        // Recent apps (the empty query).
        eq("recent: in order, uninstalled skipped, at most count",
           AppMatch.recentApps(apps, ["zen", "gone", "kitty", "nvim", "btop"], 3).map(r => r.app.name),
           ["Zen Browser", "kitty", "Neovim wrapper"]);

        // The description beside the name.
        eq("generic: lower case", AppMatch.shortGeneric(apps[5]), "web browser");
        eq("generic: words in capitals stay", AppMatch.shortGeneric(apps[18]), "device manager for RGB lighting");
        eq("generic: none when it repeats the name", AppMatch.shortGeneric(apps[17]), "");
        eq("generic: none when there is none", AppMatch.shortGeneric(apps[15]), "");

        console.log(failures === 0 ? "PASS" : "FAIL: " + failures);

    }
}
