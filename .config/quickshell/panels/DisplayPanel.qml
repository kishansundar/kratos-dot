import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// Display (design/display DisplayPanel): the monitor's own brightness and contrast over DDC/CI, and the night light.
// Opened from the sun in the bar, hung under it (the brightness keys show the OSD instead).
//   heading      "Display"; the model and connector in mono ("PG279Q · DP-2"; two monitors: "2 monitors")
//   BRIGHTNESS   its state at the right ("setting…" while a value is on its way); the sun, the ruler slider and the
//                value ("47 %"); presets 25 / 50 / 75 / 100 beneath (the one matching gets a 2 px ink underline)
//   CONTRAST     the same slider, the value as "92/150"; only if the monitor offers it (VCP 0x12)
//   night light  a full-width row under a 1 px rule: the circle, "off · 4500 K" (the dashboard's switch, same state)
//   footer       "DDC/CI · i2c-7" in mono, faint, for when something misbehaves
// With two DDC monitors, one block per monitor, its model as the eyebrow and its connector at the right, s6 apart.
// Nothing is shown as set until the monitor reads it back (services/Brightness): a slider sends on release, a preset at
// once; ↑ / ↓ step 5 % and merge into one write. A failed write: the error glyph, "PG279Q didn't answer", retry.
// No red here: brightness has no primary action. Values are read when the panel opens; nothing polls.
// Keys: Tab moves between the sliders and presets, ↑ / ↓ step the focused slider, Esc closes.
Column {
    id: panel
    width: Theme.panel.column
    focus: true

    Component.onCompleted: Brightness.refresh()

    readonly property var monitors: Brightness.monitors
    readonly property bool two: monitors.length > 1

    Heading {
        title: "Display"
        annotation: panel.two ? panel.monitors.length + " monitors"
            : panel.monitors.length === 1 ? panel.monitors[0].model + " · " + panel.monitors[0].connector
            : Brightness.silent.length > 0 ? Brightness.silent.join(" · ") : ""
    }
    Item { width: 1; height: Theme.space.s5 }

    // No monitor to talk to: say why, in one sentence.
    Txt {
        visible: !Brightness.ready
        width: parent.width
        wrapMode: Text.Wrap
        maximumLineCount: 3
        text: Brightness.state === "unknown" ? "Looking for monitors …"
            : Brightness.state === "missing" ? "Brightness needs ddcutil, which isn't installed. Add it to the NixOS packages and rebuild."
            : "This monitor doesn't answer DDC/CI. Use its own buttons for brightness."
        color: Theme.colors.textMuted
    }

    // By index, not modelData: a Repeater hands its delegates a copy of each object, which would freeze the values
    // at the moment the panel opened. Brightness.monitors[i] is the service's own, live object.
    Repeater {
        model: panel.monitors.length
        Column {
            id: block
            required property int index
            readonly property var m: panel.monitors[index]
            visible: Brightness.revision >= 0 && m.read      // unread, its values are placeholders (Brightness.ready)
            width: panel.width
            topPadding: index > 0 ? Theme.panel.sectionGap : 0

            SectionHead {
                title: panel.two ? block.m.model : "Brightness"
                annotation: Brightness.revision >= 0 && block.m.b.state === "sending" ? "setting…" : panel.two ? block.m.connector : ""
            }
            LevelRow {
                index: block.index
                vcp: "10"
                ctl: block.m.b
                glyph: Theme.icons.brightness
            }
            // Presets: they send at once. The one matching the value on its way (or the confirmed one) is underlined.
            Row {
                x: Theme.size.icon + Theme.space.s3
                spacing: Theme.space.s4
                Repeater {
                    model: Theme.display.presets
                    Item {
                        id: preset
                        required property int modelData
                        readonly property bool on: Brightness.percent(block.m.b, Brightness.shown(block.m.b)) === modelData
                        width: button.width
                        height: button.height
                        TextButton {
                            id: button
                            text: String(preset.modelData)
                            color: preset.on ? Theme.colors.text : Theme.colors.textMuted
                            onClicked: Brightness.setPercent(block.index, "10", preset.modelData)
                        }
                        Rectangle {
                            visible: preset.on
                            anchors { bottom: parent.bottom; bottomMargin: Theme.space.s1 }
                            width: parent.width
                            height: Theme.size.marker
                            color: Theme.colors.text
                        }
                    }
                }
            }
            FailLine { index: block.index; vcp: "10"; ctl: block.m.b; model: block.m.model }

            // Contrast, when the monitor offers it.
            Item { visible: Brightness.revision >= 0 && block.m.c !== null; width: 1; height: Theme.space.s4 }
            SectionHead {
                visible: Brightness.revision >= 0 && block.m.c !== null
                title: "Contrast"
                annotation: Brightness.revision >= 0 && block.m.c && block.m.c.state === "sending" ? "setting…" : ""
            }
            LevelRow {
                visible: Brightness.revision >= 0 && block.m.c !== null
                index: block.index
                vcp: "12"
                ctl: Brightness.revision >= 0 ? block.m.c : null
            }
            FailLine { index: block.index; vcp: "12"; ctl: Brightness.revision >= 0 ? block.m.c : null; model: block.m.model }
        }
    }

    // ---- Night light: the dashboard's switch, the same state -------------------------------------------------
    Item { width: 1; height: Theme.space.s5 }
    Rectangle { width: parent.width; height: Theme.size.rule; color: Theme.colors.line }
    RowItem {
        inset: 0
        radio: true
        checked: NightLight.on
        enabled: !NightLight.unsupported
        onActivated: NightLight.setOn(!NightLight.on)
        Txt {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Night light"
        }
        Annot {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: NightLight.unsupported ? "not supported" : (NightLight.on ? "on" : "off") + " · " + NightLight.temp + " K"
        }
    }

    // ---- Footer: where the values come from ----------------------------------------------------------------
    Item { width: 1; height: Theme.space.s4 }
    Annot {
        width: parent.width
        text: "DDC/CI" + (panel.monitors.length > 0 ? " · " + panel.monitors.map(m => "i2c-" + m.bus).join(" · ") : "")
        color: Theme.colors.textFaint
    }

    // One control: the glyph (or its space), the ruler slider, the value.
    component LevelRow: Item {
        id: row
        property int index: 0
        property string vcp: "10"
        property var ctl: null
        property string glyph: ""
        readonly property int rev: Brightness.revision
        width: panel.width
        height: Theme.size.hitTarget
        Item {
            anchors.fill: parent
            Icon {
                id: icon
                visible: row.glyph !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: row.glyph
            }
            DdcSlider {
                id: slider
                anchors { left: parent.left; leftMargin: Theme.size.icon + Theme.space.s3; right: value.left; rightMargin: Theme.space.s3
                          verticalCenter: parent.verticalCenter }
                value: row.rev >= 0 && row.ctl && row.ctl.max > 0 ? row.ctl.value / row.ctl.max : 0
                pending: row.rev >= 0 && row.ctl && row.ctl.target >= 0 && row.ctl.max > 0 ? row.ctl.target / row.ctl.max : -1
                onReleased: v => Brightness.set(row.index, row.vcp, v * row.ctl.max)
                onStepped: steps => Brightness.nudge(row.index, row.vcp, steps)
            }
            // The value, in a column as wide as the widest any row shows ("150/150"), so a slider never moves and every
            // row's slider ends on one line.
            TextMetrics { id: widest; font.family: Theme.font.label.family; font.pixelSize: Theme.font.label.size; text: "150/150" }
            Row {
                id: value
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: Math.ceil(widest.advanceWidth) + Theme.space.s1
                layoutDirection: Qt.RightToLeft
                readonly property color ink: slider.unconfirmed ? Theme.colors.textMuted : Theme.colors.text
                Txt {
                    visible: row.vcp === "12"
                    variant: Theme.font.label
                    text: row.ctl ? "/" + row.ctl.max : ""
                    color: Theme.colors.textFaint
                }
                Txt {
                    variant: Theme.font.labelStrong
                    text: row.rev < 0 || !row.ctl ? "" : slider.dragging ? (row.vcp === "10" ? Math.round(slider.drag * 100) + " %" : Math.round(slider.drag * row.ctl.max))
                        : row.vcp === "10" ? Brightness.percent(row.ctl, Brightness.shown(row.ctl)) + " %" : String(Brightness.shown(row.ctl))
                    color: value.ink
                }
            }
        }
    }
    // A write the monitor never confirmed: the control is back at the confirmed value; say so, and offer the same again.
    component FailLine: Item {
        id: fail
        property int index: 0
        property string vcp: "10"
        property var ctl: null
        property string model: ""
        visible: Brightness.revision >= 0 && ctl !== null && ctl.state === "failed"
        width: panel.width
        height: Theme.size.hitTarget
        Item {
            anchors.fill: parent
            Icon {
                id: errGlyph
                anchors.verticalCenter: parent.verticalCenter
                name: Theme.icons.error
                color: Theme.colors.error
            }
            Annot {
                anchors { left: errGlyph.right; leftMargin: Theme.space.s2; right: retry.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                text: fail.model + " didn't answer"
                color: Theme.colors.error
            }
            TextButton {
                id: retry
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                kind: "framed"
                text: "retry"
                onClicked: Brightness.retry(fail.index, fail.vcp)
            }
        }
    }
}
