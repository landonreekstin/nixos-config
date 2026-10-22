// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Frame.qml
// Everything one screen shows, in one of three modes:
//   blades — this display's dashboard (workspace name:dashboard-<connector>):
//            the five bands around the open blade, whose menu DashboardMenu
//            draws on top;
//   page   — a full-screen page opened from a blade (Downloads, ...), drawn as
//            the console's straight-sided "submenu" frame;
//   app    — any other workspace: the same frame around the tiled windows, in
//            the colour of the blade the app was launched from.
// A change of mode morphs one into the other — the bands deal off the sides
// and the panel grows to full width — on the console's 350 ms tempo.
//
// Every display has its own dashboard (its own Dash: blade, rows, page), so a
// dashboard can show on one screen while an app runs on another.
//
// On a PORTRAIT screen the chrome is "turned": the very same landscape
// drawing, transposed onto the screen (`stage`), so the blades run across it
// and stack top to bottom; the header and footer stay upright across the top
// and bottom, drawn here rather than by the shader. Geometry.verticalFrame.
//
// Two kinds of surface, both on the BACKGROUND layer so windows always tile
// over them: one full-screen window painting the frame (and taking clicks on
// tabs and legend), and four invisible, input-transparent windows whose only
// job is an exclusive zone, so Hyprland tiles windows inside the frame's card.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Config.js" as Cfg
import "Geometry.js" as Geo

