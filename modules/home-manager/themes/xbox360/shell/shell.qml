// ~/nixos-config/modules/home-manager/themes/xbox360/shell/shell.qml
// Xbox 360 "Blades" dashboard shell, started by the xbox360 Hyprland session
// as `qs -c xbox360`. The blades live on the primary monitor; every other
// monitor gets the blade surface as its backdrop.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Config.js" as Cfg

ShellRoot {
    id: shell

    // Config.primary is the host's "main" monitor; a machine without one
    // (a VM, an unplugged main monitor) falls back to the first screen.
    readonly property string primaryName: {
        const names = Quickshell.screens.map(s => s.name);
        if (Cfg.primary !== "" && names.indexOf(Cfg.primary) >= 0) return Cfg.primary;
        return names.length > 0 ? names[0] : "";
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: perScreen
            required property ShellScreen modelData
            readonly property bool primary: modelData.name === shell.primaryName

            LazyLoader {
                active: perScreen.primary
                Blades { screen: perScreen.modelData }
            }
            LazyLoader {
                active: !perScreen.primary
                Backdrop { screen: perScreen.modelData }
            }
        }
    }

    // `qs -c xbox360 ipc call blades <fn>` — what the controller daemon and
    // any keybind use to move between blades.
    IpcHandler {
        target: "blades"

        function current(): int {
            const ws = Hyprland.focusedWorkspace;
            return ws && ws.id >= 1 && ws.id <= 5 ? ws.id : 0;
        }
        function go(n: int): void { Hyprland.dispatch("workspace " + n); }
        function next(): void {
            const c = current();
            if (c < 5) Hyprland.dispatch("workspace " + (c + 1));
        }
        function prev(): void {
            const c = current();
            if (c > 1) Hyprland.dispatch("workspace " + (c - 1));
            else if (c === 0) Hyprland.dispatch("workspace 5");
        }
    }
}
