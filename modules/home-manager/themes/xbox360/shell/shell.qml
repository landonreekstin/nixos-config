// ~/nixos-config/modules/home-manager/themes/xbox360/shell/shell.qml
// Xbox 360 "Blades" dashboard shell, started by the xbox360 Hyprland session
// as `qs -c xbox360`. Every screen gets a Frame, and with it its own
// dashboard (workspace name:dashboard-<connector>). Shared state lives in
// ShellState.
//
// The overlays — Guide, notification blade, toasts, keyboard — open on the
// display that has focus when they open (ShellState.guideScreen and co.).
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

    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === primaryName) || null
    // A remembered screen that has since gone (a display turned off) is no
    // place to open anything: fall back to the primary one.
    function live(scr) { return scr && Quickshell.screens.indexOf(scr) >= 0 ? scr : primaryScreen; }

    // Each toast on the display focused when it pops up.
    property var toastScreen: null
    Connections {
        target: Notifications
        function onToastChanged() { if (Notifications.toast !== null) shell.toastScreen = ShellState.focusedScreen(); }
    }

    // The Guide (left), the notification blade (right) and the toasts.
    // Touching Notifications here starts the server.
    LazyLoader {
        active: shell.primaryScreen !== null
        Guide { screen: shell.live(ShellState.guideScreen) }
    }
    LazyLoader {
        active: shell.primaryScreen !== null
        NotificationBlade { screen: shell.live(ShellState.messageScreen) }
    }
    LazyLoader {
        active: shell.primaryScreen !== null && Notifications.count >= 0
        Toast { screen: shell.live(shell.toastScreen) }
    }

    // The session lock (Sign Out, SUPER+Escape, swayidle).
    LockScreen {}
    Binding { target: ShellState; property: "primaryName"; value: shell.primaryName }

    // The on-screen keyboard, over everything.
    LazyLoader {
        active: shell.primaryScreen !== null
        Keyboard { screen: shell.live(ShellState.keyboardScreen) }
    }

    Variants {
        model: Quickshell.screens
        delegate: Frame {
            required property ShellScreen modelData
            screen: modelData
            primary: modelData !== null && modelData.name === shell.primaryName
        }
    }

    // `qs -c xbox360 ipc call ui <fn>` — keybinds, scripts and the controller
    // daemon all come in here. Everything acts on the focused display.
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
        function guide(): void { ShellState.guide(); }
        function lock(): void { ShellState.signOut(); }
        function power(): void { ShellState.powerPrompt(); }
        function keyboard(): void { ShellState.toggleKeyboard(); }
        // The focused app to the previous (-1) or next (1) display.
        function movewin(step: int): void { ShellState.moveToMonitor(step < 0 ? -1 : 1); }
        // Guide -> Displays.
        function displays(): void { ShellState.openGuideAt("displays"); }
    }
}
