// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Toast.qml
// The console's toast: a dark glass pill rising at the bottom centre of the
// screen with the Xbox ring of light and two lines of text, gone after a few
// seconds. Never takes input; shows over everything, games included.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "Config.js" as Cfg

PanelWindow {
    id: win

    readonly property real s: Math.min(screen.width / 1280, screen.height / 720)
    readonly property var t: Notifications.toast
    property var shown: null
    onTChanged: if (t !== null) shown = t

    anchors { bottom: true }
    margins.bottom: 60 * s
    implicitWidth: 520 * s
    implicitHeight: 76 * s
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    visible: pill.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "xbox360-toast"

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        y: win.t !== null ? 0 : parent.height * 0.6
        opacity: win.t !== null ? 1 : 0
        radius: height / 2
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.55)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.22, 0.22, 0.22, 0.94) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.06, 0.06, 0.94) }
        }
        Behavior on y { NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier } }
        Behavior on opacity { NumberAnimation { duration: Cfg.motionMs } }

        // The ring of light, or the sender's own icon in it.
        Rectangle {
            id: ring
            x: 12 * win.s
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 20 * win.s
            height: width
            radius: width / 2
            color: "#2b2b2b"
            border.width: width * 0.12
            border.color: "#6fc23c"
            Image {
                anchors.centerIn: parent
                width: parent.width * 0.56
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                source: {
                    const n = win.shown;
                    if (!n) return "";
                    if (n.image !== "") return n.image;
                    return n.appIcon !== "" ? Quickshell.iconPath(n.appIcon, true) : "";
                }
            }
        }

        Column {
            x: ring.x + ring.width + 14 * win.s
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 30 * win.s
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: win.shown ? win.shown.summary : ""
                font.family: Cfg.font
                font.pixelSize: 21 * win.s
                color: "white"
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: win.shown ? (win.shown.body !== "" ? win.shown.body.replace(/<[^>]*>/g, "").split("\n")[0] : win.shown.appName) : ""
                font.family: Cfg.font
                font.pixelSize: 17 * win.s
                color: "#c8c8c8"
            }
        }
    }
}
