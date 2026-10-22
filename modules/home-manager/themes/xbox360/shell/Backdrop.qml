// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Backdrop.qml
// Every monitor but the primary one: no tabs, just the blade surface in the
// colour of whatever blade that monitor's workspace is, crossfading with it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Config.js" as Cfg

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandWorkspace workspace: monitor ? monitor.activeWorkspace : null
    property int index: 5
    readonly property int target: {
        const ws = workspace;
        if (!ws || ws.id < 0) return index;
        return (ws.id >= 1 && ws.id <= 5) ? ws.id - 1 : 5;
    }
    onTargetChanged: index = target
    readonly property var stops: Cfg.blades[index].stops

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "xbox360-backdrop"

    BladeSurface {
        anchors.fill: parent
        masked: 0
        panelL: 0
        panelR: 1280
        c0: "#" + win.stops[0]
        c1: "#" + win.stops[1]
        c2: "#" + win.stops[2]
        c3: "#" + win.stops[3]
        animating: !(win.workspace && win.workspace.hasFullscreen)
        Behavior on c0 { ColorAnimation { duration: Cfg.motionMs } }
        Behavior on c1 { ColorAnimation { duration: Cfg.motionMs } }
        Behavior on c2 { ColorAnimation { duration: Cfg.motionMs } }
        Behavior on c3 { ColorAnimation { duration: Cfg.motionMs } }
    }
}
