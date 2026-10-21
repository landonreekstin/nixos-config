// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Frame.qml
// Everything one screen shows, in one of three modes:
//   blades — the dashboard (primary screen, workspace name:dashboard): the five
//            bands around the open blade, whose menu DashboardMenu draws on top;
//   page   — a full-screen page opened from a blade (Downloads, ...), drawn as
//            the console's straight-sided "submenu" frame;
//   app    — any other workspace: the same frame around the tiled windows, in
//            the colour of the blade the app was launched from.
// A change of mode morphs one into the other — the bands deal off the sides
// and the panel grows to full width — on the console's 350 ms tempo.
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
    readonly property bool onDashboard: primary && workspace !== null && workspace.name === "dashboard"
    readonly property string mode: onDashboard ? (ShellState.page !== "" ? "page" : "blades") : "app"
    readonly property var appMeta: ShellState.metaFor(workspace)
    readonly property int colour: mode === "blades" ? ShellState.blade
                                : mode === "page" ? ShellState.pageBlade
                                : appMeta.blade
    readonly property string title: mode === "blades" ? Cfg.blades[ShellState.blade].title
                                  : mode === "page" ? ShellState.pageTitle
                                  : appMeta.title

    // ---- geometry --------------------------------------------------------
    readonly property var g0: Geo.frameFor(screen.width, screen.height)
    readonly property var g: ({ s: g0.s, W: g0.W, H: g0.H, cf: shown.cf })

    function targetLayout() {
        return mode === "blades" ? Geo.layout(colour, g0.W) : Geo.frame(colour, g0.W);
    }
    readonly property string targetKey: mode + ":" + colour + ":" + g0.W + ":" + g0.H

    property var fromLayout: targetLayout()
    property var toLayout: targetLayout()
    property var fromColors: stopsOf(colour)
    property var toColors: stopsOf(colour)
    property real t: 1
    readonly property var shown: Geo.mix(fromLayout, toLayout, t)
    readonly property var colors: mixStops(fromColors, toColors, t)
    property string lastMode: mode
    property int lastBlade: ShellState.blade

    onTargetKeyChanged: {
        fromLayout = shown;
        fromColors = colors;
        toLayout = targetLayout();
        toColors = stopsOf(colour);
        t = 0;
        move.restart();
        // A blade switch on the dashboard pages left or right, as on the console.
        if (mode === "blades" && lastMode === "blades" && ShellState.blade !== lastBlade)
            ShellState.play(ShellState.blade > lastBlade ? "page-right" : "page-left");
        lastMode = mode;
        lastBlade = ShellState.blade;
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
    function blade(i) { return Cfg.blades[Math.max(0, Math.min(i, Cfg.blades.length - 1))]; }
    function stopsOf(i) { return blade(i).stops.map(hex); }
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    function mixStops(A, B, t) { return A.map((c, i) => mixColor(c, B[i], t)); }

    // ---- exclusive zones: tile windows inside the frame's card ------------
    // Always the app frame's card: windows only ever live on app workspaces.
    readonly property var zones: {
        const c = Geo.cardRect(Cfg.frameMargin, g0.W - Cfg.frameMargin, 0, g0);
        return {
            left:   Math.round(c.x * g0.s),
            right:  Math.round(c.x * g0.s),
            top:    Math.round(Cfg.headerBottom * g0.s),
            bottom: Math.round(Cfg.footerHeight * g0.s)
        };
    }

    component Zone: PanelWindow {
        color: "transparent"
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
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#9a9a9a"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "xbox360-frame"

        Item {
            id: stage
            anchors.fill: parent

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
                // Nothing to look at behind a fullscreen window.
                animating: !(root.workspace && root.workspace.hasFullscreen)
            }

            // Layer 1: the silver backdrop outside the panel. Its inner edge is
            // the panel's own curve, so the arc is never cut by a straight line.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: stage.height
                        GradientStop { position: 0.0; color: "#" + Cfg.silver.gutter[0] }
                        GradientStop { position: 0.45; color: "#" + Cfg.silver.gutter[1] }
                        GradientStop { position: 1.0; color: "#" + Cfg.silver.gutter[2] }
                    }
                    PathPolyline { path: Geo.ribbon(-400, 0, root.shown.L, -1, root.g) }
                }
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: stage.height
                        GradientStop { position: 0.0; color: "#" + Cfg.silver.gutter[0] }
                        GradientStop { position: 0.45; color: "#" + Cfg.silver.gutter[1] }
                        GradientStop { position: 1.0; color: "#" + Cfg.silver.gutter[2] }
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
                    visible: root.primary || root.mode === "blades"
                    k: index
                    title: root.blade(index).title
                    topX: root.shown.tabs[index]
                    bandWidth: root.shown.widths[index]
                    mirror: root.shown.mirror[index]
                    weight: root.shown.weight[index]
                    blade: root.blade(index)
                    g: root.g
                    interactive: root.mode === "blades"
                    onHovered: ShellState.play("select")
                    onActivated: ShellState.blade = index
                }
            }

            // Layer 4: header (title, clock) and footer (button legend).
            BladeBands {
                anchors.fill: parent
                mode: root.mode
                title: root.title
                forward: root.toLayout.a >= root.fromLayout.a
                panelL: root.toLayout.L
                panelR: root.toLayout.R
                cf: root.toLayout.cf
                g: root.g0
            }

            // An app workspace with nothing on it yet: the console's loading
            // ring while the app starts, and after a while a hint that it
            // may not be coming.
            Item {
                id: loading
                readonly property int windows: root.workspace && root.workspace.toplevels
                                               ? root.workspace.toplevels.values.length : 0
                readonly property bool waiting: root.mode === "app" && windows === 0
                readonly property var c: Geo.cardRect(Cfg.frameMargin, root.g0.W - Cfg.frameMargin, 0, root.g0)
                property bool slow: false
                x: c.x * root.g0.s
                y: c.y * root.g0.s
                width: c.w * root.g0.s
                height: c.h * root.g0.s
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
                    ShellState.blade = Math.max(0, Math.min(4, ShellState.blade + step));
                }
            }
        }
    }

    // The dashboard's menus and pages, on top, with the keyboard.
    LazyLoader {
        active: root.primary
        DashboardMenu {
            screen: root.screen
            frame: root
        }
    }
}
