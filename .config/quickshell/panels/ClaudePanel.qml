import QtQuick
import Quickshell
import qs
import qs.components
import qs.services
import "../services/Format.js" as Format

// Claude Code (click its mark in the bar, or Super+Ctrl+K): what Claude Code reports (plan limits, each session's
// context and cost) and what the local logs say today (an estimate), kept apart and labelled; a value that is not
// reported says so. The logs are read only while this is open. Read-only: nothing here sends anything to Claude Code.
// In the order you act on it, one section each:
//   PLAN LIMITS   five-hour and weekly use with their resets (Pro / Max plans): account-wide, so the newest report from
//                 any session is right for them
//   SESSIONS      one line per session (from its own report, never mixed): name, context used; model, cost, age
//   TODAY         token counts summed from the local session logs: an estimate, labelled as one
// Costs are Claude Code's own list-price estimates.
Column {
    id: panel
    width: Theme.panel.column
    focus: true

    Component.onCompleted: ClaudeUsage.watching = true
    Component.onDestruction: ClaudeUsage.watching = false

    Heading {
        title: "Claude Code"
        annotation: !ClaudeUsage.installed ? "not installed"
            : ClaudeUsage.local ? ClaudeUsage.local.active + (ClaudeUsage.local.active === 1 ? " active session" : " active sessions") : ""
    }
    Item { width: 1; height: Theme.space.s5 }

    Column {
        id: section
        width: parent.width
        spacing: 0

        readonly property var r: ClaudeUsage.report
        readonly property var l: ClaudeUsage.local
        readonly property real now: ClaudeUsage.now / 1000

        function resetNote(w) {
            if (!w || !w.resets_at) return "";
            const left = w.resets_at - section.now;
            return left > 0 ? "resets in " + Format.span(left) + " · " + Qt.formatDateTime(new Date(w.resets_at * 1000), "ddd HH:mm")
                            : "window has reset since this report";
        }
        function ago(t) { const s = section.now - t; return s < 60 ? "just now" : Format.span(s) + " ago" }

        // ---- Plan limits ------------------------------------------------------------------------------
        SectionHead { title: "Plan limits"; annotation: ClaudeUsage.reportAge >= 0 ? "reported " + section.ago(ClaudeUsage.reportAt) : "" }
        Txt {
            visible: !section.r
            width: parent.width
            text: "No report yet"
            color: Theme.colors.textMuted
        }
        Annot {
            visible: !section.r
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            text: "Claude Code sends it through its status line after each message (scripts/claude-statusline.sh)"
        }
        Meter {
            visible: !!ClaudeUsage.limits?.five_hour
            label: "Five-hour limit"
            value: (ClaudeUsage.limits?.five_hour?.used_percentage ?? -100) / 100
            note: section.resetNote(ClaudeUsage.limits?.five_hour)
            near: ClaudeUsage.near(ClaudeUsage.limits?.five_hour)
        }
        Item { visible: !!ClaudeUsage.limits?.five_hour && !!ClaudeUsage.limits?.seven_day; width: 1; height: Theme.space.s2 }
        Meter {
            visible: !!ClaudeUsage.limits?.seven_day
            label: "Weekly limit"
            value: (ClaudeUsage.limits?.seven_day?.used_percentage ?? -100) / 100
            note: section.resetNote(ClaudeUsage.limits?.seven_day)
            near: ClaudeUsage.near(ClaudeUsage.limits?.seven_day)
        }
        Annot {
            visible: !!section.r && !ClaudeUsage.limits
            width: parent.width
            text: "not reported (Pro / Max plans, after a message)"
        }

        // ---- Sessions ---------------------------------------------------------------------------------
        Item { width: 1; height: Theme.space.s6 }
        SectionHead { title: "Sessions"; annotation: "context · list-price cost" }
        Annot {
            visible: ClaudeUsage.sessions.length === 0
            width: parent.width
            text: "no session has reported yet"
        }
        Repeater {
            model: ClaudeUsage.sessions
            Item {
                id: srow
                required property var modelData
                readonly property bool recent: section.now - modelData.at < 300
                width: parent.width
                height: 44
                Txt {
                    id: sname
                    anchors { left: parent.left; right: pct.left; rightMargin: Theme.space.s3; top: parent.top }
                    height: Theme.font.body.lineHeight
                    text: srow.modelData.name
                    color: srow.recent ? Theme.colors.text : Theme.colors.textMuted
                }
                Txt {
                    id: pct
                    anchors { right: parent.right; baseline: sname.baseline }
                    variant: Theme.font.labelStrong
                    text: srow.modelData.context === null ? "–" : Math.round(srow.modelData.context) + " %"
                    color: srow.recent ? Theme.colors.text : Theme.colors.textMuted
                }
                Annot {
                    anchors { left: parent.left; right: parent.right; top: sname.bottom }
                    height: Theme.font.mono.lineHeight
                    text: [srow.modelData.model,
                           srow.modelData.cost === null ? "" : "≈ $" + srow.modelData.cost.toFixed(2),
                           section.ago(srow.modelData.at)].filter(s => s !== "").join(" · ")
                }
            }
        }

        // ---- Today, from the local logs ------------------------------------------------------------------
        Item { width: 1; height: Theme.space.s6 - Theme.space.s2 }
        SectionHead {
            title: "Today"
            annotation: "local logs, an estimate" + (ClaudeUsage.localAt > 0 ? " · " + Qt.formatTime(new Date(ClaudeUsage.localAt * 1000), "HH:mm") : "")
        }
        Txt {
            visible: ClaudeUsage.localError !== ""
            width: parent.width
            text: "Unavailable: " + ClaudeUsage.localError
            color: Theme.colors.textMuted
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
        Annot {
            visible: !!section.l && section.l.ok
            width: parent.width
            text: ClaudeUsage.tokens(section.l?.day?.input) + " in · " + ClaudeUsage.tokens(section.l?.day?.output) + " out"
            color: Theme.colors.text
        }
        Annot {
            visible: !!section.l && section.l.ok
            width: parent.width
            text: "cache  " + ClaudeUsage.tokens(section.l?.day?.cacheRead) + " read · " + ClaudeUsage.tokens(section.l?.day?.cacheWrite) + " written"
            color: Theme.colors.text
        }
        Annot {
            visible: !!section.l && section.l.ok
            width: parent.width
            text: (section.l?.day?.responses ?? 0) + " responses in " + (section.l?.day?.sessions ?? 0) + " sessions"
        }
    }

    Item { width: 1; height: Theme.space.s4 }
    Item {
        width: parent.width
        height: Theme.size.hitTarget
        Annot { anchors.verticalCenter: parent.verticalCenter; text: "esc close"; color: Theme.colors.textFaint }
        TextButton {
            anchors.right: parent.right
            text: "New session"
            hint: "↗"
            onClicked: { Panels.close(); Quickshell.execDetached(["kitty", "-e", "claude"]); }
        }
    }
}