Scope {
    id: root

    required property ShellScreen screen
    property bool primary: false

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandWorkspace workspace: monitor ? monitor.activeWorkspace : null
    // The screen's name and size, with stand-ins while a display going off
    // tears this Frame down (its `screen` is already null by then).
    readonly property string screenName: screen ? screen.name : ""
    readonly property real sw: screen ? screen.width : 1280
    readonly property real sh: screen ? screen.height : 720
    readonly property var dash: ShellState.dashFor(screenName)
    readonly property bool focused: ShellState.focusedMonitor !== null && monitor !== null
                                    && ShellState.focusedMonitor.name === monitor.name
    readonly property bool onDashboard: ShellState.isDashboard(workspace)
    readonly property string mode: onDashboard ? (dash.page !== "" ? "page" : "blades") : "app"
    readonly property var appMeta: ShellState.metaFor(workspace)
    readonly property int colour: mode === "blades" ? dash.blade
                                : mode === "page" ? dash.pageBlade
                                : appMeta.blade
    readonly property string title: mode === "blades" ? Theme.blades[dash.blade].title
                                  : mode === "page" ? dash.pageTitle
                                  : appMeta.title

    // ---- geometry --------------------------------------------------------
    readonly property bool vertical: sh > sw
    readonly property var g0: vertical ? Geo.verticalFrame(sw, sh) : Geo.frameFor(sw, sh)
    readonly property var g: Object.assign({}, g0, { cf: shown.cf })
    // The upright header and footer of a turned frame: a plain, full-width
    // frame of the whole screen at the stage's scale.
    readonly property var gUpright: ({ s: g0.s, W: sw / g0.s, H: sh / g0.s, cf: 0 })

    // A rectangle in the stage's reference units, in screen pixels.
    function onScreen(c) {
        const s = g0.s;
        if (!vertical) return { x: c.x * s, y: c.y * s, w: c.w * s, h: c.h * s };
        return { x: c.y * s, y: g0.top + c.x * s, w: c.h * s, h: c.w * s };
    }

    function targetLayout() {
        return mode === "blades" ? Geo.layout(colour, g0.W) : Geo.frame(colour, g0.W);
    }
    readonly property string targetKey: mode + ":" + colour + ":" + g0.W + ":" + g0.H + ":" + Theme.night

    property var fromLayout: targetLayout()
    property var toLayout: targetLayout()
    property var fromColors: stopsOf(colour)
    property var toColors: stopsOf(colour)
    property real t: 1
    readonly property var shown: Geo.mix(fromLayout, toLayout, t)
    readonly property var colors: mixStops(fromColors, toColors, t)
    property string lastMode: mode
    property int lastBlade: dash.blade

    onTargetKeyChanged: {
        fromLayout = shown;
        fromColors = colors;
        toLayout = targetLayout();
        toColors = stopsOf(colour);
        t = 0;
        move.restart();
        // A blade switch on the dashboard pages left or right, as on the console.
        if (mode === "blades" && lastMode === "blades" && dash.blade !== lastBlade)
            ShellState.play(dash.blade > lastBlade ? "page-right" : "page-left");
        lastMode = mode;
        lastBlade = dash.blade;
    }

    NumberAnimation {
        id: move
        target: root
        property: "t"
        from: 0
        to: 1
        duration: Cfg.motionMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Cfg.motionBezier
    }

    function hex(h) { return Qt.color("#" + h); }
    function blade(i) { return Theme.blades[Math.max(0, Math.min(i, Theme.blades.length - 1))]; }
    function stopsOf(i) { return blade(i).stops.map(hex); }
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    function mixStops(A, B, t) { return A.map((c, i) => mixColor(c, B[i], t)); }

    // ---- exclusive zones: tile windows inside the frame's card ------------
    // Always the app frame's card: windows only ever live on app workspaces.
    readonly property var appCard: onScreen(Geo.cardRect(Cfg.frameMargin, g0.W - Cfg.frameMargin, 0, g0))
    readonly property var zones: ({
        left:   Math.round(appCard.x),
        right:  Math.round(sw - appCard.x - appCard.w),
        top:    Math.round(appCard.y),
        bottom: Math.round(sh - appCard.y - appCard.h)
    })

    // A turned frame's upright header and footer bands, across the whole
    // screen: the blade's deep stops, as the shader paints them.
    component UprightBand: Rectangle {
        id: band
        property real shade: 0.55
        width: parent ? parent.width : 0
        visible: root.vertical
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.mixColor(root.mixColor(root.colors[2], root.colors[3], band.shade), Qt.rgba(1, 1, 1, 1), Theme.glow * 0.18) }
            GradientStop { position: 1.0; color: root.mixColor(root.colors[2], root.colors[3], band.shade + 0.1) }
        }
        Rectangle {
            width: parent.width
            height: 1.6
            y: band.y > 0 ? 0 : band.height - height
            color: Qt.rgba(0.25, 0.25, 0.25, 0.7)
        }
    }

    // Hyprland places a layer surface where its monitor is when it maps, and
    // leaves it there if the monitor then moves (an auto-placed output
    // sliding over when the display beside it goes off): the whole frame sat
    // off-screen. So every surface of this Frame maps again when it moves.
    property bool mapped: true
    function remap() { mapped = false; remapLater.restart(); }
    Timer { id: remapLater; interval: 100; onTriggered: root.mapped = true }
    Connections {
        target: root.monitor
        function onXChanged() { root.remap(); }
        function onYChanged() { root.remap(); }
    }

    component Zone: PanelWindow {
        color: "transparent"
        visible: root.mapped
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "xbox360-zone"
    }
    Zone {
        anchors { top: true; left: true; right: true }
        screen: root.screen
        implicitHeight: 1
        exclusiveZone: root.zones.top
    }
    Zone {
        anchors { bottom: true; left: true; right: true }
        screen: root.screen
        implicitHeight: 1
        exclusiveZone: root.zones.bottom
    }
    Zone {
        anchors { left: true; top: true; bottom: true }
        screen: root.screen
        implicitWidth: 1
        exclusiveZone: root.zones.left
    }
    Zone {
        anchors { right: true; top: true; bottom: true }
        screen: root.screen
        implicitWidth: 1
        exclusiveZone: root.zones.right
    }

    // ---- the frame -------------------------------------------------------
    PanelWindow {
        id: win
        screen: root.screen
        visible: root.mapped
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.backdrop
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "xbox360-frame"

        Item {
            id: screenItem
            anchors.fill: parent

            // The chrome, in the stage's own landscape coordinates. On a
            // portrait screen it is transposed — (u, v) lands at (v, top + u) —
            // which turns the blades a quarter while keeping every curve, the
            // shader and all of Geometry.js exactly as on a landscape screen.
            Item {
                id: stage
                width: root.g0.W * root.g0.s
                height: root.g0.H * root.g0.s
                transform: Matrix4x4 {
                    matrix: root.vertical ? Qt.matrix4x4(0, 1, 0, 0,
                                                         1, 0, 0, root.g0.top,
                                                         0, 0, 1, 0,
                                                         0, 0, 0, 1)
                                          : Qt.matrix4x4()
                }

                // Layer 0: the surface — gradient, bands, card, sheen, gloss.
                BladeSurface {
                    anchors.fill: parent
                    c0: root.colors[0]
                    c1: root.colors[1]
                    c2: root.colors[2]
                    c3: root.colors[3]
                    panelL: root.shown.L
                    panelR: root.shown.R
                    curveAmt: root.shown.cf
                    refSize: Qt.size(root.g0.W, root.g0.H)
                    hb: root.g0.hb !== undefined ? root.g0.hb : Cfg.headerBottom
                    fh: root.g0.fh !== undefined ? root.g0.fh : Cfg.footerHeight
                    turned: root.vertical ? 1 : 0
                    // Only where the card is what you look at. Behind apps the
                    // ripples redrew the whole screen every frame (180 Hz here) for
                    // a sliver of margin — GPU time a windowed game wants.
                    animating: root.mode !== "app"
                }

                // Layer 1: the silver backdrop outside the panel. Its inner edge is
                // the panel's own curve, so the arc is never cut by a straight line.
                // Light at the top of the SCREEN: along u when turned.
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0
                            x2: root.vertical ? stage.width : 0
                            y2: root.vertical ? 0 : stage.height
                            GradientStop { position: 0.0; color: "#" + Theme.silver.gutter[0] }
                            GradientStop { position: 0.45; color: "#" + Theme.silver.gutter[1] }
                            GradientStop { position: 1.0; color: "#" + Theme.silver.gutter[2] }
                        }
                        PathPolyline { path: Geo.ribbon(-400, 0, root.shown.L, -1, root.g) }
                    }
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0
                            x2: root.vertical ? stage.width : 0
                            y2: root.vertical ? 0 : stage.height
                            GradientStop { position: 0.0; color: "#" + Theme.silver.gutter[0] }
                            GradientStop { position: 0.45; color: "#" + Theme.silver.gutter[1] }
                            GradientStop { position: 1.0; color: "#" + Theme.silver.gutter[2] }
                        }
                        PathPolyline { path: Geo.ribbon(root.shown.R, 1, root.g0.W + 400, 0, root.g) }
                    }
                }

                // Layer 2: the dark line down each side of the panel.
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Qt.rgba(0.25, 0.25, 0.25, 0.7)
                        strokeWidth: 1.6
                        fillColor: "transparent"
                        PathPolyline { path: Geo.edge(root.shown.L, -1, root.g) }
                    }
                    ShapePath {
                        strokeColor: Qt.rgba(0.25, 0.25, 0.25, 0.7)
                        strokeWidth: 1.6
                        fillColor: "transparent"
                        PathPolyline { path: Geo.edge(root.shown.R, 1, root.g) }
                    }
                }

                // Layer 3: the five bands (dealt off-screen in the frame modes).
                Repeater {
                    model: 5
                    delegate: BladeTab {
                        required property int index
                        anchors.fill: parent
                        k: index
                        title: root.blade(index).title
                        topX: root.shown.tabs[index]
                        bandWidth: root.shown.widths[index]
                        mirror: root.shown.mirror[index]
                        weight: root.shown.weight[index]
                        blade: root.blade(index)
                        g: root.g
                        turned: root.vertical
                        interactive: root.mode === "blades"
                        onHovered: ShellState.play("select")
                        onActivated: root.dash.blade = index
                    }
                }
            }
            UprightBand {
                y: 0
                height: root.vertical ? root.g0.top : 0
                shade: 0.55
            }
            UprightBand {
                y: screenItem.height - height
                height: root.vertical ? root.g0.bottom : 0
                shade: 0.8
            }

            // Layer 4: header (title, clock, ring of light) and footer (button
            // legend). Upright on a turned frame, across the whole screen.
            BladeBands {
                anchors.fill: parent
                mode: root.mode
                title: root.title
                dash: root.dash
                focused: root.focused
                forward: root.toLayout.a >= root.fromLayout.a
                panelL: root.vertical ? Cfg.frameMargin : root.toLayout.L
                panelR: root.vertical ? root.gUpright.W - Cfg.frameMargin : root.toLayout.R
                cf: root.vertical ? 0 : root.toLayout.cf
                g: root.vertical ? root.gUpright : root.g0
            }

            // An app workspace with nothing on it yet: the console's loading
            // ring while the app starts, and after a while a hint that it
            // may not be coming.
            Item {
                id: loading
                readonly property int windows: root.workspace && root.workspace.toplevels
                                               ? root.workspace.toplevels.values.length : 0
                readonly property bool waiting: root.mode === "app" && windows === 0
                property bool slow: false
                x: root.appCard.x
                y: root.appCard.y
                width: root.appCard.w
                height: root.appCard.h
                opacity: waiting ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Cfg.motionMs } }
                onWaitingChanged: { slow = false; if (waiting) slowTimer.restart(); }
                Timer { id: slowTimer; interval: 30000; onTriggered: loading.slow = true }

                LoadingRing {
                    id: ring
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -24 * root.g0.s
                    size: 90 * root.g0.s
                    running: loading.visible
                }
                Text {
                    anchors.top: ring.bottom
                    anchors.topMargin: 22 * root.g0.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, parent.width - 40 * root.g0.s)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: loading.slow ? root.title + " is taking a while. Guide + Y goes back to the dashboard."
                                       : "Loading " + root.title + "…"
                    font.family: Cfg.font
                    font.pixelSize: 24 * root.g0.s
                    color: "white"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.28)
                }
            }

            // Scroll on the dashboard to move between blades.
            WheelHandler {
                enabled: root.mode === "blades"
                property real acc: 0
                onWheel: event => {
                    acc += event.angleDelta.y;
                    if (Math.abs(acc) < 120) return;
                    const step = acc > 0 ? -1 : 1;
                    acc = 0;
                    root.dash.blade = Math.max(0, Math.min(4, root.dash.blade + step));
                }
            }
        }
    }

    // This display's dashboard menus and pages, on top, with the keyboard
    // while this display has focus.
    DashboardMenu {
        screen: root.screen
        frame: root
    }
}
