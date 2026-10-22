// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Theme.qml
// Day or night: which palette the shell paints with. colors.nix makes both
// under the same keys (Config.blades / Config.bladesNight, ...), so a consumer
// reads Theme.blades where it used to read Config.blades and never needs to
// know which one it got.
//
// Night Mode is Auto, On or Off (System blade, Guide -> Console Settings),
// saved in Quickshell's state dir. Auto follows century-series' own sunset
// reckoning (`century-night status` prints sun=day|night) when the host has
// it, else the clock (7 pm to 7 am).
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Singleton {
    id: theme

    property string mode: "auto"          // auto | on | off
    property bool sunDown: false
    readonly property bool night: mode === "on" || (mode === "auto" && sunDown)

    readonly property var blades: night ? Cfg.bladesNight : Cfg.blades
    readonly property var silver: night ? Cfg.silverNight : Cfg.silver
    // The Guide's colours only; its commands stay in Config.guide.
    readonly property var guide: night ? Cfg.guideNight : Cfg.guide
    readonly property color backdrop: night ? "#" + Cfg.backdropNight : "#9a9a9a"
    // Text on the highlighted row's white wash: the ink by day, dark at night.
    function onWash(ink) { return night ? "#" + Cfg.washInkNight : ink; }
    // The card's white gloss, sheen and ripples: dimmed at night (blade.frag).
    property real glow: night ? 0.3 : 1
    Behavior on glow { NumberAnimation { duration: 1200 } }

    readonly property string modeText: ({ auto: "Auto", on: "On", off: "Off" })[mode]
    function cycle(dir) {
        const order = ["auto", "on", "off"];
        setMode(order[(order.indexOf(mode) + (dir < 0 ? 2 : 1)) % 3]);
    }
    function setMode(m) {
        mode = m;
        store.setText(JSON.stringify({ night: m }));
        if (m === "auto") sun.running = true;
    }

    FileView {
        id: store
        path: Quickshell.statePath("settings.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const m = JSON.parse(text()).night;
                if (["auto", "on", "off"].indexOf(m) >= 0) theme.mode = m;
            } catch (e) {}
        }
    }

    // ---- the sun -------------------------------------------------------------
    function byClock() {
        const h = new Date().getHours();
        return h >= 19 || h < 7;
    }
    Process {
        id: sun
        command: ["sh", "-c", Cfg.nightStatusCmd]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /sun=(day|night)/.exec(text);
                theme.sunDown = m ? m[1] === "night" : theme.byClock();
            }
        }
    }
    Timer {
        interval: 5 * 60 * 1000
        running: theme.mode === "auto"
        repeat: true
        onTriggered: if (!sun.running) sun.running = true
    }
}
