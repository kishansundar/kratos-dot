import QtQuick
import qs

// The Swiss two-tone NixOS mark, from the owner's nixos-two-tone-bar package (Swiss Glyphs 1.7; its two shapes ported
// into this font as nixos-rest and nixos-accent): five arms in ink with the sixth, top left, in the accent on top, in
// one box. One red arm follows the one-accent rule and reads at 24 px as a single red stroke; the NixOS split (red and
// ink by turns, the old components/Logo) broke into confetti at bar size. 24 in the bar; never two-tone below 24 (Glyphs.nixos,
// one colour, there). Drawn unhinted (Qt's own rendering, not the glyphs' NativeRendering) so the thin arms keep the
// official shape instead of snapping to the pixel grid. Geometry: NixOS snowflake, nixos-artwork, CC-BY 4.0.
Item {
    id: mark
    property int size: 24
    property color ink: Theme.colors.text
    property color accent: Theme.colors.accent
    implicitWidth: size
    implicitHeight: size

    component Layer: Text {
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        font.family: Theme.font.icon
        font.pixelSize: mark.size
        lineHeightMode: Text.FixedHeight
        lineHeight: mark.size
    }
    Layer { text: Glyphs.nixosRest; color: mark.ink }        // five arms
    Layer { text: Glyphs.nixosAccent; color: mark.accent }   // one arm, on top
}
