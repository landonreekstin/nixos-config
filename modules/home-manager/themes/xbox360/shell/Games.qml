// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Games.qml
// Every installed game (Steam and Heroic), newest-played first, from the
// generated scanner (Config.gamesCmd, pad/xbox360-games.py). Loaded at start
// and refreshed whenever the Games Library opens.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Singleton {
    id: games

    property var list: []
    property bool loaded: false

    function refresh() { if (!proc.running) proc.running = true; }

    function play(g) {
        ShellState.play("select-a");
        ShellState.launch(g.cmd, g.name, 2);
    }

    Process {
        id: proc
        command: [Cfg.gamesCmd, Cfg.gamesConfig]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { games.list = JSON.parse(text); } catch (e) {}
                games.loaded = true;
            }
        }
    }
}
