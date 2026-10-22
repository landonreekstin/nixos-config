// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Displays.qml
// The displays, for Guide -> Displays: each configured monitor, whether it is
// on, which one has focus, and turning one on or off.
//
// On/off goes through century-series' own `toggle-monitor`
// (scripts/toggle-monitor.nix): it writes ~/.local/state/hypr/disabled-monitors,
// which `restore-monitors` re-applies at login and `monitor-state-watcher`
// after every config reload, so a display turned off here stays off through a
// rebuild and a reboot, in both sessions. TV Mode writes the same file.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Config.js" as Cfg

Singleton {
    id: displays

    // `hyprctl monitors -j all`: disabled ones included, which Quickshell's
    // own monitor list leaves out.
    property var live: []

    // One entry per display: the host's configured monitors (by their name:
    // main, left, ...), else whatever Hyprland knows (a VM).
    readonly property var list: {
        const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        const find = id => live.find(m => id.startsWith("desc:")
            ? m.description.startsWith(id.slice(5)) : m.name === id) || null;
        const base = Cfg.monitors.length > 0 ? Cfg.monitors
            : live.map(m => ({ id: m.name, label: m.name, rule: m.name + ", preferred, auto, 1" }));
        return base.map(c => {
            const m = find(c.id);
            return {
                id: c.id, label: c.label, rule: c.rule,
                name: m ? m.name : (c.id.startsWith("desc:") ? "" : c.id),
                on: m !== null && !m.disabled,
                present: m !== null,
                focused: m !== null && m.name === focused,
                size: m && !m.disabled ? m.width + "x" + m.height + " at " + Math.round(m.refreshRate) + " Hz" : ""
            };
        });
    }
    readonly property int onCount: list.filter(d => d.on).length

    function refresh() { if (!query.running) query.running = true; }

    Process {
        id: query
        command: [Cfg.hyprctl, "-j", "monitors", "all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { displays.live = JSON.parse(text); } catch (e) {} }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name.startsWith("monitoradded") || event.name.startsWith("monitorremoved")
                || event.name === "configreloaded")
                displays.refresh();
        }
    }

    function focus(d) {
        if (!d.on || d.name === "") return;
        Hyprland.dispatch("focusmonitor " + d.name);
    }

    // Turn a display on or off. Returns "" or why it can't.
    function toggle(d) {
        if (d.on && onCount <= 1) return "It's your only screen.";
        if (!d.present) return "It isn't connected.";
        if (d.on && d.focused) {
            // Focus somewhere that stays on first: the main display, else any.
            const next = list.find(x => x.on && x.id !== d.id && x.label === "Main")
                      || list.find(x => x.on && x.id !== d.id);
            if (next) Hyprland.dispatch("focusmonitor " + next.name);
        }
        // Turning displays on and off by hand ends TV Mode's bookkeeping
        // without putting its saved state back.
        const tv = Cfg.tvCmd !== "" ? Cfg.tvCmd + " forget; " : "";
        toggler.command = ["sh", "-c", tv + "export PATH=$PATH:/etc/profiles/per-user/$USER/bin; toggle-monitor \"$0\" \"$1\"",
                           d.id, d.rule];
        toggler.running = true;
        return "";
    }
    Process {
        id: toggler
        onExited: { displays.refresh(); ShellState.refreshTv(); }
    }
}
