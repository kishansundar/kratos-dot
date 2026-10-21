import QtQuick
import qs

// Text in one of the type styles (Theme.font.<style>: body by default; count, label, caps, h2, h1, display, mono).
// Tabular figures always, so changing numbers never shift. A style is used whole: never set a raw size.
Text {
    property QtObject variant: Theme.font.body
    font.family: variant.family
    font.pixelSize: variant.size
    font.weight: variant.weight
    font.letterSpacing: variant.spacing
    font.capitalization: variant.caps ? Font.AllUppercase : Font.MixedCase
    font.features: { "tnum": 1 }
    color: Theme.colors.text
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    maximumLineCount: 1
    textFormat: Text.PlainText
}
