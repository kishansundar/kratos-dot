import QtQuick
import qs

// A failure in words (design/panels: "Read the truth back"): the error glyph, then the message in body, in the error
// colour, wrapping to two lines. Never colour alone: the glyph and the words carry it.
Item {
    id: line
    property string text: ""
    property color color: Theme.colors.error

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.size.hitTarget, words.implicitHeight + 2 * Theme.space.s1)
    height: implicitHeight

    Icon {
        id: glyph
        y: words.y + Math.round((Theme.font.body.lineHeight - height) / 2)
        name: Theme.icons.error
        color: line.color
    }
    Txt {
        id: words
        anchors { left: glyph.right; leftMargin: Theme.space.s2; right: parent.right }
        y: Math.round((line.height - implicitHeight) / 2)
        height: implicitHeight
        verticalAlignment: Text.AlignTop
        wrapMode: Text.Wrap
        maximumLineCount: 2
        lineHeightMode: Text.FixedHeight
        lineHeight: Theme.font.body.lineHeight
        text: line.text
        color: line.color
    }
}
