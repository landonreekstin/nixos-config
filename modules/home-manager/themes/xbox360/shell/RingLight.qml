// ~/nixos-config/modules/home-manager/themes/xbox360/shell/RingLight.qml
// The controller's ring of light, in every frame's header beside the clock:
// four quarters round a silver ring, the top-left one lit green (player 1)
// on the display that has focus, all of them dark on the others. Arriving
// focus lights it on the console's tempo with a brief flare.
import QtQuick
import QtQuick.Shapes
import "Config.js" as Cfg

Item {
    id: ring

    property real size: 24
    property bool lit: false

    width: size
    height: size

    property real glow: lit ? 1 : 0
    Behavior on glow { NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier } }
    onLitChanged: if (lit) flare.restart()

    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    readonly property color off: Qt.rgba(0.18, 0.18, 0.18, 0.55)
    readonly property color dim: Qt.rgba(0.85, 0.85, 0.85, 0.55)
    readonly property color green: "#7ce03a"

    // The flare: a soft green halo that swells and fades as focus lands.
    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: ring.size * 1.9
        height: width
        radius: width / 2
        color: ring.green
        opacity: 0
        scale: 0.6
    }
    ParallelAnimation {
        id: flare
        NumberAnimation { target: halo; property: "opacity"; from: 0.45; to: 0; duration: Cfg.motionMs * 2 }
        NumberAnimation { target: halo; property: "scale"; from: 0.6; to: 1.2; duration: Cfg.motionMs * 2 }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // The silver ring the four lights sit in.
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.35)
            strokeWidth: ring.size * 0.24
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: ring.size * 0.38; radiusY: ring.size * 0.38
                startAngle: 0; sweepAngle: 360
            }
        }
    }
    // Quarters clockwise from the top left; quarter 0 is player 1.
    Repeater {
        model: 4
        delegate: Shape {
            id: quarter
            required property int index
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: quarter.index === 0 ? ring.mixColor(ring.off, ring.green, ring.glow)
                                                 : ring.mixColor(ring.off, ring.dim, ring.glow)
                strokeWidth: ring.size * 0.14
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.size / 2; centerY: ring.size / 2
                    radiusX: ring.size * 0.38; radiusY: ring.size * 0.38
                    startAngle: 180 + 90 * quarter.index + 12
                    sweepAngle: 66
                }
            }
        }
    }
}
