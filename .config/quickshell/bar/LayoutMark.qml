import QtQuick
import qs
import qs.components
import qs.services

// The focused tag's layout (Layout), beside its numeral in the tag ruler: a plan of the panes mango arranges, in 1 px
// rules, 17 x 13 px standing on the bar's baseline (a pixel over an occupied tick, a screen's proportion). Every split is
// whole on that grid: halves 7 | 7 inside the frame, thirds 3 / 3 / 3, a master of 8 against a stack of 6 (mango's
// 0.55). In textMuted, as the inactive glyphs: the numeral and the ticks are the ink. The owner's pick A of four
// rendered on 20 October 2026 (over mango's symbol "DW" and the name in mono, and 8 px text under the numeral, which
// is all the room the day ruler leaves there):
//   1 ┌──┬─┐ ┃ ı · · ·      tile: master | stack of three   dwindle: halves of halves   monocle: the frame alone
//     │  ├┬┤                scroller: a column, its neighbours cut off by the frame's open sides   grid: 2 x 2 …
//     └──┴┴┘
// Tooltip: the layout's name. Click: the next layout of config.conf's circle_layout (switch_layout, also Super+N).
// The wheel steps tags, as anywhere on the ruler.
BarSlot {
    id: mark
    required property string symbol           // mango's layout_symbol: "DW"
    readonly property string name: Mango.layoutName(symbol)
    signal stepped(int steps)

    padding: Theme.space.s2
    tooltip: "Layout · " + (name !== "" ? name.replace(/_/g, " ") : symbol) + " · click or Super+N: next"
    onClicked: button => { if (button === Qt.LeftButton) Mango.nextLayout() }
    onScrolled: steps => mark.stepped(steps)

    // Rules [x, y, w, h] in the 17 x 13 box, frame included.
    readonly property int planW: 17
    readonly property int planH: 13
    function rules(name) {
        const W = planW, H = planH;
        const v = (x, y0, y1) => [x, y0 ?? 0, 1, (y1 ?? H - 1) - (y0 ?? 0) + 1];
        const h = (y, x0, x1) => [x0 ?? 0, y, (x1 ?? W - 1) - (x0 ?? 0) + 1, 1];
        const frame = [h(0), h(H - 1), v(0), v(W - 1)];
        switch (name) {
        case "tile":              return frame.concat([v(9), h(4, 9), h(8, 9)]);          // master | stack of three
        case "right_tile":        return frame.concat([v(7), h(4, 0, 7), h(8, 0, 7)]);   // stack | master
        case "vertical_tile":     return frame.concat([h(7), v(8, 7)]);                   // master over a stack of two
        case "center_tile":       return frame.concat([v(4), v(12)]);                     // stack | master | stack
        case "dwindle":           return frame.concat([v(8), h(6, 8), v(12, 6)]);         // halves of halves
        case "deck":              return frame.concat([v(9), h(3, 11), v(11, 3)]);        // master | cards
        case "vertical_deck":     return frame.concat([h(7), v(3, 9), h(9, 3)]);
        case "grid":
        case "vertical_grid":     return frame.concat([v(8), h(6)]);
        case "fair":              return frame.concat([v(8)]);
        case "vertical_fair":     return frame.concat([h(6)]);
        case "scroller":          return [h(0), h(H - 1), v(3), v(13)];                   // a strip running on past both sides
        case "vertical_scroller": return [v(0), v(W - 1), h(2), h(10)];
        default:                  return frame;                                           // monocle: one pane
        }
    }

    Item {
        width: mark.planW
        height: Theme.bar.height
        Repeater {
            model: mark.rules(mark.name)
            Rectangle {
                required property var modelData
                x: modelData[0]
                y: Theme.bar.baseline - mark.planH + modelData[1]
                width: modelData[2]
                height: modelData[3]
                color: Theme.colors.textMuted
            }
        }
    }
}
