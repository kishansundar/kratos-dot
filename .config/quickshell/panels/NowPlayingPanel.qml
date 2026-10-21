import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services
import "../services/Format.js" as Format

// Now Playing, version 2 (design/now-playing: README, then Layouts and States): the panel the bar's track title opens
// (or Super+Ctrl+M), hung under it. Built from what players really send (design/now-playing/recorded): music players
// give square art, a length and a moving position; Zen and Firefox on YouTube give a wide thumbnail, no length and a
// position stuck at 0.
//   Now playing                                       zen +1 ›     the id, other players, a chevron when it can be
//   ├───┼                                                          raised: one button (Media.goTo, the window)
//   the track, compact (the owner's request, 15 October 2026: the package's full-width video frame and separate rows
//   left most of the panel empty): the art artCompact (72) tall at the left, as wide as its shape (album art cropped to
//   its square, video 128 x 72, anything else fitted with surfaceAlt gaps), the words beside it: the title up to two
//   lines, the artist, the source line. No art, or still loading: the words alone, full width.
//   the time row, by what the player reports:
//     seekable   ├────┼────┼───▌┼────┤ elapsed / −remaining; drag or click to seek, the time under the pointer
//     read-only  the same without the handle (a length, a position, no seek)
//     live       a rule, then ● live … time listened (a position that moved for 3 s with no length), or ● live
//                alone for a length of liveLength or more (what a browser gives a live stream when it gives one)
//     untimed    a plain rule, nothing said (the owner's choice over the package's "zen doesn't report position");
//                the default until the live probe has passed. Zen loses YouTube's time when the page moves to the
//                next video without reloading (a Firefox race): ~/nixos/modules/apps/youtube-mpris.user.js, in Violentmonkey,
//                hands it back.
//   ◀◀ [▶] ▶▶  ◁ ├──────────▌ 62%     one row: the one red square, no border; the player's own volume in the rest
//                                     (hidden if it ignores a change). Shuffle and repeat, only if supported, sit
//                                     between a timed track's times, else in the line under the rule.
//   PLAYERS  (only with more than one)
// The row is the panel's last: the red square's lower edge stands on the padding, as the heading's top does.
// Keys: Space play / pause, ← / → 5 s (seekable), ↑ / ↓ volume 5 %, N / P track, Esc closes. Focus starts on play /
// pause; its ring (ink, outside the square) shows only once a key has been pressed in the panel.
FocusScope {
    id: panel
    width: Theme.panel.column
    height: column.height
    focus: true                             // the Loader in PanelHost hands its focus on only to an item that asks

    readonly property var player: Media.player
    readonly property bool hasTrack: Media.active
    readonly property bool canControl: player?.canControl ?? false

    // ---- The time row's form ------------------------------------------------------------------------------------
    readonly property real liveLength: 360000          // 100 h: no track is that long; a browser's live stream is
    readonly property bool endless: hasTrack && !!player && player.lengthSupported && player.length >= liveLength
    readonly property bool timed: hasTrack && !!player && player.positionSupported && player.lengthSupported
        && player.length > 0 && !endless
    readonly property bool seekable: timed && player.canSeek
    // Live needs the player's own Position (Quickshell's `position` counts on by the clock while playing, even when
    // the player says 0): read from D-Bus, then again liveProbe later; moved means live. Until then: untimed.
    property bool live: false
    readonly property bool isLive: live || endless
    readonly property bool needsProbe: hasTrack && !timed && !endless && Media.playing && !live
    onNeedsProbeChanged: if (needsProbe) probe()
    Connections { target: Media; function onTitleChanged() { panel.live = false; panel.probe(); } }
    property real probeFirst: NaN
    property real probeFirstAt: 0
    function probe() {
        probeFirst = NaN;
        probeAgain.stop();
        if (!needsProbe || !player.dbusName) return;
        probeProc.command = ["busctl", "--user", "get-property", player.dbusName, "/org/mpris/MediaPlayer2",
                             "org.mpris.MediaPlayer2.Player", "Position"];
        probeProc.running = true;
    }
    Process {
        id: probeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const v = Number((text.match(/x (-?\d+)/) ?? [0, NaN])[1]);
                // A second reading counts only after the whole probe time (opening asks more than once, and the
                // readings of overlapping asks arrive together): anything sooner starts the probe again.
                if (isNaN(panel.probeFirst) || Date.now() - panel.probeFirstAt < Theme.motion.liveProbe - 100) {
                    panel.probeFirst = v;
                    panel.probeFirstAt = Date.now();
                    probeAgain.restart();
                } else panel.live = !isNaN(v) && v > panel.probeFirst;
            }
        }
    }
    Timer { id: probeAgain; interval: Theme.motion.liveProbe; onTriggered: if (panel.needsProbe) probeProc.running = true }

    // ---- The track's layout, from the loaded art --------------------------------------------------------------------
    Image {
        id: artProbe
        visible: false
        source: Media.art
        asynchronous: true
    }
    readonly property real aspect: artProbe.status === Image.Ready && artProbe.implicitHeight > 0
                                   ? artProbe.implicitWidth / artProbe.implicitHeight : 0
    readonly property string layout: aspect <= 0 ? "bare" : aspect > Theme.control.artSquareMax ? "video" : "album"

    // ---- Focus, keys, volume ------------------------------------------------------------------------------------
    property bool keyed: false              // a key was pressed in the panel: the focus ring may show
    function setVolume(v) {
        if (!canControl) return;
        const want = Math.max(0, Math.min(1, v));
        player.volume = want;
        volumeCheck.want = want;
        volumeCheck.restart();
    }
    // A player that claims a volume but does not move after a set loses the row for the session.
    Timer {
        id: volumeCheck
        property real want: -1
        interval: Theme.motion.positionTick
        onTriggered: if (panel.player && Math.abs(panel.player.volume - want) > 0.01) Media.ignoreVolume(panel.player)
    }
    function stateWord(p) {
        return p.playbackState === MprisPlaybackState.Playing ? "playing"
             : p.playbackState === MprisPlaybackState.Paused ? "paused" : "stopped";
    }
    // Playing first, then paused, then stopped; among equals the one that played last first.
    readonly property var ranked: {
        const rank = p => p.playbackState === MprisPlaybackState.Playing ? 0 : p.playbackState === MprisPlaybackState.Paused ? 1 : 2;
        return Media.players.slice().sort((a, b) => rank(a) - rank(b) || (b === Media.last) - (a === Media.last));
    }

    // The position: read at once (a player just chosen has a stale one), then every positionTick while it plays.
    onPlayerChanged: { if (player && player.positionSupported) player.positionChanged(); live = false; probe(); }
    Component.onCompleted: { if (player && player.positionSupported) player.positionChanged(); probe(); }
    Timer {
        running: (panel.timed || panel.live) && Media.playing
        interval: Theme.motion.positionTick
        repeat: true
        onTriggered: panel.player.positionChanged()
    }

    Keys.onPressed: event => {
        // Any real key shows the focus ring from now on (not the modifiers of the shortcut that opened the panel,
        // nor its auto-repeat).
        if (!event.isAutoRepeat && ![Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Meta, Qt.Key_Control, Qt.Key_Alt,
                                     Qt.Key_Shift].includes(event.key))
            panel.keyed = true;
        const p = panel.player;
        if (!panel.hasTrack) return;
        const k = event.key;
        if (k === Qt.Key_Space && p.canTogglePlaying) p.togglePlaying();
        // ← / →: the position set, not a relative Seek (Zen turns a Seek into its own fixed 10 s step), and kept inside
        // the track (a position past the end would count as "next").
        else if ((k === Qt.Key_Right || k === Qt.Key_Left) && panel.seekable)
            p.position = Math.max(0, Math.min(p.length - 1, p.position + (k === Qt.Key_Right ? 1 : -1) * Theme.motion.seekStep / 1000));
        else if ((k === Qt.Key_Up || k === Qt.Key_Down) && volume.visible) panel.setVolume(p.volume + (k === Qt.Key_Up ? 1 : -1) * Theme.control.volumeStep / 100);
        else if (k === Qt.Key_N && p.canGoNext) p.next();
        else if (k === Qt.Key_P && p.canGoPrevious) p.previous();
        else return;
        event.accepted = true;
    }

    Column {
        id: column
        width: parent.width

        // ---- Header: the title; the player as one button (its window) --------------------------------------------
        Heading {
            title: "Now playing"
            Item {
                id: goTo
                visible: panel.hasTrack
                readonly property bool canGo: panel.player?.canRaise ?? false
                width: goRow.implicitWidth
                height: Theme.size.hitTarget
                activeFocusOnTab: canGo
                function go() { if (canGo) { Media.goTo(panel.player); Panels.close(); } }

                Rectangle {
                    anchors { fill: parent; leftMargin: -Theme.space.s2; rightMargin: -Theme.space.s2 }
                    color: !goTo.canGo ? "transparent" : goMouse.pressed ? Theme.states.pressed : goMouse.containsMouse ? Theme.states.hover : "transparent"
                    border.width: goTo.activeFocus ? Theme.states.focusWidth : 0
                    border.color: Theme.states.focus
                    Behavior on color { enabled: !Theme.recolouring; ColorAnimation { duration: Theme.motion.fast } }
                }
                Row {
                    id: goRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.s1
                    Annot { anchors.verticalCenter: parent.verticalCenter; text: Media.idOf(panel.player) }
                    Annot {
                        visible: Media.players.length > 1
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + (Media.players.length - 1)
                        color: Theme.colors.textFaint
                    }
                    Icon {
                        visible: goTo.canGo
                        anchors.verticalCenter: parent.verticalCenter
                        name: Theme.icons.chevronRight
                        color: Theme.colors.textMuted
                    }
                }
                MouseArea {
                    id: goMouse
                    anchors { fill: parent; leftMargin: -Theme.space.s2; rightMargin: -Theme.space.s2 }
                    enabled: goTo.canGo
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: goTo.go()
                }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        goTo.go();
                        event.accepted = true;
                    }
                }
            }
        }
        Item { width: 1; height: Theme.space.s4 }

        Txt {
            visible: !panel.hasTrack
            width: parent.width
            height: Theme.size.hitTarget
            text: "Nothing playing"
            color: Theme.colors.textMuted
        }

        // ---- Track: the art beside the words ---------------------------------------------------------------------
        // artCompact tall and as wide as its shape, at most artSize (16:9: 128 x 72); album art is cropped to its
        // square, anything else fitted (never cropped), the gaps surfaceAlt. No art: the words alone, full width.
        Row {
            visible: panel.hasTrack
            width: parent.width
            spacing: art.visible ? Theme.space.s4 : 0

            Rectangle {
                id: art
                visible: panel.layout !== "bare"
                readonly property bool album: panel.aspect >= Theme.control.artSquareMin
                                              && panel.aspect <= Theme.control.artSquareMax
                width: !visible ? 0
                     : Math.min(Theme.size.artSize, Math.round(Theme.size.artCompact * Math.max(1, panel.aspect)))
                height: Theme.size.artCompact
                color: Theme.colors.surfaceAlt
                clip: true
                Image {
                    anchors.fill: parent
                    source: art.visible ? Media.art : ""
                    sourceSize: Qt.size(2 * parent.width, 2 * parent.height)
                    fillMode: art.album ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            Column {
                width: parent.width - art.width - parent.spacing
                Txt {
                    id: titleText
                    width: parent.width
                    text: Media.title
                    variant: Theme.font.bodyStrong
                    wrapMode: Text.Wrap
                    maximumLineCount: Theme.control.titleLinesWide
                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered && titleText.truncated) titleTipDelay.restart();
                            else { titleTipDelay.stop(); panel.titleTip = false; }
                        }
                    }
                }
                Txt {
                    visible: text !== ""
                    width: parent.width
                    text: Media.artist
                    color: Theme.colors.textMuted
                }
                Annot {
                    // album · year for music; the site for browser media; the format for a local file
                    readonly property string line: Media.album !== "" ? [Media.album, Media.year].filter(s => s !== "").join(" · ")
                                                   : Media.host !== "" ? Media.host : Media.format
                    visible: line !== ""
                    width: parent.width
                    text: line
                    color: Theme.colors.textFaint
                }
            }
        }

        // ---- The time row ----------------------------------------------------------------------------------------
        // A ruler, straight under the words (its hit area's upper 16 px are the gap), the times under it; the modes
        // (shuffle, repeat) between the times, where there is room for them.
        Item {
            visible: panel.timed
            width: parent.width
            height: times.y + times.height

            RulerSlider {
                id: seek
                width: parent.width
                interactive: panel.seekable
                showHandle: panel.seekable
                accentHandle: false             // the panel's one red thing is play / pause
                value: panel.timed ? panel.player.position / panel.player.length : 0
                onMoved: v => { if (panel.seekable) panel.player.position = v * panel.player.length }
            }
            Item {
                id: times
                y: seek.base + 2 + Theme.space.s1          // the handle's foot is 2 px under the baseline
                width: parent.width
                height: modes.shown ? Theme.size.hitTarget : Theme.font.mono.lineHeight
                Annot {
                    anchors { left: times.left; verticalCenter: times.verticalCenter }
                    text: panel.timed ? Format.clock(panel.player.position) : ""
                }
                Annot {
                    anchors { right: times.right; verticalCenter: times.verticalCenter }
                    text: panel.timed ? "−" + Format.clock(panel.player.length - panel.player.position) : ""
                }
                Modes { id: modes; player: panel.player; canControl: panel.canControl; anchors.centerIn: times }
            }
        }
        // No ruler: a plain rule; under it, for a live stream, ● live (and the time listened when it was measured), and
        // the modes between them, as between a timed track's times.
        Item { visible: panel.hasTrack && !panel.timed; width: 1; height: Theme.space.s3 }
        Rectangle { visible: panel.hasTrack && !panel.timed; width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
        Item {
            visible: panel.hasTrack && !panel.timed && (panel.isLive || untimedModes.shown)
            width: parent.width
            height: status.y + status.height
            Item {
                id: status
                y: Theme.space.s2
                width: parent.width
                height: untimedModes.shown ? Theme.size.hitTarget : Theme.font.mono.lineHeight
                Row {
                    visible: panel.isLive
                    anchors.verticalCenter: status.verticalCenter
                    spacing: Theme.space.s2
                    Mark { anchors.verticalCenter: parent.verticalCenter; kind: "circle" }
                    Annot { text: "live" }
                }
                Annot {
                    visible: panel.live
                    anchors { right: status.right; verticalCenter: status.verticalCenter }
                    text: panel.live ? Format.clock(panel.player.position) : ""
                }
                Modes { id: untimedModes; player: panel.player; canControl: panel.canControl; anchors.centerIn: status }
            }
        }

        // ---- One row: previous, play / pause (the red square), next; the player's own volume in the rest ----
        Item { visible: panel.hasTrack; width: 1; height: Theme.space.s3 }
        Item {
            id: controls
            visible: panel.hasTrack
            width: parent.width
            height: Theme.size.playButton

            Row {
                id: transport
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.s2
                GlyphButton {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Theme.icons.prev
                    enabled: panel.player?.canGoPrevious ?? false
                    onClicked: panel.player.previous()
                }
                Item {
                    id: play
                    readonly property bool can: panel.player?.canTogglePlaying ?? false
                    width: Theme.size.playButton
                    height: Theme.size.playButton
                    focus: true
                    activeFocusOnTab: true                     // even when it cannot act: it may hold the focus as the player goes

                    // The one red square: no border, no hover or pressed colour; it stays the same red.
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.colors.accent
                        opacity: play.can ? 1 : 0.5
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: Media.playing ? Theme.icons.pause : Theme.icons.play
                        color: Theme.colors.textOnAccent
                    }
                    // Keyboard focus: a 2 px ink outline 2 px outside the square (it shows on the red and on the surface).
                    Rectangle {
                        visible: play.activeFocus && panel.keyed
                        anchors { fill: parent; margins: -2 * Theme.size.marker }
                        color: "transparent"
                        border.width: Theme.size.marker
                        border.color: Theme.colors.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: play.can
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.player.togglePlaying()
                    }
                    Keys.onPressed: event => {
                        if (!event.isAutoRepeat) panel.keyed = true;
                        if (play.can && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            panel.player.togglePlaying();
                            event.accepted = true;
                        }
                    }
                }
                GlyphButton {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Theme.icons.next
                    enabled: panel.player?.canGoNext ?? false
                    onClicked: panel.player.next()
                }
            }

            // The player's own volume in the row's rest: the glyph, a ruler meter, 62% (hidden if it ignores a change).
            Item {
                id: volume
                readonly property real level: panel.player?.volume ?? 0
                visible: panel.hasTrack && (panel.player?.volumeSupported ?? false)
                         && !Media.volumeIgnored[panel.player?.dbusName ?? ""]
                anchors { left: transport.right; leftMargin: Theme.space.s4; right: controls.right
                          verticalCenter: controls.verticalCenter }
                height: Theme.size.hitTarget

                Icon {
                    id: volumeGlyph
                    y: volumeMeter.base + 2 - height              // glyph, meter and number stand on one line
                    name: volume.level <= 0 ? Theme.icons.volumeMuted
                        : Theme.icons.volume[volume.level < 0.34 ? 0 : volume.level < 0.67 ? 1 : 2]
                    color: Theme.colors.text
                }
                RulerSlider {
                    id: volumeMeter
                    anchors { left: volumeGlyph.right; leftMargin: Theme.space.s2
                              right: volumeValue.left; rightMargin: Theme.space.s2 }
                    height: parent.height
                    ticks: false
                    accentHandle: false
                    interactive: panel.canControl
                    value: volume.level
                    onMoved: v => panel.setVolume(v)
                }
                Txt {
                    id: volumeValue
                    anchors.right: parent.right
                    y: volumeMeter.base + 2 - height
                    width: widest.advanceWidth
                    horizontalAlignment: Text.AlignRight
                    variant: Theme.font.label
                    text: Math.round(volume.level * 100) + " %"
                    TextMetrics { id: widest; font: volumeValue.font; text: "100 %" }
                }
            }
        }

        // ---- Players, only when there is a choice: the marked one is the bar's ---------------------------------
        Item { visible: Media.players.length > 1; width: 1; height: Theme.space.s6 }
        SectionHead { visible: Media.players.length > 1; title: "Players" }
        Repeater {
            model: Media.players.length > 1 ? panel.ranked : []
            RowItem {
                id: prow
                required property var modelData
                readonly property string pid: Media.idOf(modelData)
                // Two players of one app (two mpv, two browser windows): each also names its track.
                readonly property bool twin: Media.players.filter(p => Media.idOf(p) === pid).length > 1
                radio: true
                checked: modelData === panel.player
                onActivated: Media.choose(modelData)
                Txt {
                    id: playerName
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, playerState.x - Theme.space.s3)
                    text: prow.pid
                }
                Txt {
                    visible: prow.twin
                    anchors { left: playerName.right; leftMargin: Theme.space.s2; right: playerState.left; rightMargin: Theme.space.s3
                              verticalCenter: parent.verticalCenter }
                    text: prow.modelData.trackTitle ?? ""
                    color: Theme.colors.textMuted
                }
                Annot {
                    id: playerState
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: panel.stateWord(prow.modelData)
                }
            }
        }
    }

    // ---- The modes, where the player has them: shuffle, then repeat (off -> repeat -> repeat one) --------
    component Modes: Row {
        id: modesRow
        property var player: null
        property bool canControl: false
        // From the player, not the switches' `visible`: inside a hidden row that reads false, and it would never show.
        readonly property bool shown: (player?.shuffleSupported ?? false) || (player?.loopSupported ?? false)
        visible: shown
        spacing: Theme.space.s1
        Switch {
            visible: modesRow.player?.shuffleSupported ?? false
            enabled: modesRow.canControl
            word: "shuffle"
            checked: modesRow.player?.shuffle ?? false
            onToggled: modesRow.player.shuffle = !modesRow.player.shuffle
        }
        Switch {
            readonly property int loop: modesRow.player?.loopState ?? MprisLoopState.None
            visible: modesRow.player?.loopSupported ?? false
            enabled: modesRow.canControl
            word: loop === MprisLoopState.Track ? "repeat one" : "repeat"
            checked: loop !== MprisLoopState.None
            onToggled: modesRow.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
    }

    // ---- The tooltip: the full title (after the hover delay, when it is cut), or the time under the pointer on the
    // seek ruler (at once). Drawn over the content, inside the panel.
    property bool titleTip: false
    Timer { id: titleTipDelay; interval: Theme.motion.tooltipDelay; onTriggered: panel.titleTip = true }
    TipBox {
        id: tip
        readonly property bool forSeek: seek.hovered && panel.seekable
        readonly property point at: forSeek ? seek.mapToItem(panel, seek.hoverValue * seek.width, seek.base - Theme.ruler.tickValue)
                                            : titleText.mapToItem(panel, titleText.width / 2, titleText.height)
        visible: panel.hasTrack && (forSeek || panel.titleTip)
        x: Math.round(Math.max(0, Math.min(panel.width - width, at.x - width / 2)))
        y: Math.round(forSeek ? at.y - height - Theme.space.s1 : at.y + Theme.space.s1)
        maxWidth: panel.width
        minHeight: Theme.space.s5
        wrap: true                              // the whole title
        text: forSeek ? Format.clock(seek.hoverValue * panel.player.length) : Media.title
    }
}
