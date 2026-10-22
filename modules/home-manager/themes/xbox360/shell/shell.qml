// ~/nixos-config/modules/home-manager/themes/xbox360/shell/shell.qml
// Xbox 360 "Blades" dashboard shell, started by the xbox360 Hyprland session
// as `qs -c xbox360`. Every screen gets a Frame; the primary one also carries
// the dashboard (workspace name:dashboard). Shared state lives in ShellState.
//
// Icons come from Papirus, which the century-series theme installs; without
// a pragma Quickshell would use Qt's (empty) default theme.
//@ pragma IconTheme Papirus
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
        delegate: Frame {
            required property ShellScreen modelData
            screen: modelData
            primary: modelData.name === shell.primaryName
        }
    }

    // `qs -c xbox360 ipc call ui <fn>` — keybinds, scripts and the controller
    // daemon all come in here.
    IpcHandler {
        target: "ui"

        // A controller button (a b x y up down left right lb rb lt rt start
        // back): "taken" if the shell's UI used it, "pass" if nothing is open.
        function input(btn: string): string { return ShellState.input(btn) ? "taken" : "pass"; }
        function dashboard(): void { ShellState.dashboard(); }
        function resume(): void { ShellState.resume(); }
        // Toggle between the dashboard and the last app.
        function home(): void {
            if (ShellState.onDashboard) ShellState.resume();
            else ShellState.dashboard();
        }
        function launch(cmd: string, title: string): void { ShellState.launch(cmd, title, 5); }
    }
}
