// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Blades.qml
// The blades dashboard on the primary monitor. Workspaces 1-5 are the five
// blades; any other workspace opens a sixth, neutral "steel" blade.
//
// Two kinds of surface, both on the BACKGROUND layer so windows always tile
// over them:
//   - one full-screen window that paints the whole dashboard and takes clicks
//     on the tabs (windows never cover the tabs: see the next point), and
//   - four invisible, input-transparent windows whose only job is an
//     exclusive zone, so Hyprland tiles windows inside the open blade.
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

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandWorkspace workspace: monitor ? monitor.activeWorkspace : null

    // Blade shown for the monitor's workspace. Special workspaces (negative
    // ids, e.g. the ckb utility drawer) are overlays and leave it alone.
    property int index: 2
    function bladeFor(ws) {
        if (!ws || ws.id < 0) return index;
        return (ws.id >= 1 && ws.id <= 5) ? ws.id - 1 : 5;
    }
    readonly property int target: bladeFor(workspace)

    // ---- the move between blades -----------------------------------------
    // `from` is whatever is on screen when a move starts, so switching again
    // mid-move continues from where things are rather than snapping back.
    property var fromLayout: Geo.layout(index)
    property var toLayout: Geo.layout(index)
    property var fromColors: stopsOf(index)
    property var toColors: stopsOf(index)
    property real t: 1
    readonly property var shown: Geo.mix(fromLayout, toLayout, t)
    readonly property var colors: mixStops(fromColors, toColors, t)
    property bool started: false

    onTargetChanged: {
        if (target === index) return;
        const forward = target > index;
        fromLayout = shown;
        fromColors = colors;
        toLayout = Geo.layout(target);
        toColors = stopsOf(target);
        index = target;
        t = 0;
        move.restart();
        if (started) play(forward ? "page-right" : "page-left");
    }
    Component.onCompleted: {
        index = target;
        fromLayout = toLayout = Geo.layout(index);
        fromColors = toColors = stopsOf(index);
        started = true;
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

    // ---- colour helpers ----------------------------------------------------
    function hex(h) { return Qt.color("#" + h); }
    function blade(i) { return Cfg.blades[Math.max(0, Math.min(i, Cfg.blades.length - 1))]; }
    function stopsOf(i) { return blade(i).stops.map(hex); }
    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
    function mixStops(A, B, t) { return A.map((c, i) => mixColor(c, B[i], t)); }

    function play(cue) {
        Quickshell.execDetached([Cfg.pwPlay, Cfg.sounds + "/" + cue + ".wav"]);
    }
    function go(i) { Hyprland.dispatch("workspace " + (i + 1)); }

    // ---- exclusive zones: tile windows inside the open panel -------------
    // From the TARGET layout, not the animated one: the zones jump once and
    // Hyprland's own (identically timed) window animation does the moving.
    readonly property real sx: screen.width / 1280
    readonly property real sy: screen.height / 720
    readonly property var zones: {
        const l = Geo.layout(target);
        return {
            left:   Math.round((l.L + Geo.WAIST + Cfg.cardInset) * sx),
            right:  Math.round(screen.width - (l.R - Geo.WAIST - Cfg.cardInset) * sx),
            top:    Math.round(Cfg.headerBottom * sy),
            bottom: Math.round((720 - Cfg.footerTop) * sy)
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

    // ---- the dashboard itself --------------------------------------------
    PanelWindow {
        id: win
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#9a9a9a"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "xbox360-blades"

        Item {
            id: stage
            anchors.fill: parent
            readonly property real sx: width / 1280
            readonly property real sy: height / 720

            // Layer 0: the section gradient, sheen, ripples and gloss.
            BladeSurface {
                anchors.fill: parent
                c0: root.colors[0]
                c1: root.colors[1]
                c2: root.colors[2]
                c3: root.colors[3]
                panelL: root.shown.L
                panelR: root.shown.R
                // Nothing to look at behind a fullscreen window.
                animating: !(root.workspace && root.workspace.hasFullscreen)
            }

            // Layer 1: the neutral gutters behind the collapsed stacks. Their
            // inner edge is the panel's own curve, so the panel's flare is
            // never cut by a straight line.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: stage.height
                        GradientStop { position: 0.0; color: Qt.alpha("#" + Cfg.silver.gutter[0], 0.95) }
                        GradientStop { position: 0.45; color: Qt.alpha("#" + Cfg.silver.gutter[1], 0.95) }
                        GradientStop { position: 1.0; color: Qt.alpha("#" + Cfg.silver.gutter[2], 0.95) }
                    }
                    PathPolyline {
                        path: Geo.ribbon(-400, 0, root.shown.L, -1, stage.sx, stage.sy)
                    }
                }
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: stage.height
                        GradientStop { position: 0.0; color: Qt.alpha("#" + Cfg.silver.gutter[0], 0.95) }
                        GradientStop { position: 0.45; color: Qt.alpha("#" + Cfg.silver.gutter[1], 0.95) }
                        GradientStop { position: 1.0; color: Qt.alpha("#" + Cfg.silver.gutter[2], 0.95) }
                    }
                    PathPolyline {
                        path: Geo.ribbon(root.shown.R, 1, 1680, 0, stage.sx, stage.sy)
                    }
                }
            }

            // Layer 2: the panel's rim — the same dark line the captures show
            // between every band, here down each side of the open panel.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(0.25, 0.25, 0.25, 0.7)
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    PathPolyline { path: Geo.edge(root.shown.L, -1, stage.sx, stage.sy) }
                }
                ShapePath {
                    strokeColor: Qt.rgba(0.25, 0.25, 0.25, 0.7)
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    PathPolyline { path: Geo.edge(root.shown.R, 1, stage.sx, stage.sy) }
                }
            }

            // Layer 3: the five tabs.
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
                    sx: stage.sx
                    sy: stage.sy
                    onHovered: root.play("select")
                    onActivated: root.go(index)
                }
            }

            // Layer 4: the header — the open blade's title on the left, the
            // gamertag and clock on the right. The title lands from the
            // direction of travel a third of a tempo after the chrome moves.
            BladeHeader {
                anchors.fill: parent
                // The steel blade is any other workspace, so it is titled by name.
                title: root.index === 5 && root.workspace
                    ? (root.workspace.name && root.workspace.name !== String(root.workspace.id)
                        ? root.workspace.name : "Workspace " + root.workspace.id)
                    : root.blade(root.index).title
                forward: root.toLayout.a >= root.fromLayout.a
                panelL: root.toLayout.L
                panelR: root.toLayout.R
                sx: stage.sx
                sy: stage.sy
            }

            // Scroll anywhere on the dashboard to move between blades.
            WheelHandler {
                property real acc: 0
                onWheel: event => {
                    acc += event.angleDelta.y;
                    if (Math.abs(acc) < 120) return;
                    const step = acc > 0 ? -1 : 1;
                    acc = 0;
                    const next = Math.max(0, Math.min(4, Math.min(root.index, 4) + step));
                    if (next !== root.index) root.go(next);
                }
            }
        }
    }
}
