import QtQuick
import qs

// What polkit asks (overlays/Polkit), set as a panel (design/panels Parts): an AUTHENTICATION eyebrow on its ruler
// with whose password it wants ("as kishan"), what was asked for in the app's own words, the password field, PAM's
// words under it, "authenticate" and "cancel", and the polkit action in the footer. It follows PAM: the field shows
// only while PAM waits for an answer (between a sent password and the verdict the line reads "checking…"); a wrong
// password comes back as an empty field with the words under it; a password never stays in the field once sent.
// `flow` is Quickshell's polkit AuthFlow, or anything with its properties (a preview).
Column {
    id: prompt
    property var flow: null
    readonly property bool asking: flow?.isResponseRequired ?? false
    readonly property string identity: flow?.selectedIdentity?.displayName ?? ""
    readonly property string question: (flow?.inputPrompt ?? "").replace(/:\s*$/, "").trim().toLowerCase() || "password"
    // PAM's own words beside the question (rare: attempts left, an expired password), unless the failure already says it.
    readonly property string note: flow?.failed ? "" : flow?.supplementaryMessage ?? ""
    readonly property bool noteIsError: flow?.supplementaryIsError ?? false

    width: Theme.panel.column
    spacing: 0

    function focusInput() { if (asking) field.focusInput() }
    function send() {
        if (!asking) return;
        const typed = field.text;
        field.clear();
        flow.submit(typed);
    }
    function cancel() {
        field.clear();
        flow?.cancelAuthenticationRequest();
    }

    // A new question, or another try after a wrong password: the field takes the keys again.
    onAskingChanged: if (asking) Qt.callLater(focusInput)

    SectionHead {
        title: "Authentication"
        annotation: prompt.identity !== "" ? "as " + prompt.identity : ""
    }
    Txt {
        width: parent.width
        text: prompt.flow?.message ?? ""
        wrapMode: Text.Wrap
        maximumLineCount: 4
    }
    Item { width: 1; height: Theme.space.s4 }

    // The field, or "checking…" in its place (same height) while PAM decides.
    Item {
        width: parent.width
        height: prompt.asking ? field.height : Theme.panel.fieldH

        Field {
            id: field
            visible: prompt.asking
            password: true
            reveal: prompt.flow?.responseVisible ?? false
            placeholder: prompt.question
            error: prompt.flow?.failed ? "wrong password — try again" : ""
            onAccepted: prompt.send()
            onCancelled: prompt.cancel()
        }
        Txt {
            visible: !prompt.asking
            height: Theme.panel.fieldH
            text: "checking…"
            color: Theme.colors.textMuted
        }
    }
    ErrorLine {
        visible: prompt.note !== "" && prompt.noteIsError
        text: prompt.note
    }
    Txt {
        visible: prompt.note !== "" && !prompt.noteIsError
        width: parent.width
        topPadding: Theme.space.s1
        text: prompt.note
        color: Theme.colors.textMuted
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
    Item { width: 1; height: Theme.space.s4 }

    // The one primary action, then cancel (as the Wi-Fi password form: "connect", "cancel").
    Row {
        spacing: Theme.space.s4
        TextButton {
            kind: "primary"
            text: "authenticate"
            enabled: prompt.asking
            onClicked: prompt.send()
        }
        TextButton {
            text: "cancel"
            onClicked: prompt.cancel()
        }
    }
    Item { width: 1; height: Theme.space.s3 }

    // Which polkit action this is, as the panels name their backend.
    PanelFooter {
        backend: prompt.flow?.actionId ?? ""
    }
}
