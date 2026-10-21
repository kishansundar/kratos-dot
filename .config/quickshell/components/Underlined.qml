import QtQuick
import qs

// Text with some letters underlined, not bolded (design/launcher Row: the letters a query matched), so the text keeps
// one weight: a `marker` (2 px) line in ink under each run of marked letters, underlineOffset under the baseline.
// One line; a run the elision hides is not drawn.
Txt {
    id: label
    property var marks: []                  // indices into `text`, ascending

    // Consecutive marks joined into runs: [from, to) pairs.
    readonly property var runs: {
        const out = [];
        for (const i of marks) {
            const last = out[out.length - 1];
            if (last && last[1] === i) last[1] = i + 1;
            else out.push([i, i + 1]);
        }
        return out;
    }

    Repeater {
        model: label.runs
        Item {
            id: run
            required property var modelData
            TextMetrics { id: before; font: label.font; text: label.text.slice(0, run.modelData[0]) }
            TextMetrics { id: through; font: label.font; text: label.text.slice(0, run.modelData[1]) }
            Rectangle {
                x: Math.round(before.advanceWidth)
                width: Math.round(through.advanceWidth) - x
                y: Math.round(label.baselineOffset) + Theme.launcher.underlineOffset
                height: Theme.size.marker
                visible: x + width <= label.width
                color: Theme.colors.text
            }
        }
    }
}
