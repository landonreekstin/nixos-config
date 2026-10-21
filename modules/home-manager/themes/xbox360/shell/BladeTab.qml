// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeTab.qml
// One blade band, as on the console: a full-height curved band, silver when
// collapsed and the blade's own colour when it is the open blade's, with a
// darker label box on its inner side — a rounded top corner, an S-step back
// into the band near the bottom — and the blade's name in lowercase running
// down it. The clickable area is the band's real curved shape.
import QtQuick
import QtQuick.Shapes
import "Config.js" as Cfg
import "Geometry.js" as Geo

Item {
    id: tab

    property int k
    property string title
    property real topX          // band's left edge at the top, reference units
    property real bandWidth: Cfg.tabPitch
    property real mirror: 1     // -1 left stack, +1 right stack
    property real weight: 0     // 0 silver .. 1 blade colour
    property var blade          // the blade's palette entry (stops, tab, ink)
    property real sx: 1
    property real sy: 1

    signal hovered()
    signal activated()

    function c(h) { return Qt.color("#" + h); }
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }
    function blend(silver, coloured, i) { return mixColor(c(silver[i]), coloured[i], weight); }

    // Band and box fills on the same four stop positions, so a band can blend
    // from collapsed silver to the blade colour as it crosses into place.
    readonly property var bandColoured: {
        const s = blade.tab.map(c);
        return [s[0], s[1], mixColor(s[1], s[2], 0.5), s[2]];
    }
    readonly property var boxColoured: {
        const s = blade.stops.map(c);
        return [s[1], s[0], s[0], s[1]];
    }

    readonly property real boxTop: Cfg.tabBoxTop + (Cfg.tabBoxTopActive - Cfg.tabBoxTop) * weight
    readonly property bool leftStack: mirror < 0
    readonly property real strip: bandWidth * Cfg.tabBoxInset

    // Box centre line at the label's height, in screen px.
    readonly property real labelRefY: boxTop + 12
    readonly property real boxCentreX: {
        const outerTop = leftStack ? topX + strip : topX + bandWidth - strip;
        const innerTop = leftStack ? topX + bandWidth : topX;
        return (Geo.edgeX((outerTop + innerTop) / 2, mirror, labelRefY + 40)) * sx;
    }

    Shape {
        id: shape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        containsMode: Shape.FillContains

        // The band, with the dark line the console draws between bands.
        ShapePath {
            strokeColor: Qt.rgba(0.30, 0.30, 0.30, 0.75)
            strokeWidth: 1.4
            fillGradient: LinearGradient {
                x1: tab.topX * tab.sx
                y1: 0
                x2: (tab.topX + tab.bandWidth) * tab.sx
                y2: 0
                GradientStop { position: 0.0;  color: tab.blend(Cfg.silver.tab, tab.bandColoured, 0) }
                GradientStop { position: 0.32; color: tab.blend(Cfg.silver.tab, tab.bandColoured, 1) }
                GradientStop { position: 0.62; color: tab.blend(Cfg.silver.tab, tab.bandColoured, 2) }
                GradientStop { position: 1.0;  color: tab.blend(Cfg.silver.tab, tab.bandColoured, 3) }
            }
            PathPolyline {
                path: Geo.ribbon(tab.topX, tab.mirror, tab.topX + tab.bandWidth, tab.mirror, tab.sx, tab.sy)
            }
        }

        // The label box.
        ShapePath {
            strokeColor: Qt.rgba(0.35, 0.35, 0.35, 0.55)
            strokeWidth: 1
            fillGradient: LinearGradient {
                x1: tab.topX * tab.sx
                y1: 0
                x2: (tab.topX + tab.bandWidth) * tab.sx
                y2: 0
                GradientStop { position: 0.0;  color: tab.blend(Cfg.silver.box, tab.boxColoured, 0) }
                GradientStop { position: 0.32; color: tab.blend(Cfg.silver.box, tab.boxColoured, 1) }
                GradientStop { position: 0.62; color: tab.blend(Cfg.silver.box, tab.boxColoured, 2) }
                GradientStop { position: 1.0;  color: tab.blend(Cfg.silver.box, tab.boxColoured, 3) }
            }
            PathPolyline {
                path: Geo.tabBox(tab.topX, tab.bandWidth, tab.mirror, tab.boxTop, tab.sx, tab.sy)
            }
        }
    }

    // The name, rotated to read top to bottom, centred in the box.
    Text {
        id: label
        text: tab.title.toLowerCase()
        font.family: Cfg.font
        font.pixelSize: Cfg.tabLabelSize * tab.sy
        color: area.containsMouse && tab.weight < 0.5 ? "#2e2e2e"
             : tab.mixColor(tab.c(Cfg.silver.label), tab.c(tab.blade.ink), tab.weight)
        rotation: 90
        transformOrigin: Item.TopLeft
        x: tab.boxCentreX + height / 2
        y: tab.labelRefY * tab.sy
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
