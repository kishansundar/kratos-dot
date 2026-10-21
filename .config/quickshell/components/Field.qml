import QtQuick
import qs

// A text field (design/panels Parts): fieldH tall, a 1 px line border on the bg ground, Geist Mono; keyboard focus a
// 2 px accent outline, inset. `error` (words): the border turns error and the words stand under the field with the error
// glyph (ErrorLine). `password`: dots unless `reveal`. Enter emits accepted(), Esc cancelled(). The text is never
// logged or kept anywhere else.
Column {
    id: field
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool reveal: false
    property string error: ""
    property var validator: null
    signal accepted()
    signal cancelled()

    function focusInput() { input.forceActiveFocus() }
    function clear() { input.text = "" }

    width: parent ? parent.width : 0
    spacing: Theme.space.s1

    Rectangle {
        width: parent.width
        height: Theme.panel.fieldH
        color: Theme.colors.bg
        border.width: Theme.size.rule
        border.color: field.error !== "" ? Theme.colors.error : Theme.colors.line

        TextInput {
            id: input
            anchors { fill: parent; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
            verticalAlignment: TextInput.AlignVCenter
            echoMode: field.password && !field.reveal ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            font.family: Theme.font.mono.family
            font.pixelSize: Theme.font.mono.size
            font.features: { "tnum": 1 }
            color: Theme.colors.text
            selectionColor: Theme.colors.selection
            selectedTextColor: Theme.colors.text
            selectByMouse: true
            renderType: Text.NativeRendering
            validator: field.validator
            clip: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) field.cancelled();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) field.accepted();
                else return;
                event.accepted = true;
            }
            Txt {
                anchors.fill: parent
                visible: input.text.length === 0
                variant: Theme.font.mono
                text: field.placeholder
                color: Theme.colors.textFaint
            }
        }
        // Keyboard focus: the 2 px accent outline, inside the field's edge.
        FocusRing { visible: input.activeFocus }
    }
    ErrorLine {
        visible: field.error !== ""
        text: field.error
    }
}
