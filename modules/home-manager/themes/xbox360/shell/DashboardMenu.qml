// ~/nixos-config/modules/home-manager/themes/xbox360/shell/DashboardMenu.qml
// A display's dashboard, the interactive part: the open blade's menu (or a
// page opened from it), drawn over the Frame's card on a TOP-layer window.
// Its input mask is the card alone, so the bands drawn on the background
// layer stay clickable.
//
// Every display has one, but only the FOCUSED display's takes the keyboard
// and the controller: two exclusive-keyboard layers would fight, and a button
// press is meant for the screen you are looking at.
//
// Keys map to controller buttons, so the keyboard, the mouse and the
// controller daemon all drive the same `handle(btn)`:
//   arrows = d-pad, Enter/Space = A, Esc/Backspace = B, X/Y = X/Y,
//   Tab/Shift+Tab = RB/LB, PageUp/PageDown = LT/RT.
// On a portrait (turned) dashboard the blades stack top to bottom, so up and
// down past the first or last row move to the blade above or below.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Config.js" as Cfg
import "Geometry.js" as Geo

PanelWindow {
    id: win

    required property var frame
    readonly property var dash: frame.dash
    readonly property bool showing: frame.mode === "blades" || frame.mode === "page"
    readonly property bool live: showing && frame.focused
    readonly property real s: frame.g0.s
    readonly property var card: frame.onScreen(Geo.cardRect(frame.toLayout.L, frame.toLayout.R, frame.toLayout.cf, frame.g0))
    readonly property int bladeIndex: frame.mode === "page" ? dash.pageBlade : dash.blade
    readonly property var bladeSpec: Theme.blades[bladeIndex]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: showing && frame.mapped
    mask: Region { item: content }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "xbox360-dashboard"
    WlrLayershell.keyboardFocus: live ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---- input ---------------------------------------------------------------
    QtObject {
        id: handler
        property bool active: win.live
        property int priority: 0
        function handle(btn) { return win.handle(btn); }
    }
    Component.onCompleted: ShellState.pushHandler(handler)
    Component.onDestruction: ShellState.removeHandler(handler)

    // Whether the blade changed.
    function prevBlade() { if (dash.blade <= 0) return false; dash.blade--; return true; }
    function nextBlade() { if (dash.blade >= 4) return false; dash.blade++; return true; }

    function handle(btn) {
        if (frame.mode === "page") return pageLoader.item ? pageLoader.item.handle(btn) : false;
        if (frame.vertical) {
            switch (btn) {
            case "up":
                if (bladeMenu.current > 0) return bladeMenu.handle(btn);
                if (prevBlade()) bladeMenu.landOn("last");
                return true;
            case "down":
                if (bladeMenu.current < bladeMenu.rows.length - 1) return bladeMenu.handle(btn);
                if (nextBlade()) bladeMenu.landOn("first");
                return true;
            case "left": case "right":
                bladeMenu.handle(btn);   // a switch row; else nothing to go to
                return true;
            }
        }
        switch (btn) {
        case "left": case "right":
            if (bladeMenu.handle(btn)) return true;
            if (btn === "left") prevBlade(); else nextBlade();
            return true;
        case "lb": prevBlade(); return true;
        case "rb": nextBlade(); return true;
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
        x: win.card.x + Cfg.contentPad * win.s
        y: win.card.y + Cfg.contentPad * 0.6 * win.s
        width: win.card.w - 2 * Cfg.contentPad * win.s
        height: win.card.h - Cfg.contentPad * 1.2 * win.s

        // Contents land from the direction of travel after the chrome moves,
        // like the title — from below or above on a turned dashboard.
        property real shift: 0
        transform: Translate {
            x: win.frame.vertical ? 0 : content.shift
            y: win.frame.vertical ? content.shift : 0
        }
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
            dash: win.dash
            blade: win.dash.blade
            s: win.s
        }

        Loader {
            id: pageLoader
            anchors.fill: parent
            active: win.frame.mode === "page"
            source: win.dash.page === "" ? "" : Qt.resolvedUrl(Cfg.pages[win.dash.page])
            onLoaded: {
                item.s = Qt.binding(() => win.s);
                item.bladeSpec = Qt.binding(() => win.bladeSpec);
            }
        }
    }
}
