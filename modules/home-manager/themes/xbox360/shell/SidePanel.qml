// ~/nixos-config/modules/home-manager/themes/xbox360/shell/SidePanel.qml
// A blade that slides in from one side over everything, the way the console's
// Guide (from the left, guide.png) and notification blade (from the right,
// notification.png) do, dimming the rest of the screen. Its surface is the
// same blade shader as the dashboard, so it has the header band (title and
// clock), the rounded card and the footer band with the button legend; its
// inner edge is the dashboard's arc, with a band beside it carrying a label
// (the gamertag on the Guide).
//
// Content goes in the default property and is laid out inside `card`.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "Config.js" as Cfg
import "Geometry.js" as Geo

PanelWindow {
    id: win

    property bool open: false
    property bool fromLeft: true
    property real widthRef: 560          // the blade's width, reference units
    property string title: ""
    property string bandLabel: ""
    property var stops: Cfg.guide.stops   // 4 hex gradient stops
    property var legend: ({ left: [], right: [] })
    property bool exclusiveKeyboard: true
    signal dismissed()                    // clicked outside
    default property alias content: card.data

    readonly property var g: Geo.frameFor(screen.width, screen.height)
    readonly property real s: g.s
    readonly property real stripW: 40
    // The panel's own edges in its local reference frame: the outer one off
    // screen, the inner one curved, leaving room for the band beside it.
    readonly property real innerEdge: fromLeft ? widthRef - stripW : stripW
    readonly property var cardRef: {
        const L = fromLeft ? 0 : innerEdge, R = fromLeft ? innerEdge : widthRef;
        const r = Geo.cardRect(L, R, 1, { s: g.s, W: widthRef, H: g.H, cf: 1 });
        if (fromLeft) { r.x = Cfg.cardInset + 6; r.w = innerEdge - Geo.WAIST - Cfg.cardInset - 12; }
        else { r.x = innerEdge + Geo.WAIST + 6; r.w = widthRef - r.x - Cfg.cardInset - 6; }
        return r;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || slide.running || dimAnim.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "xbox360-side"
    WlrLayershell.keyboardFocus: open && exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The rest of the screen dims, as on the console.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.open ? 0.5 : 0
        Behavior on opacity { NumberAnimation { id: dimAnim; duration: Cfg.motionMs } }
        MouseArea { anchors.fill: parent; onClicked: win.dismissed() }
    }

    Item {
        id: blade
        width: win.widthRef * win.s
        height: parent.height
        x: win.fromLeft ? (win.open ? 0 : -width) : (win.open ? parent.width - width : parent.width)
        Behavior on x { NumberAnimation { id: slide; duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier } }
        Behavior on width { NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier } }
        MouseArea { anchors.fill: parent }   // clicks on the blade don't dismiss it

        readonly property var lg: ({ s: win.s, W: win.widthRef, H: win.g.H, cf: 1 })

        BladeSurface {
            id: surface
            // Only the panel's own span: the band beside it is drawn on top.
            x: win.fromLeft ? 0 : win.innerEdge * win.s
            width: (win.fromLeft ? win.innerEdge : win.widthRef - win.innerEdge) * win.s
            height: parent.height
            c0: "#" + win.stops[0]
            c1: "#" + win.stops[1]
            c2: "#" + win.stops[2]
            c3: "#" + win.stops[3]
            refSize: Qt.size(width / win.s, win.g.H)
            panelL: win.fromLeft ? -60 : 0
            panelR: win.fromLeft ? win.innerEdge : win.widthRef - win.innerEdge + 60
            curveAmt: 1
            animating: win.visible
        }

        // The band beside the inner edge, over the surface's outer sliver.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(0.3, 0.25, 0.1, 0.6)
                strokeWidth: 1.4
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: blade.width; y2: 0
                    GradientStop { position: 0.0; color: Qt.lighter("#" + win.stops[1], 1.15) }
                    GradientStop { position: 1.0; color: "#" + win.stops[2] }
                }
                PathPolyline {
                    path: win.fromLeft
                        ? Geo.ribbon(win.innerEdge - 2, 1, win.widthRef, 1, blade.lg)
                        : Geo.ribbon(0, -1, win.stripW + 2, -1, blade.lg)
                }
            }
        }
        Text {
            text: win.bandLabel
            font.family: Cfg.font
            font.pixelSize: 21 * win.s
            color: "#2a1f05"
            rotation: 90
            transformOrigin: Item.TopLeft
            x: (win.fromLeft ? win.innerEdge + win.stripW / 2 - Geo.WAIST * 0.4 : win.stripW / 2) * win.s + height / 2
            y: 150 * win.s
        }
        // The panel's outline down the inner edge.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(0.25, 0.2, 0.05, 0.7)
                strokeWidth: 1.6
                fillColor: "transparent"
                PathPolyline { path: Geo.edge(win.innerEdge, win.fromLeft ? 1 : -1, blade.lg) }
            }
        }

        // Header: title and clock.
        SystemClock { id: clock; precision: SystemClock.Minutes }
        Text {
            x: (win.cardRef.x + 14) * win.s
            y: Cfg.titleCentre * win.s - height / 2
            text: win.title
            font.family: Cfg.font
            font.pixelSize: Cfg.titleSize * win.s
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.28)
        }
        Text {
            x: (win.cardRef.x + win.cardRef.w - 14) * win.s - width
            y: Cfg.titleCentre * win.s - height / 2
            text: Qt.formatTime(clock.date, "h:mm AP")
            font.family: Cfg.font
            font.pixelSize: Cfg.footerSize * win.s
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.28)
        }

        // The card, where the content goes.
        Item {
            id: card
            x: (win.cardRef.x + 14) * win.s
            y: (win.cardRef.y + 12) * win.s
            width: (win.cardRef.w - 28) * win.s
            height: (win.cardRef.h - 24) * win.s
        }

        // Footer: the legend, Y over X on the left, B over A on the right.
        component Entry: Row {
            id: entry
            property var spec
            property bool rightSide: false
            spacing: 6 * win.s
            layoutDirection: rightSide ? Qt.RightToLeft : Qt.LeftToRight
            ButtonGlyph { btn: entry.spec.btn; size: 20 * win.s; dim: entry.spec.label === ""; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: entry.spec.label
                font.family: Cfg.font
                font.pixelSize: Cfg.footerSize * win.s
                color: "white"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.28)
            }
        }
        Column {
            x: (win.cardRef.x + 14) * win.s
            y: (win.g.H - Cfg.footerHeight + 6) * win.s
            spacing: 2 * win.s
            Repeater {
                model: win.legend.left
                delegate: Entry { required property var modelData; spec: modelData }
            }
        }
        Column {
            x: (win.cardRef.x + win.cardRef.w - 14) * win.s - width
            y: (win.g.H - Cfg.footerHeight + 6) * win.s
            spacing: 2 * win.s
            Repeater {
                model: win.legend.right
                delegate: Entry {
                    required property var modelData
                    spec: modelData
                    rightSide: true
                    anchors.right: parent ? parent.right : undefined
                }
            }
        }
    }
}
