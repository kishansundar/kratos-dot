pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell Swiss on Kratos: the design system in design/swiss/ (README.md, tokens.json, components/*/README.md) set on
// the "Measure" shell. Every colour, size, space, type style, duration and glyph comes from here, mirroring
// design/swiss/tokens.json; nothing literal elsewhere. Kept from Measure by the owner's choice (15 October 2026): the 24-hour
// day ruler on the bar's lower edge, and the clock on the screen's centre, split by its red "now" stroke.
//   colour   neutrals and one red (`accent`); ok / warn / error only for a real state, always with a shape or a word
//   type     Geist for UI text, Geist Mono for metadata and machine text, Swiss Glyphs for icons (design/glyphs)
//   grid     8 px (s2); 4 px (s1) only for optical alignment
//   marks    in ink only: a filled circle = on / selected (a ring = off), a triangle = attention; the red square fill
//            is the one active thing. Shape carries the state; colour never has to.
// Palettes: ~/.config/swiss-desktop/tokens (one source for the shell, mango, kitty, GTK and the lock screen).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // SWISS_DESKTOP_DIR points a test shell at a copy, so its mode and wallpaper switches never touch this desktop.
    readonly property string desktopDir: Quickshell.env("SWISS_DESKTOP_DIR") || home + "/.config/swiss-desktop"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/swiss"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/swiss-desktop"
    // SWISS_DRY_RUN=1 (every test rig): actions on the real machine (Wi-Fi, Bluetooth, the session, processes, the
    // trash) are logged as "DRYRUN ..." instead of done; the rig shares this machine's adapter, link and processes.
    readonly property bool dryRun: Quickshell.env("SWISS_DRY_RUN") === "1"

    // ---- Mode: "light" or "dark", from the file swiss-mode writes ---------------------------
    property string mode: "dark"
    readonly property bool dark: mode !== "light"

    // Switch the whole desktop (shell, mango, GTK, kitty, lock screen) and remember the choice: swiss-mode writes the
    // mode file this shell watches, the dconf colour scheme, and the colour-file links.
    function toggleMode() { Quickshell.execDetached([desktopDir + "/bin/swiss-mode", "toggle"]) }

    // Read before the first frame (blockLoading), so the shell never starts in the wrong mode.
    FileView {
        path: root.stateDir + "/mode"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().trim() === "light" ? "light" : "dark";
            if (m !== root.mode) root.recolour(() => root.mode = m);
        }
    }

    property var lightPalette: ({})
    property var darkPalette: ({})
    FileView {
        path: root.desktopDir + "/build/light/palette.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { const p = JSON.parse(text()); root.recolour(() => root.lightPalette = p); }
            catch (e) { /* mid-rewrite: keep the last good palette */ }
        }
    }
    FileView {
        path: root.desktopDir + "/build/dark/palette.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { const p = JSON.parse(text()); root.recolour(() => root.darkPalette = p); }
            catch (e) { /* mid-rewrite: keep the last good palette */ }
        }
    }
    readonly property var p: dark ? darkPalette : lightPalette

    // A mode or palette change is made with every colour fade off (each `Behavior on color` is `enabled:
    // !Theme.recolouring`): the colours follow it in the same frame as their ground, instead of fading across it from
    // the old palette (a folio tick blinked out for a frame). The bindings follow the change at once, so the fades are
    // off only while it is made; hover and press fades are as before.
    property bool recolouring: false
    function recolour(change) { recolouring = true; change(); recolouring = false; }

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // ---- Colour (tokens.json "color"; the palette files use the desktop's names, mapped here) ------------------
    readonly property QtObject colors: QtObject {
        readonly property color bg: root.p.background ?? "#0d0d0d"          // bar and panel ground
        readonly property color surface: root.p.surface ?? "#161616"        // popups, cards, toasts, OSD
        readonly property color surfaceAlt: root.p.surface2 ?? "#222222"    // hover fill, inactive fill
        readonly property color line: root.p.border ?? "#333333"            // 1 px rules, borders, pressed fill: decorative only
        readonly property color tick: root.p.borderStrong ?? "#6e6e69"      // ruler baselines and ticks (>= 3:1), never text
        readonly property color text: root.p.text ?? "#f2f2ee"              // primary text, icons, the occupied-tag tick
        readonly property color textMuted: root.p.text2 ?? "#a8a8a2"        // secondary text, eyebrows, inactive icons
        readonly property color textFaint: root.p.muted ?? "#8e8e87"        // timestamps, week numbers, empty tags, disabled
        readonly property color accent: root.p.accentFill ?? "#e93f20"      // the one red (the posters'): one thing per view
        // tokens.json "onAccent", renamed: QML reads a property called on<Capital> as a signal handler, and
        // Theme.colors.onAccent came out black (#000000) in both modes.
        readonly property color textOnAccent: root.p.accentFg ?? "#0d0d0d"  // text and icons on an accent fill
        readonly property color ok: root.p.success ?? "#3dbe7a"             // connected / healthy, always with a word or shape
        readonly property color warn: root.p.warning ?? "#e0a030"           // degraded, always with a word or shape
        readonly property color error: root.p.error ?? "#ec5a40"            // critical / failed: the red as text, with a word or icon
        readonly property color selection: root.p.selection ?? "#521f16"    // selected text in fields: the selection GTK, kitty and the editors use
    }

    // ---- States: one rule for every control (README "States and interaction") ---------------------------------
    readonly property QtObject states: QtObject {
        readonly property color hover: root.colors.surfaceAlt
        readonly property color pressed: root.colors.line
        readonly property color focus: root.colors.accent       // keyboard focus: a 2 px outline, inset
        readonly property int focusWidth: 2
        readonly property color disabled: root.colors.textFaint  // disabled text and glyphs; no hover
    }

    readonly property string wallpaper: root.p.wallpaper ? "file://" + home + "/" + root.p.wallpaper : ""

    // ---- Space (tokens.json "spacing"): the only spacing values ----------------------------------------------
    readonly property QtObject space: QtObject {
        readonly property int s0: 0
        readonly property int s1: 4        // optical alignment of icons and text only
        readonly property int s2: 8        // the base unit
        readonly property int s3: 12       // row padding inside lists
        readonly property int s4: 16       // bar side padding, gap between bar modules
        readonly property int s5: 24       // popup inner padding, gap between bar groups
        readonly property int s6: 32       // between panel sections
        readonly property int s7: 48
        readonly property int s8: 64
    }

    // ---- Sizes (tokens.json "size") ----------------------------------------------------------------------------
    readonly property QtObject size: QtObject {
        readonly property int radius: 0            // square everywhere
        readonly property int rule: 1              // hairlines and borders
        readonly property int marker: 2            // state bars: tag ticks, the active row, the critical toast, focus
        readonly property int icon: 16             // the one icon size: Swiss Glyphs are drawn on a 16 px grid
        readonly property int hitTarget: 32        // the least width and height of anything clickable
        readonly property int sliderHandle: 12
        readonly property int mediaArt: 64
        readonly property int popupWidth: 384      // popups, toasts (48 x 8)
        readonly property int launcherWidth: 640   // the clipboard field (80 x 8; the launcher is Theme.launcher.width)
        readonly property int clipThumbW: 192      // an image in the clipboard history, fitted into 192 x 48 (24 x 8 by
        readonly property int clipThumbH: 48       // 6 x 8) and never enlarged, in a row of two hit targets
        readonly property int osdWidth: 240
        readonly property int osdHeight: 48
        readonly property int panelColumns: 6
        readonly property int appIcon: 16          // app icons in the tray and the launcher (Swiss app icons in ink)
        readonly property int markCircle: 8        // the on / selected circle (a ring when off)
        readonly property int markTriangle: 8      // the attention triangle
        readonly property int npTextMax: 192       // the now-playing title slot, at most (about 31 characters)
        readonly property int progressW: 3         // the track progress line on the bar rule (and the tray drawer's reach); 2 until 15 October evening, the owner found it too faint
        // Now Playing panel (design/now-playing/tokens.json "size")
        readonly property int artSize: 128         // the album art, square, radius 0
        readonly property int playButton: 48       // play / pause: the panel's one accent square
        // Not a package token: the compact panel's art (the owner's request, 15 October 2026), this tall beside the
        // words, as wide as its shape makes it, at most artSize (16:9 is 128 x 72).
        readonly property int artCompact: 72
    }

    // ---- The ruler (tokens.json "size": ticks on a 4 px step, 8 px pitch) ---------------------------------------
    readonly property QtObject ruler: QtObject {
        readonly property int tickW: 1
        readonly property int tickMinor: 4         // every pitch; every 10 % of a slider; every hour of the day ruler
        readonly property int tickMajor: 8         // the origin; 0 / 50 / 100 % of a slider; 00, 06, 12, 18 h
        readonly property int tickValue: 16        // a slider's or meter's value tick (marker wide)
        readonly property int fill: 3              // slider and meter fill, centred on the baseline
        readonly property int pitch: 8
        readonly property int short: 32            // a heading ruler: four pitches
        readonly property int tagPitch: 12
        readonly property int tagEmpty: 4
        readonly property int tagOccupied: 12
        readonly property int tagActive: 16
    }

    // ---- The bar (tokens.json barHeight, barPadX, moduleGap, groupGap) -----------------------------------------
    readonly property QtObject bar: QtObject {
        readonly property int height: 32
        // Of its ground: the blurred wallpaper shows through a little (the owner's choice, against the package's
        // "no glass"; 75 % until 15 October evening, then 68 %, as asked). 85 % since 20 October (option B of three
        // rendered, 68 / 85 / solid): at 68 % a poster's red block read as a second red behind the status icons.
        readonly property real opacity: 0.85
        // So its faint text and ticks keep their contrast on that ground (WCAG 2.x AA: text 4.5:1, meaningful non-text
        // 3:1): the wallpaper picker flags a picture whose top strip would push them below.
        readonly property real minTextContrast: 4.5
        readonly property real minTickContrast: 3
        // Also where the day ruler starts and ends, and mango's window gap (8 px everywhere), so window edges stand on
        // the ruler's 00:00 and 24:00. 16 until 15 October evening: the owner chose one 8 px measure for gaps and bar.
        readonly property int padX: 8
        readonly property int moduleGap: 16
        readonly property int groupGap: 24
        // The one baseline: numerals, labels, glyphs and tag ticks all stand on it. Rows 8-23 carry the content (the
        // numerals' and glyphs' 16 px), centred in the bar as in the package's reference; rows 24-31 hold the day ruler's
        // ticks (22 put everything 2 px above the middle).
        readonly property int baseline: 24
        readonly property int iconTop: baseline - 16      // a glyph's 16 px box ends on the baseline
    }

    // ---- Type (tokens.json "type"): use a style, never a raw size -------------------------------------------
    // letterSpacing is in px here (Qt): the token's em value times the size.
    component Style: QtObject {
        property string family: root.font.sans
        property int size: 14
        property int weight: Font.Normal
        property real spacing: 0
        property int lineHeight: 20
        property bool caps: false
    }
    readonly property QtObject font: QtObject {
        readonly property string sans: "Geist"
        readonly property string monoFamily: "Geist Mono"
        readonly property string icon: glyphFont.status === FontLoader.Ready ? glyphFont.name : "Swiss Glyphs"
        readonly property Style display: Style { size: 48; lineHeight: 48; weight: Font.Bold; spacing: -0.96 }   // big numbers
        readonly property Style count: Style { size: 22; lineHeight: 24; weight: Font.Bold; spacing: -0.44 }     // bar numerals
        readonly property Style h1: Style { size: 32; lineHeight: 40; weight: Font.Bold; spacing: -0.48 }        // lead figures
        readonly property Style h2: Style { size: 20; lineHeight: 24; weight: Font.DemiBold; spacing: -0.2 }     // panel titles
        readonly property Style body: Style { size: 14; lineHeight: 20 }                                         // default
        readonly property Style bodyStrong: Style { size: 14; lineHeight: 20; weight: Font.DemiBold }             // body, emphasised: a title, the chosen option
        readonly property Style label: Style { size: 12; lineHeight: 16; weight: Font.Medium; spacing: 0.24 }    // bar text
        readonly property Style labelStrong: Style { size: 12; lineHeight: 16; weight: Font.DemiBold; spacing: 0.24 }  // label, emphasised: values, the chosen segment
        readonly property Style caps: Style { size: 11; lineHeight: 16; weight: Font.DemiBold; spacing: 0.88; caps: true }  // eyebrows
        readonly property Style mono: Style { family: root.font.monoFamily; size: 13; lineHeight: 20 }                 // metadata
        readonly property Style stat: Style { size: 32; lineHeight: 40; weight: Font.DemiBold; spacing: -0.48 }  // dashboard tile values
        // The dashboard's headline figures, at the posters' scale (their headlines are Geist-like bold grotesk set
        // tight; the lock screen's clock is 128): not in design/dashboard's tokens, a render for the owner to judge.
        readonly property Style headline: Style { size: 96; lineHeight: 96; weight: Font.Bold; spacing: -2.88 }
    }
    // Swiss Glyphs, the system's own icon font, loaded from the shell's assets (no install needed; design/glyphs/build.py
    // makes it from design/glyphs/defs.py). A missing font would show empty boxes, so say so in the log.
    FontLoader {
        id: glyphFont
        source: Qt.resolvedUrl("assets/fonts/SwissGlyphs.ttf")
        onStatusChanged: if (status === FontLoader.Error) console.warn("Theme: Swiss Glyphs did not load from", source)
    }

    // ---- Motion (tokens.json "duration"): fades and short moves; reduceMotion sets them all to 0 ----------------
    property bool reduceMotion: false
    // SWISS_MOTION_SCALE stretches the fades and moves below by its factor (a rig sets 5 to see a motion frame by frame).
    readonly property real motionScale: Number(Quickshell.env("SWISS_MOTION_SCALE")) || 1
    function motionMs(d) { return reduceMotion ? 0 : Math.round(d * motionScale) }
    readonly property QtObject motion: QtObject {
        readonly property int fast: root.motionMs(120)     // hover, colour, theme switch
        readonly property int med: root.motionMs(180)      // popups: opacity and an 8 px slide
        readonly property int slow: root.motionMs(240)     // the OSD fade
        readonly property int slide: 8
        readonly property int drawer: root.motionMs(180)   // the tray drawer opening
        // Not a token: a popover's move and resize from one module to the next (PanelHost), Caelestia's "spatial"
        // motion without its overshoot.
        readonly property int spatial: root.motionMs(200)
        readonly property int marqueeHold: 1500    // a long title rests this long before it scrolls
        readonly property int marqueeSpeed: 32     // px per second, linear
        readonly property int marqueeGap: 48       // px between the title and its repeat
        readonly property int tooltipDelay: 450
        readonly property int toast: 5000
        readonly property int osd: 1200
        // Now Playing panel (design/now-playing/tokens.json "duration"); not motion, so reduceMotion leaves them
        readonly property int positionTick: 1000   // the position is read this often, only while the panel is open
        readonly property int seekStep: 5000       // ← / → in the panel
        readonly property int liveProbe: 3000      // a position must move this long, with no length, to be "live"
        // Dashboard (design/dashboard/tokens.json "duration"): sampled only while the overlay is open
        readonly property int refreshFast: 1000    // cpu, gpu, network, threads, temperatures
        readonly property int refreshSlow: 5000    // disks, processes, services, jobs
        readonly property int historyWindow: 600000 // the charts' ten minutes, kept in memory while the shell runs
        // The owner's choice (15 October 2026), not a token: what changes slowly is read every 30 s while the dashboard is
        // open (services, timers, Tailscale, the filesystems) instead of every refreshSlow.
        readonly property int refreshIdle: 30000
    }

    // ---- Controls (design/now-playing and design/dashboard tokens.json "control") -------------------------------
    readonly property QtObject control: QtObject {
        readonly property int volumeStep: 5        // % per ↑ / ↓ or wheel notch on a player's own volume
        readonly property int titleLines: 3        // a track title wraps to this many lines, then an ellipsis
        readonly property int titleLinesWide: 2    // ... beside video art, or with none
        readonly property real artWideRatio: 16 / 9    // the video frame (336 x 189)
        readonly property real artSquareMin: 0.8   // art between these aspect ratios is album art; wider is video
        readonly property real artSquareMax: 1.25
        readonly property int nightTempDefault: 4000   // K
        readonly property int nightTempMin: 2500
        readonly property int nightTempMax: 6500
        readonly property int nightTempStep: 100
        readonly property var holdOptions: ["30m", "1h", "2h", "off"]   // caffeine and do not disturb; off = until off
        readonly property var holdMinutes: ({ "30m": 30, "1h": 60, "2h": 120, "off": 0 })
    }

    // ---- Dashboard thresholds (design/dashboard/tokens.json "threshold") ---------------------------------------
    readonly property QtObject threshold: QtObject {
        readonly property int cpuTempWarn: 80      // °C
        readonly property int cpuTempCrit: 90
        readonly property int gpuTempWarn: 80
        readonly property int gpuTempCrit: 90
        readonly property int memWarn: 85          // % (memory and vram)
        readonly property int diskWarn: 85
        readonly property int diskCrit: 95
    }

    // ---- Dashboard v2, the instrument sheet (design/dashboard/tokens.json "size") -----------------------------------
    // One 1152 px panel (3 x popupWidth), 24 px inside: 1104 px of content on four 258 px columns with 24 px gutters.
    readonly property QtObject dash: QtObject {
        readonly property int width: 1152          // the panel, centred on the screen
        readonly property int margin: 24           // inside it
        readonly property int col: 258             // one of the four columns
        readonly property int gutter: 24
        readonly property int bandCols: 4
        readonly property int sectionGap: 32       // between the vitals and the lower band
        readonly property int vitalRowH: 40        // one vital: label and value, ruler, sparkline, metadata
        readonly property int vitalSparkH: 24      // its sparkline
        readonly property int listRow: 32          // the lower band's rows (processes, storage, controls)
        readonly property int sparkW: 96
        readonly property int strokeData: 2
        readonly property int dotD: 8
        readonly property int tipW: 192
    }

    // ---- Chart colours (design/dashboard/tokens.json "color"): identity only, never status; text never wears them --
    // Mirrored from the package; nothing draws with them since dashboard v2 (the instrument sheet is ink only). seq is
    // the one-hue ramp, flipped in dark so low values recede into the ground.
    readonly property QtObject chart: QtObject {
        readonly property color series1: root.dark ? "#3987e5" : "#2a78d6"     // blue
        readonly property color series2: root.dark ? "#d55181" : "#e87ba4"     // magenta (2.69:1 in light: keep labels)
        readonly property color series3: "#008300"                             // green
        readonly property color series4: root.dark ? "#9085e9" : "#6250d6"     // violet
        readonly property var seq: root.dark
            ? ["#0d366b", "#184f95", "#256abf", "#3987e5", "#6da7ec", "#9ec5f4", "#cde2fb"]
            : ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b"]
        readonly property color inkWash: root.dark ? "#14f2f2ee" : "#0f111111"        // #AARRGGBB
        readonly property color series1Wash: root.dark ? "#1f3987e5" : "#1a2a78d6"
    }

    // ---- Glyphs: which symbol means what (Glyphs.qml, generated from design/glyphs/defs.py) ---------------------
    readonly property QtObject icons: QtObject {
        readonly property string claude: "svg:claude"        // Claude's own mark (the owner's choice), filled with ink
        readonly property var wifi: [Glyphs.wifi0, Glyphs.wifi1, Glyphs.wifi2, Glyphs.wifi3, Glyphs.wifi4]  // bars lit
        readonly property string wifiOff: Glyphs.wifiOff
        readonly property string lan: Glyphs.lan
        readonly property string lanOff: Glyphs.lanOff
        readonly property string bluetooth: Glyphs.bluetooth
        readonly property string bluetoothOn: Glyphs.bluetoothConnected
        readonly property string bluetoothOff: Glyphs.bluetoothOff
        readonly property var volume: [Glyphs.volume0, Glyphs.volume1, Glyphs.volume2]
        readonly property string volumeMuted: Glyphs.volumeMute
        readonly property string mic: Glyphs.mic
        readonly property string micOff: Glyphs.micOff
        readonly property string bell: Glyphs.bell
        readonly property string bellUnread: Glyphs.bellUnread
        readonly property string bellOff: Glyphs.bellOff
        readonly property string theme: Glyphs.theme
        readonly property string brightness: Glyphs.brightness  // the monitor's brightness (bar, Display panel, OSD)
        readonly property string power: Glyphs.power
        readonly property string awake: Glyphs.awakeDot        // keep awake on: a filled circle (the owner's pick)
        readonly property string awakeOff: Glyphs.awakeDotOff  // keep awake off: a ring, the screen may sleep
        readonly property string play: Glyphs.play
        readonly property string pause: Glyphs.pause
        readonly property string next: Glyphs.next
        readonly property string prev: Glyphs.prev
        readonly property string lock: Glyphs.lock
        readonly property string error: Glyphs.error
        readonly property string close: Glyphs.close
        readonly property string search: Glyphs.search
        readonly property string headphones: Glyphs.headphones
        readonly property string chevronLeft: Glyphs.chevronLeft
        readonly property string chevronRight: Glyphs.chevronRight
        readonly property string drawerOpen: Glyphs.chevronRight     // the tray drawer's toggle, 16 px like its neighbours
        readonly property string drawerClosed: Glyphs.chevronLeft
        readonly property string noIcon: Glyphs.squareOff        // an app whose icon is not installed (the launcher): a plain square
    }

    // ---- Panels (design/panels/tokens.json): the popups hung from the bar ---------------------------------------
    // Swiss's tokens unchanged plus the panels' own geometry, timeouts and defaults. Every panel is an SPopup
    // (overlays/PanelHost, components/Card): `width` wide with s5 padding, so its content column is `column`; the
    // power menu is narrower. Sections are s6 apart, each opening with an eyebrow and its ruler.
    readonly property QtObject panel: QtObject {
        readonly property int width: root.size.popupWidth            // 384: every panel but the power menu
        readonly property int column: width - 2 * root.space.s5      // 336
        readonly property int powerWidth: 240                       // the power menu
        readonly property int powerColumn: powerWidth - 2 * root.space.s5   // 192
        readonly property int notifWidth: root.size.popupWidth                       // the notification centre
        readonly property int sectionGap: root.space.s6             // between sections
        readonly property int fieldH: 32                            // a text field (a Wi-Fi password)
        readonly property int miniMeter: 32                         // a device's battery ruler
        readonly property int listMax: 320                          // a list scrolls inside its panel past this
        readonly property int scanTimeout: 30000                    // Wi-Fi and Bluetooth scan only while open, this long
        readonly property int connectTimeout: 20000                 // a connect or pair attempt gives up after this
        readonly property int answerDelay: 1000                     // a pairing request takes no answer until shown this long (the owner's choice, 20 October 2026; not in the package)
        readonly property int powerCountdown: 5000                  // log out, reboot, shut down: the visible countdown
        readonly property int undo: 5000                            // clear all can be undone this long (README)
        readonly property int volumeStep: 5                         // % per arrow key or wheel notch
        readonly property int volumeMax: 100                        // sliders stop here (over-amplification: settings)
        readonly property int notifBodyLines: 2                     // a notification's body, then an ellipsis
        readonly property int notifGroupMax: 3                      // items shown per app, then "+N more"
        readonly property int peersMax: 8                           // Tailscale peers before the list scrolls
        // network: its own tokens below this line
        readonly property int tailscaleRefresh: 5000                // Tailscale's state, again, while the panel is open

        // notifications, date and time, power: their own tokens below this line
        readonly property int notifImage: 32                        // a notification's image, square-cropped (README)
        readonly property int notifListMax: 640                     // the history scrolls past this (80 x 8; not in the package)
        readonly property int historyMax: 100                       // records kept across restarts (not in the package)
        readonly property int clocksMax: 5                          // world clocks: UTC plus up to four more (README)
        readonly property int nightFrom: 22                         // a world clock reads "(night)" from 22:00 ...
        readonly property int nightTo: 7                            // ... to 06:59 (README)
        readonly property int keyCap: 20                            // the power menu's keys, drawn as keys (the owner's choice)
        readonly property int countdownStep: 50                     // ms between redraws of the draining countdown ruler
    }

    // ---- Display (design/display/tokens.json): monitor brightness over DDC/CI -----------------------------------
    // Swiss's tokens unchanged (the OSD is size.osdWidth x size.osdHeight and fades over motion.slow) plus DDC timing
    // and the brightness steps. A DDC write takes a tenth of a second and can fail: the Display panel says "setting…"
    // until the monitor reads it back; the OSD and the keys show a step at once (the owner's choice).
    readonly property QtObject display: QtObject {
        readonly property int step: 5                               // per key press, wheel notch or arrow key, in %
        readonly property var presets: [25, 50, 75, 100]            // one-click values under the slider, in % of max
        readonly property int floor: 0                              // the keys go down to this (DDC never turns it off)
        readonly property int settle: 300                           // presses inside this merge into one write
        readonly property int timeout: 2000                         // a write not read back by then has failed
        readonly property int osdHold: root.motion.osd              // 1200, the volume OSD's too: the OSD stays this long after the last change
        readonly property int pendingTick: 8                        // the faint tick at the confirmed value while sending
        // Not a package token (the package has no detection): with no DDC/CI monitor found, the least time between one
        // detection and the next, after 1, 2 and 3+ that found none (services/Brightness: on events only, never a poll).
        readonly property var redetect: [5000, 30000, 300000]
    }

    // ---- Tray row (design/tray-row/tokens.json): the chevron, Claude and keep-awake ------------------------------
    // Swiss's tokens unchanged plus the gap that ends the row and its tooltips' delay. The row's cells are the bar's
    // 32 px slots with 16 px icons: an app in the Swiss app icons (design/app-icons) in ink, any other in its own colours.
    readonly property QtObject trayRow: QtObject {
        // Between the tray row and Wi-Fi in the package. Not used: the owner wants the row to run straight into Wi-Fi
        // (bar/Status).
        readonly property int rowGap: 16
        readonly property int tipDelay: 500    // hover time before a tray-row tooltip shows
    }

    // ---- Launcher (design/launcher/tokens.json): the app launcher, hung from the bar under the NixOS mark ------------
    // Swiss's tokens unchanged plus the launcher's geometry and matching (services/AppMatch.js). The query sits on a
    // ruler the launcher's width whose ink fill is the share of apps still matching; rows are rowH, maxRows of them
    // before the list scrolls.
    readonly property QtObject launcher: QtObject {
        readonly property int width: 576           // launcherWidth: a name and its generic name on one line (72 x 8)
        readonly property int fieldH: 56           // the query row: h2 standing on its ruler
        readonly property int rowH: 40             // a result row: 14 px name, 16 px icon, room to scan
        readonly property int maxRows: 8           // rows shown before the list scrolls (8 x 40 = 320)
        readonly property int recentCount: 6       // recent apps shown for an empty query
        readonly property int fuzzyMin: 2          // initials and in-name matching start at this many letters
        readonly property int altReveal: 250       // hold Alt this long before the row numbers show (a quick Alt+n works)
        readonly property int underlineOffset: 3   // a matched letter's 2 px (marker) underline starts this far under the baseline (README)
        // The calculator ("=", this shell's addition; not in the package)
        readonly property int calcSettle: 150      // qalc is asked this long after typing pauses
        readonly property int calcLimit: 500       // ms qalc may spend on one sum (its -m), so 2^1e9 never stalls
    }

    // ---- The dock (design/dock tokens.json) ----------------------------------------------------------------------
    readonly property QtObject dock: QtObject {
        readonly property int cellW: 64            // one cell around a 48 px app icon (8 grid units)
        readonly property int cellH: 80            // the dock's height: 16 top, 48 icon, 4, 2 px running bar, 10 (the owner's pick; package: 12, 48, 8, 2, 10)
        readonly property int icon: 48             // the tile each app stands on (the owner's pick, 16 October 2026)
        readonly property int pictogram: 36        // the icon on it: the Swiss 48 px masters at 3/4 (their 4 px grid lands on whole px)
        readonly property int padX: 8              // inside left and right
        readonly property int groupGap: 16         // between pinned apps, running-only apps and the trash (a 1 px rule in it)
        readonly property int mark: 16             // the running bar under an icon: 16 x 2 px, ink
        readonly property int lift: 8              // from the dock's top edge to the hover name label
        readonly property int slide: root.motion.drawer            // 180; show: slide up cellH and fade in; hide: at once
        readonly property int hoverDelay: 150      // the name label after hovering this long (Cell README)
        readonly property int menuWidth: 192       // the right-click menu (s7 x 4)
        readonly property int maxPinned: 10        // pinned apps before the dock stops growing and scrolls
        readonly property bool showRunning: true   // running apps that aren't pinned follow the pinned group
    }

    // ---- Busy indicator (the owner's busy-indicator package, 16 October 2026; its README "States", "Geometry") ----
    // The 16 px mark after the app id in the bar's title (kitty's states, any app starting): icon size, space.s2
    // either side; services/Busy, components/BusyMark.
    readonly property QtObject busy: QtObject {
        readonly property int showAfter: 800       // a command shorter than this never shows
        readonly property int doneHold: 3000       // the check stays this long once you can see it
        readonly property int failHold: 8000       // the error mark stays this long once you can see it
        readonly property int step: 150            // the scanner: one tick a step, six steps a sweep (0.9 s)
        readonly property int launchShowAfter: 400 // an app whose window opens sooner never shows "starting"
        readonly property int launchTimeout: 15000 // no window by then: "starting" goes quietly (tray apps, Steam)
        readonly property int launchRefocus: 500   // the launched app's own window regaining focus this soon is not it
    }
}
