// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeHeader.qml
// The open blade's header and footer bands. The header holds its title on
// the left, as on the console; the footer — the console's button-legend band —
// carries the gamertag on the left and the clock on the right. Text is
// regular weight and white with a soft shadow.
import QtQuick
import Quickshell
import "Config.js" as Cfg
import "Geometry.js" as Geo

Item {
    id: header

    property string title
    property bool forward: true
    property real panelL
    property real panelR
    property real sx: 1
    property real sy: 1

    // Inner x of the panel's curved edges at reference height y.
    function leftAt(y) { return (panelL - Geo.curve(y)) * sx; }
    function rightAt(y) { return (panelR + Geo.curve(y)) * sx; }

    readonly property real titleY: Cfg.titleCentre * sy
    readonly property real footerY: (Cfg.footerTop + 720) / 2 * sy

    component BandText: Text {
        font.family: Cfg.font
        color: "white"
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.28)
    }

    // The title lands from the direction of travel: 28 reference px off,
    // fading in over one tempo after a third-of-a-tempo delay, so the chrome
    // is seen moving first.
    Item {
        id: titleBox
        x: header.leftAt(Cfg.titleCentre) + Cfg.titleInset * header.sx
        y: header.titleY - titleText.implicitHeight / 2
        width: titleText.implicitWidth
        height: titleText.implicitHeight

        BandText {
            id: titleText
            text: header.title
            font.pixelSize: Cfg.titleSize * header.sy
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

    BandText {
        id: gamertag
        text: Cfg.gamertag
        font.pixelSize: Cfg.footerSize * header.sy
        x: header.leftAt(700) + Cfg.titleInset * header.sx
        y: header.footerY - implicitHeight / 2
        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }

    BandText {
        id: time
        text: Qt.formatTime(clock.date, "h:mm AP")
        font.pixelSize: Cfg.footerSize * header.sy
        x: header.rightAt(700) - Cfg.titleInset * header.sx - implicitWidth
        y: header.footerY - implicitHeight / 2
        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }
}
