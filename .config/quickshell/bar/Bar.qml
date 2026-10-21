import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// The bar along the top of one screen (Bar): 32 px, its ground 85 % opaque over mango's blur, composed on one
// baseline (Theme.bar.baseline, 24 px from the top) with 8 px padding (Theme.bar.padX, mango's window gap), and ending
// in the 24-hour day ruler:
//
//   ❄  ı ı ┃ ı · · · · ·  kitty nvim — desktop.nix     Thursday 20 ┃ 34 15 October   zen Title — Artist ⏮⏸⏭  ‹  ● ✱ ᯤ ᛒ ☀ ◁)) ⍾ ◐  ⏻
//   ├━━━━━━━━━━━━━━━━━━━━━━━━ the day so far ━━━━━━━━━━━━━━━━━━━━━━━━┼──────────────┼──────────────┼──────────────┤
//
// Left group: the NixOS mark (the launcher; right click: the dashboard) on the ruler's origin, the tag ruler, the
// focused window (app id in mono, the busy mark for kitty or an app starting, title in label, muted, elided at 40 % of
// the bar; the full title in a tooltip). Centre (kept from "Measure"): the clock, its stroke on the screen's exact
// centre. Right: now playing, the tray drawer, the status glyphs, power.
// No rules but the bottom one; groups are 24 px of space apart, modules 16.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData
    readonly property var mon: Mango.monitor(modelData.name)

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.bar.height
    color: Theme.tint(Theme.colors.bg, Theme.bar.opacity)
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "swiss-bar"
    // While the tray drawer is open the bar takes the keyboard on demand (when clicked), so Esc closes the drawer.
    WlrLayershell.keyboardFocus: Panels.trayOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Item {
        focus: true
        Keys.onEscapePressed: Panels.trayOpen = false
    }

    // Keep awake (services/Caffeine): the bar is always mapped, so its inhibitor holds while the switch is on (the cup
    // in bar/Status, Super+Alt+C, the dashboard's Caffeine switch).
    IdleInhibitor {
        window: bar
        enabled: Caffeine.on
    }

    DayRuler {
        x: Theme.bar.padX
        width: bar.width - 2 * Theme.bar.padX
        height: Theme.bar.height
    }

    // ---- Left -------------------------------------------------------------------------------------
    // The mark opens the launcher, which hangs from it with its left edge on the mark (design/launcher); a right click
    // opens the dashboard (also Super+D), so it keeps a way in by mouse. The mark is the Swiss two-tone NixOS mark
    // (components/NixMark, the owner's nixos-two-tone-bar package, 15 October 2026): 24 px, centred in its 32 px cell
    // on whole pixels, its box starting on the padding, over the ruler's 00:00 (the origin tick). It replaced the 18 px
    // vector mark whose arms alternated red and ink, which broke into confetti at this size.
    BarSlot {
        id: machine
        readonly property int markSize: 24
        x: Theme.bar.padX - (Theme.size.hitTarget - markSize) / 2
        fixedWidth: Theme.size.hitTarget
        hangLeft: (Theme.size.hitTarget - markSize) / 2
        panel: "launcher"
        tooltip: "Apps · Super+Space · right click: dashboard"
        onClicked: button => { if (button === Qt.RightButton) Panels.toggle("dashboard", machine) }
        NixMark {
            id: logo
            size: machine.markSize
            x: Theme.bar.padX - machine.x
            y: Math.round((Theme.bar.height - size) / 2)
        }
    }

    Folio {
        id: folio
        // moduleGap from the mark to the tag numeral (- 1: the numeral's own 1 px side bearing).
        x: Theme.bar.padX + logo.size + Theme.bar.moduleGap - 1
        monitor: bar.mon
    }

    Item {
        id: context
        readonly property var client: bar.mon ? bar.mon.active_client : null
        // The app id, short: "org.gnome.Nautilus" -> "nautilus", ".piper-wrapped" -> "piper".
        function shortId(id) {
            return id ? String(id).replace(/^\./, "").replace(/-wrapped$/, "").split(".").pop().toLowerCase() : "";
        }
        readonly property string appId: client ? shortId(client.appid) : ""
        readonly property string title: client ? trimTitle(client.title ?? "", appId, client.appid) : ""
        // An app's own name ending its title ("Geist font research - Claude — Zen Browser") says what the app id
        // already does: it goes when it contains the app id or is the app's name (the owner's choice, 16 October 2026).
        function trimTitle(t, id, appid) {
            const m = String(t).match(/^(.*\S)\s+[—–-]\s+([^—–-]+)$/);
            if (!m || id === "") return t;
            const tail = m[2].trim().toLowerCase();
            const e = DesktopEntries.heuristicLookup(appid);
            return tail.includes(id) || (e && tail === String(e.name).toLowerCase()) ? m[1] : t;
        }
        // An app just started (services/Busy; the owner's busy-indicator package) stands in for the focused window, on
        // the focused screen's bar, until its own window opens: its id, the scanner, its name.
        readonly property bool launching: Busy.launching
            && (Mango.focused === "" || Mango.focused === bar.modelData.name)
        readonly property string shownId: launching ? shortId(Busy.launchId) : appId
        readonly property string shownTitle: launching ? Busy.launchName : title
        // moduleGap from the last tag's ink, not its 12 px cell (whose 5 px beside the tick made this gap 5 px wider
        // than the logo -> folio and folio -> tags gaps).
        x: folio.x + folio.width - (Theme.ruler.tagPitch - Theme.size.marker) / 2 + Theme.bar.moduleGap
        width: Math.max(0, Math.min(bar.width * 0.4, clock.x - x - Theme.bar.groupGap))
        height: Theme.bar.height
        visible: shownId !== ""
        clip: true

        Annot {
            id: appLabel
            anchors { baseline: parent.top; baselineOffset: Theme.bar.baseline }
            width: Math.min(implicitWidth, 160)
            text: context.shownId
        }
        // The busy mark (services/Busy): 16 px with space.s2 either side, for an app starting (the scanner) and for
        // kitty (its states). Only while it shows something: an idle kitty reads "kitty ~" like any app, and the title
        // moves aside for the mark (the owner's choice, 16 October 2026, over the package's slot kept while idle). Its
        // tooltip says what and how long.
        BusyMark {
            id: busyMark
            readonly property string tipText: context.launching ? Busy.launchDetail : Busy.detail
            visible: context.launching || (context.appId === "kitty" && mode !== "idle")
            x: appLabel.x + appLabel.width + Theme.space.s2
            // Centred on the title's text: midway between its capitals' middle and its lowercase's, above the baseline
            // (row 20 of the bar with Geist at the label size: H 9 px, x 7 px; the owner's choice over the icon line,
            // row 16). Qt's FontMetrics has no capHeight: the ink of "H" and "x" stands in.
            y: {
                titleFont.font;
                const cap = titleFont.tightBoundingRect("H").height, ex = titleFont.tightBoundingRect("x").height;
                return Theme.bar.baseline - Math.round((cap + ex) / 4) - height / 2;
            }
            FontMetrics { id: titleFont; font: titleText.font }
            mode: context.launching ? "working" : Busy.kittyActive ? Busy.status : "idle"
            HoverHandler {
                id: busyHover
                onHoveredChanged: {
                    if (hovered && busyMark.tipText !== "") bar.showTip(busyMark, busyMark.tipText);
                    else bar.hideTip(busyMark);
                }
            }
            // The tooltip follows the running clock, and goes with the mark.
            onTipTextChanged: {
                if (!busyHover.hovered) return;
                if (tipText === "") bar.hideTip(busyMark);
                else if (bar.tipOwner === busyMark) tip.text = tipText;
                else bar.showTip(busyMark, tipText);
            }
        }
        Txt {
            id: titleText
            anchors { left: busyMark.visible ? busyMark.right : appLabel.right; leftMargin: Theme.space.s2; right: parent.right; baseline: parent.top; baselineOffset: Theme.bar.baseline }
            variant: Theme.font.label
            text: context.shownTitle
            color: Theme.colors.textMuted
        }
        // A cut title: the whole of it in a tooltip.
        HoverHandler {
            id: titleHover
            onHoveredChanged: {
                if (busyHover.hovered && busyMark.tipText !== "") return;    // the busy mark's tooltip, not the title's
                if (hovered && titleText.truncated) bar.showTip(context, context.shownTitle);
                else bar.hideTip(context);
            }
        }
    }

    // ---- Centre -----------------------------------------------------------------------------------
    Clock {
        id: clock
        x: Math.round(bar.width / 2 - strokeX)
    }

    // ---- Right ------------------------------------------------------------------------------------
    // The power glyph's ink ends on the padding, over the ruler's 24:00, as the mark's starts on it over 00:00: padX
    // (8 px) from either screen edge. Its drawing stops 1.5 px inside its 16 px box, hence the 1 px.
    Status {
        id: status
        anchors { right: parent.right; rightMargin: Theme.bar.padX - (Theme.size.hitTarget - Theme.size.icon) / 2 - 1 }
    }

    // Now playing: right of the clock, against the status group (24 px of space); it never reaches the clock.
    NowPlaying {
        anchors.right: status.left
        anchors.rightMargin: Theme.bar.groupGap - 2 * Theme.space.s2
        maxWidth: Math.max(0, Math.min(420, status.x - (clock.x + clock.width) - 2 * Theme.space.s6))
    }

    // ---- Tooltip: one per bar, under the hovered control after a short delay ---------------------------
    // The tip belongs to the control that asked last. Moving straight from one control to its neighbour, the new one
    // enters before the old one leaves: the old one's leave must not cancel the new one's tip.
    property Item tipOwner: null
    function showTip(item, text, delay) {
        const p = item.mapToItem(null, 0, 0);
        tipOwner = item;
        tipDelay.interval = delay > 0 ? delay : Theme.motion.tooltipDelay;
        tip.text = text;
        tip.anchor.rect.x = p.x;
        tip.anchor.rect.width = item.width;
        if (tip.visible) tip.anchor.updateAnchor();
        else tipDelay.restart();
    }
    function hideTip(item) {
        if (item && item !== tipOwner) return;
        tipOwner = null;
        tipDelay.stop();
        tip.visible = false;
    }
    Timer {
        id: tipDelay
        interval: Theme.motion.tooltipDelay
        onTriggered: tip.visible = Panels.current === ""
    }
    Connections {
        target: Panels
        function onCurrentChanged() { bar.hideTip() }
    }

    PopupWindow {
        id: tip
        property string text: ""
        anchor.window: bar
        anchor.rect.y: Theme.bar.height + Theme.space.s1
        anchor.rect.height: 1
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: tipBox.implicitWidth
        implicitHeight: tipBox.implicitHeight
        color: "transparent"
        visible: false

        TipBox {
            id: tipBox
            anchors.fill: parent
            text: tip.text
            minHeight: Theme.space.s5
        }
    }
}
