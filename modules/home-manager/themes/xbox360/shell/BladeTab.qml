// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeTab.qml
// One collapsed blade tab: a curved ribbon, silver when collapsed and the
// blade's own colour when it is the open blade's tab, with its name running
// down it. The clickable area is the ribbon's real curved shape.
import QtQuick
import QtQuick.Shapes
import "Config.js" as Cfg
import "Geometry.js" as Geo

Item {
    id: tab

    property int k
    property string title
    property real topX          // left edge's top x, reference units
    property real mirror: 1     // -1 left stack, +1 right stack
    property real weight: 0     // 0 silver .. 1 blade colour
    property var tabStops       // blade's own tab gradient, 3 hex stops
    property real sx: 1
    property real sy: 1

    signal hovered()
    signal activated()

    function c(h) { return Qt.color("#" + h); }
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    // Both fills on the same four stop positions, so a tab can blend between
    // collapsed silver and the blade colour as it crosses into place.
    readonly property var silver: Cfg.silver.tab.map(c)
    readonly property var bladeFill: {
        const s = tabStops.map(c);
        return [s[0], s[1], mixColor(s[1], s[2], 0.5), s[2]];
    }
    function fill(i) { return mixColor(silver[i], bladeFill[i], weight); }

    readonly property real labelY: 64
    readonly property real centreX: (topX + mirror * Geo.curve(labelY) + Cfg.tabWidth / 2) * sx

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        containsMode: Shape.FillContains

        ShapePath {
            strokeColor: Qt.rgba(0.94, 0.94, 0.94, 0.85)
            strokeWidth: 1.2
            fillGradient: LinearGradient {
                x1: tab.topX * tab.sx
                y1: 0
                x2: (tab.topX + Cfg.tabWidth) * tab.sx
                y2: 0
                GradientStop { position: 0.0;  color: tab.fill(0) }
                GradientStop { position: 0.32; color: tab.fill(1) }
                GradientStop { position: 0.62; color: tab.fill(2) }
                GradientStop { position: 1.0;  color: tab.fill(3) }
            }
            PathPolyline {
                path: Geo.ribbon(tab.topX, tab.mirror, tab.topX + Cfg.tabWidth, tab.mirror, tab.sx, tab.sy)
            }
        }
    }

    // The name, rotated to read top to bottom.
    Text {
        id: label
        text: tab.title
        font.family: Cfg.font
        font.pixelSize: Cfg.tabLabelSize * tab.sy
        color: area.containsMouse || tab.weight > 0.5 ? "white" : "#" + Cfg.silver.label
        style: tab.weight > 0.5 ? Text.Raised : Text.Normal
        styleColor: Qt.rgba(0, 0, 0, 0.25)
        rotation: 90
        transformOrigin: Item.TopLeft
        x: tab.centreX + height / 2
        y: (tab.labelY - 34) * tab.sy
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        containmentMask: shape
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tab.hovered()
        onClicked: tab.activated()
    }
}
