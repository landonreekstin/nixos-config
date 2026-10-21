// ~/nixos-config/modules/home-manager/themes/xbox360/shell/PageUpdates.qml
// Marketplace -> System Update: where this console's configuration stands —
// the branch and commit it is on, how far behind main it is, when it was last
// rebuilt, and the weekly flake-update PR (which merges itself on Mondays) —
// with the actions to act on it, each run in a terminal on its own workspace.
// Status comes from the generated Config.updatesCmd.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Item {
    id: page

    property real s: 1
    property var bladeSpec: Theme.blades[0]
    readonly property color ink: "#" + bladeSpec.ink
    property var st: null
    property int current: 0

    readonly property var actions: [
        { label: "Update now", icon: "system-software-update", cmd: "update",
          desc: "Pull the latest configuration and rebuild, the same as the weekly automatic update." },
        { label: "Rebuild", icon: "view-refresh", cmd: "rebuild",
          desc: "Rebuild this console from the configuration it already has." },
        { label: "Update and turn off", icon: "system-shutdown", cmd: "update-shutdown",
          desc: "Update, then turn the console off when it is done. Good for the end of the night." }
    ]

    function handle(btn) {
        switch (btn) {
        case "up": if (current > 0) { current--; ShellState.play("select"); } return true;
        case "down": if (current < actions.length - 1) { current++; ShellState.play("select"); } return true;
        case "a": {
            const a = actions[current];
            ShellState.play("select-a");
            ShellState.closePage();
            ShellState.launch(Cfg.terminal + " -e " + a.cmd, a.label, 0);
            return true;
        }
        case "b": ShellState.play("back"); ShellState.closePage(); return true;
        }
        return false;
    }

    Process {
        command: [Cfg.updatesCmd]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.st = JSON.parse(text); } catch (e) { page.st = {}; } }
        }
    }

    function ago(ts) {
        if (!ts) return "";
        const h = Math.floor((Date.now() / 1000 - ts) / 3600);
        if (h < 1) return "less than an hour ago";
        if (h < 48) return h + (h === 1 ? " hour ago" : " hours ago");
        return Math.floor(h / 24) + " days ago";
    }

    readonly property var facts: {
        const s = st;
        if (s === null) return [["Checking…", ""]];
        const out = [];
        if (s.branch) out.push(["Configuration", s.branch + " at " + s.commit + (s.committed ? ", " + ago(s.committed) : "")]);
        if (s.behind !== undefined && s.behind !== null)
            out.push(["Behind main", s.behind === 0 ? "Up to date" : s.behind + (s.behind === 1 ? " change" : " changes")]);
        if (s.built) out.push(["Last rebuilt", ago(s.built)]);
        if (s.pr) out.push(["Weekly update", "#" + s.pr.number + (s.pr.blocked ? " — blocked" : " — merges on Monday")]);
        else if (s.pr === null) out.push(["Weekly update", "None waiting"]);
        return out;
    }

    // ---- status ------------------------------------------------------------
    Column {
        id: factsCol
        width: parent.width * 0.48
        spacing: 2 * page.s
        Repeater {
            model: page.facts
            delegate: Item {
                required property var modelData
                width: factsCol.width
                height: 40 * page.s
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData[0]
                    font.family: Cfg.font
                    font.pixelSize: 21 * page.s
                    color: page.ink
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.6
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: parent.modelData[1]
                    font.family: Cfg.font
                    font.pixelSize: 21 * page.s
                    color: page.ink
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 2 * page.s
                    color: "#" + page.bladeSpec.rule
                    opacity: 0.6
                }
            }
        }
    }

    // ---- actions -----------------------------------------------------------
    Column {
        id: actionCol
        x: 0
        anchors.bottom: parent.bottom
        width: parent.width * 0.48
        Repeater {
            model: page.actions
            delegate: MenuRow {
                required property var modelData
                required property int index
                width: actionCol.width
                height: Cfg.rowHeight * page.s
                s: page.s
                ink: page.ink
                rule: "#" + page.bladeSpec.rule
                label: modelData.label
                icon: modelData.icon
                selected: page.current === index
                onHovered: page.current = index
                onClicked: { page.current = index; page.handle("a"); }
            }
        }
    }

    Text {
        x: parent.width * 0.53
        width: parent.width - x
        wrapMode: Text.WordWrap
        text: page.actions[page.current].desc
        font.family: Cfg.font
        font.pixelSize: Cfg.descSize * page.s
        color: page.ink
    }
}
