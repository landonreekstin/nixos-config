// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeHeader.qml
// The open blade's header band: its title on the left of the panel, the
// gamertag and clock on the right. Titles are regular weight and white with a
// soft shadow, as on the console.
import QtQuick
import Quickshell
import "Config.js" as Cfg

Item {
    id: header

    property string title
    property bool forward: true
    property real panelL
    property real panelR
    property real sx: 1
    property real sy: 1

    readonly property real bandTop: Cfg.contentTop * sy

    // The title lands from the direction of travel: 28 reference px off,
    // fading in over one tempo after a third-of-a-tempo delay, so the chrome
    // is seen moving first.
    Item {
        id: titleBox
        x: (header.panelL + Cfg.titleInset) * header.sx
        y: header.bandTop
        width: titleText.implicitWidth
        height: titleText.implicitHeight

        Text {
            id: titleText
            text: header.title
            font.family: Cfg.font
            font.pixelSize: Cfg.titleSize * header.sy
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.28)
        }

        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }

    onTitleChanged: land.restart()
    SequentialAnimation {
        id: land
        PropertyAction { target: titleText; property: "opacity"; value: 0 }
        PropertyAction { target: titleText; property: "x"; value: (header.forward ? 28 : -28) * header.sx }
        PauseAnimation { duration: Cfg.motionMs / 3 }
        ParallelAnimation {
            NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: Cfg.motionMs }
            NumberAnimation {
                target: titleText; property: "x"; to: 0; duration: Cfg.motionMs
                easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: status
        spacing: 18 * header.sx
        anchors.right: parent.right
        anchors.rightMargin: parent.width - (header.panelR - Cfg.titleInset) * header.sx
        y: header.bandTop + (titleText.implicitHeight - height) / 2

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }

        Text {
            text: Cfg.gamertag
            font.family: Cfg.font
            font.pixelSize: Cfg.statusSize * header.sy
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.28)
        }
        Text {
            text: Qt.formatTime(clock.date, "h:mm AP")
            font.family: Cfg.font
            font.pixelSize: Cfg.statusSize * header.sy
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.28)
        }
    }
}
