// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Audio.qml
// The sound devices, for Guide -> Audio: the host's audioDevices (Speakers,
// Headphones, TV, Headset...), which are plugged in, which is in use, and
// switching — output and microphone together — through Config.audioCmd
// (pad/xbox360-audio.py). Empty when the host lists none.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Singleton {
    id: audio

    readonly property bool enabled: Cfg.audioCmd !== ""
    // [{ label, icon, present, active, micActive, sink, source, keepOnTv }]
    property var list: []
    readonly property var current: list.find(d => d.active) || null
    readonly property string currentLabel: current ? current.label : ""

    // A reading taken before the latest switch is stale: it is dropped and
    // the devices are read again, or it would undo the switch on screen.
    property int generation: 0
    property bool again: false
    function refresh() {
        if (!enabled) return;
        if (query.running) { again = true; return; }
        query.gen = generation;
        query.running = true;
    }

    Process {
        id: query
        property int gen: 0
        command: [Cfg.audioCmd, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (query.gen === audio.generation) {
                    try { audio.list = JSON.parse(text); } catch (e) {}
                } else audio.again = true;
            }
        }
        onExited: if (audio.again) { audio.again = false; audio.refresh(); }
    }
    Component.onCompleted: refresh()
    // Headsets come and go, and TV Mode moves the sound behind our back:
    // looked at again every few seconds while the Guide is open.
    Timer {
        interval: 3000
        running: audio.enabled && ShellState.guideOpen
        triggeredOnStart: true
        repeat: true
        onTriggered: audio.refresh()
    }

    // Returns "" or why it can't.
    function choose(d) {
        if (!d.present) return d.label + " isn't connected.";
        if (d.active && d.micActive) return "";
        // Shown as chosen at once: the switch itself takes a moment.
        generation++;
        list = list.map(x => Object.assign({}, x, { active: x.label === d.label }));
        switcher.label = d.label;
        switcher.icon = d.icon;
        switcher.command = [Cfg.audioCmd, "set", d.label];
        switcher.running = true;
        return "";
    }
    Process {
        id: switcher
        property string label: ""
        property string icon: ""
        stdout: StdioCollector {}
        onExited: code => {
            audio.refresh();
            if (code === 0) Notifications.say("Audio: " + switcher.label, "Sound and microphone switched.", switcher.icon, "audio");
        }
    }

    // X on the Audio page: century-series' left/right swap on the current output.
    function flip() {
        flipper.running = true;
    }
    Process {
        id: flipper
        command: ["sh", "-c", "export PATH=$PATH:/etc/profiles/per-user/$USER/bin; toggle-audio-flip"]
        onExited: audio.refresh()
    }
}
