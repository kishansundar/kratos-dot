pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs

// The media player the desktop speaks about (MPRIS), chosen the way a person would point at it:
//   1. the one playing (if several play, the one that started last);
//   2. else the one that played last, paused, so its track stays in view with its state;
//   3. else the first player that has a track.
// playerctld is left out: it re-publishes whichever player is active, so counting it would show every track
// twice. A player with no title shows nothing: a browser tab that only plays sounds is not "now playing".
Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => !(p.dbusName ?? "").endsWith(".playerctld"))
    property var last: null                         // the player that started playing most recently
    property bool pinned: false                     // chosen in the media popover: followed until another one starts
    function choose(p) { last = p; pinned = true }
    // The next player (a right click on the bar's player id).
    function cycle() {
        if (players.length < 2) return;
        choose(players[(players.indexOf(player) + 1) % players.length]);
    }

    // Go to a player's window (a click on the bar's player id): the mango window of the process that owns the player's
    // D-Bus name; of several (a browser's windows), the one whose title names the track; else a window whose app id is
    // the player's desktop entry or name; then the player's own Raise (in a browser: its playing tab). mango switches to
    // the window's tag.
    property var seeking: null
    property int seekingPid: -1
    function goTo(p) {
        if (!p || ownerProc.running) return;     // one lookup at a time: its answer is for the player it asked about
        seeking = p;
        seekingPid = -1;
        ownerProc.command = ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                             "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", p.dbusName];
        ownerProc.running = true;
    }
    Process {
        id: ownerProc
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/u (\d+)/);
                root.seekingPid = m ? Number(m[1]) : -1;
                Mango.readClients(list => root.reach(list ?? []));
            }
        }
    }
    function reach(clients) {
        const p = root.seeking;
        if (!p) return;
        const names = [p.desktopEntry, (p.identity ?? "").split(" ").pop()]
            .filter(n => n).map(n => n.toLowerCase());
        let found = clients.filter(c => c.pid === root.seekingPid);
        if (found.length === 0) found = clients.filter(c => names.includes((c.appid ?? "").toLowerCase().replace(/^.*\./, "")));
        const track = (p.trackTitle ?? "").toLowerCase().slice(0, 24);
        const c = found.find(c => track !== "" && (c.title ?? "").toLowerCase().includes(track)) ?? found[0];
        // mango brings the window (its tag, the focus); the player's own Raise then brings its tab forward in a
        // browser (Firefox and Zen raise the tab that plays). Players without Raise (mpv) need only the window.
        if (c) Mango.focusClient(c.id);
        if (p.canRaise) p.raise();
        root.seeking = null;
    }

    readonly property var player: {
        if (pinned && players.includes(last)) return last;
        const playing = players.filter(p => p.isPlaying);
        if (playing.length > 0) return playing.includes(last) ? last : playing[0];
        if (players.includes(last)) return last;
        return players.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    readonly property bool active: player !== null && title !== ""
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: (player?.trackTitle ?? "").trim()
    readonly property var meta: player?.metadata ?? ({})
    // The artist (several joined with ", "), unless the title already names it ("Artist - Title" from some browsers).
    readonly property string artist: {
        const list = meta["xesam:artist"];
        const a = (typeof list === "object" && list && list.length !== undefined ? Array.from(list).join(", ")
                   : player?.trackArtist ?? "").trim();
        return a !== "" && !title.toLowerCase().includes(a.toLowerCase()) ? a : "";
    }
    readonly property string album: (player?.trackAlbum ?? "").trim()
    readonly property string year: (String(meta["xesam:contentCreated"] ?? meta["year"] ?? "").match(/^\d{4}/) ?? [""])[0]
    // Browser media has no album: the site it plays on instead ("youtube.com").
    readonly property string host: (String(meta["xesam:url"] ?? "").match(/^https?:\/\/(?:www\.)?([^\/:?#]+)/) ?? ["", ""])[1]
    // A local file without an album: its format ("flac"), for the panel's source line.
    readonly property string format: (String(meta["xesam:url"] ?? "").match(/^file:\/\/.*\.(\w{2,5})$/) ?? ["", ""])[1].toLowerCase()
    readonly property string art: player?.trackArtUrl ?? ""
    // Players that claim a volume but ignore a change (it never moved after a set): the panel hides their volume for
    // the rest of the session. Keyed by D-Bus name.
    property var volumeIgnored: ({})
    function ignoreVolume(p) { if (p) { const m = Object.assign({}, volumeIgnored); m[p.dbusName] = true; volumeIgnored = m; } }
    readonly property string app: player?.identity ?? ""

    // The player for the lock screen (~/.config/hypr/lock-media.sh) and `qs ipc call bar nowPlaying`, one field a line:
    // playing / paused / none, the app, the title, the artist. Written to the shell's cache whenever it changes, so the
    // lock screen reads a file every second instead of starting an IPC client each time (~46 ms of CPU a call).
    readonly property string nowPlaying: {
        const line = s => String(s ?? "").replace(/[\r\n\t]+/g, " ").trim();
        if (!active) return "none";
        return [playing ? "playing" : "paused", line(app), line(title), line(artist)].join("\n");
    }
    onNowPlayingChanged: nowPlayingFile.setText(nowPlaying + "\n")
    Component.onCompleted: nowPlayingFile.setText(nowPlaying + "\n")
    FileView {
        id: nowPlayingFile
        path: Theme.cacheDir + "/now-playing"
        preload: false
        printErrors: false
        atomicWrites: true
    }
    // A player's short id, as the bar and the Now Playing panel name it: the last word of its name, lower case
    // ("Mozilla zen" -> "zen"), or of its bus name when it has none ("org.mpris.MediaPlayer2.spotify" -> "spotify").
    function idOf(p) {
        const name = (p?.identity ?? "").trim();
        return (name !== "" ? name.split(" ").pop() : (p?.dbusName ?? "").replace("org.mpris.MediaPlayer2.", "").split(".")[0]).toLowerCase();
    }

    // Remember who started playing last.
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying && modelData !== root.last) { root.last = modelData; root.pinned = false; } }
        }
    }

}
