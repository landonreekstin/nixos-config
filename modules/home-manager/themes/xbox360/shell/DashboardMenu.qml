// ~/nixos-config/modules/home-manager/themes/xbox360/shell/DashboardMenu.qml
// The dashboard's interactive layer: the open blade's menu (or a page opened
// from it), drawn over the Frame's card on a TOP-layer window that takes the
// keyboard while the dashboard is showing. Its input mask is the card alone,
// so the bands drawn on the background layer stay clickable.
//
// Keys map to controller buttons, so the keyboard, the mouse and (later) the
// controller daemon all drive the same `handle(btn)`:
//   arrows = d-pad, Enter/Space = A, Esc/Backspace = B, X/Y = X/Y,
//   Tab/Shift+Tab = RB/LB, PageUp/PageDown = LT/RT.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Config.js" as Cfg
import "Geometry.js" as Geo

PanelWindow {
    id: win

    required property var frame
    readonly property bool showing: frame.mode === "blades" || frame.mode === "page"
    readonly property real s: frame.g0.s
    readonly property var card: Geo.cardRect(frame.toLayout.L, frame.toLayout.R, frame.toLayout.cf, frame.g0)
    readonly property int bladeIndex: frame.mode === "page" ? ShellState.pageBlade : ShellState.blade
    readonly property var bladeSpec: Theme.blades[bladeIndex]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: showing
    mask: Region { item: content }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "xbox360-dashboard"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---- input ---------------------------------------------------------------
    QtObject {
        id: handler
        property bool active: win.showing
        property int priority: 0
        function handle(btn) { return win.handle(btn); }
    }
    Component.onCompleted: ShellState.pushHandler(handler)
    Component.onDestruction: ShellState.removeHandler(handler)

    function handle(btn) {
        if (frame.mode === "page") return pageLoader.item ? pageLoader.item.handle(btn) : false;
        switch (btn) {
        case "left": case "right":
            if (bladeMenu.handle(btn)) return true;
            if (btn === "left") { if (ShellState.blade > 0) ShellState.blade--; return true; }
            if (ShellState.blade < 4) ShellState.blade++;
            return true;
        case "lb":
            if (ShellState.blade > 0) ShellState.blade--;
            return true;
        case "rb":
            if (ShellState.blade < 4) ShellState.blade++;
            return true;
        default:
            return bladeMenu.handle(btn);
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const map = {
                [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                [Qt.Key_Return]: "a", [Qt.Key_Enter]: "a", [Qt.Key_Space]: "a",
                [Qt.Key_Escape]: "b", [Qt.Key_Backspace]: "b",
                [Qt.Key_X]: "x", [Qt.Key_Y]: "y",
                [Qt.Key_Tab]: "rb", [Qt.Key_Backtab]: "lb",
                [Qt.Key_PageUp]: "lt", [Qt.Key_PageDown]: "rt"
            };
            const btn = map[event.key];
            if (btn !== undefined && win.handle(btn)) event.accepted = true;
        }
    }

    // ---- content -------------------------------------------------------------
    Item {
        id: content
        x: (win.card.x + Cfg.contentPad) * win.s
        y: (win.card.y + Cfg.contentPad * 0.6) * win.s
        width: (win.card.w - 2 * Cfg.contentPad) * win.s
        height: (win.card.h - Cfg.contentPad * 1.2) * win.s

        // Contents land from the direction of travel after the chrome moves,
        // like the title.
        property real shift: 0
        transform: Translate { x: content.shift }
        Connections {
            target: win.frame
            function onTargetKeyChanged() { land.restart(); }
        }
        SequentialAnimation {
            id: land
            PropertyAction { target: content; property: "opacity"; value: 0 }
            PropertyAction { target: content; property: "shift"; value: (win.frame.toLayout.a >= win.frame.fromLayout.a ? 28 : -28) * win.s }
            PauseAnimation { duration: Cfg.motionMs / 3 }
            ParallelAnimation {
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: Cfg.motionMs }
                NumberAnimation {
                    target: content; property: "shift"; to: 0; duration: Cfg.motionMs
                    easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier
                }
            }
        }

        BladeMenu {
            id: bladeMenu
            anchors.fill: parent
            visible: win.frame.mode === "blades"
            blade: ShellState.blade
            s: win.s
        }

        Loader {
            id: pageLoader
            anchors.fill: parent
            active: win.frame.mode === "page"
            source: ShellState.page === "" ? "" : Qt.resolvedUrl(Cfg.pages[ShellState.page])
            onLoaded: {
                item.s = Qt.binding(() => win.s);
                item.bladeSpec = Qt.binding(() => win.bladeSpec);
            }
        }
    }
}
