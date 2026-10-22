// ~/nixos-config/modules/home-manager/themes/xbox360/shell/LoadingRing.qml
// The console's "please wait" ring: a silver ring with a bright green arc of
// light chasing round it.
import QtQuick
import QtQuick.Shapes

Item {
    id: ring

    property real size: 80
    property bool running: true

    width: size
    height: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // The ring itself.
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.55)
            strokeWidth: ring.size * 0.11
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: ring.size * 0.4; radiusY: ring.size * 0.4
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // The chasing light, rotated as a whole.
    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "#7ce03a"
            strokeWidth: ring.size * 0.11
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: ring.size * 0.4; radiusY: ring.size * 0.4
                startAngle: -90; sweepAngle: 80
            }
        }
        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 1100
            loops: Animation.Infinite
            running: ring.running
        }
    }
}
