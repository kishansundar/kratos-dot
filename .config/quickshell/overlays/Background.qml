import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// The desktop picture of one screen, chosen by the mode (tokens wallpaper=). The background colour shows
// while it loads or if the file is missing. Decoded at the screen's size, not the file's.
//
// Each picture is a layer of its own: a new one decodes out of sight on top of the old and then fades in over it
// (motion.slow), and only then do the layers under it go. So a new picture, and every light / dark switch (each
// mode has its own), crosses straight from the old one, never through the bare background colour. A picture still
// decoding when another is asked for is dropped. One that cannot be read, or no picture at all, fades out what is
// there to the background colour.
PanelWindow {
    id: window
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "swiss-background"
    color: Theme.colors.bg

    readonly property string source: Theme.wallpaper
    // A layer made before the window has its size would decode the file at full size first.
    readonly property bool sized: stage.width > 0 && stage.height > 0
    onSourceChanged: show()
    onSizedChanged: show()

    function show() {
        if (!sized) return;
        const layers = stage.children;
        const top = layers.length > 0 ? layers[layers.length - 1] : null;
        if (top && !top.leaving && String(top.source) === source) return;
        for (const l of layers) if (!l.settled) l.destroy();
        if (source === "") {
            for (const l of layers) if (l.settled) l.leave();
            return;
        }
        pictureLayer.createObject(stage, { source: source });
    }
    // The layers under `over` once it is fully shown, or every layer when a picture fails.
    function clearUnder(over) {
        for (const l of stage.children) {
            if (l === over) return;
            l.destroy();
        }
    }
    function clearAll() {
        for (const l of stage.children) l.leave();
    }

    Item {
        id: stage
        anchors.fill: parent
    }

    Component {
        id: pictureLayer

        Image {
            id: picture
            property bool settled: false
            property bool leaving: false
            function leave() {
                leaving = true;
                fadeIn.stop();
                fadeOut.start();
            }

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(stage.width, stage.height)
            asynchronous: true
            cache: false
            smooth: true
            opacity: 0

            onStatusChanged: {
                if (settled || leaving) return;
                if (status === Image.Ready) {
                    settled = true;
                    fadeIn.start();
                } else if (status === Image.Error) {
                    settled = true;
                    console.warn("Background: cannot load", source);
                    window.clearAll();
                }
            }

            NumberAnimation {
                id: fadeIn
                target: picture; property: "opacity"; to: 1
                duration: Theme.motion.slow; easing.type: Easing.OutCubic
                onFinished: window.clearUnder(picture)
            }
            NumberAnimation {
                id: fadeOut
                target: picture; property: "opacity"; to: 0
                duration: Theme.motion.slow; easing.type: Easing.OutCubic
                onFinished: picture.destroy()
            }
        }
    }
}
