// ~/nixos-config/modules/home-manager/themes/xbox360/shell/PageDownloads.qml
// Marketplace -> Downloads: the NAS's torrents, laid out like the console's
// "My Games" page (games-submenu.png) — a list on the left with a progress
// bar per row, the highlighted download's details in a box on the right.
// Polled from Transmission's RPC (Config.downloadsCmd) every 3 s while open.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Item {
    id: page

    property real s: 1
    property var bladeSpec: Cfg.blades[0]
    readonly property color ink: "#" + bladeSpec.ink

    property var items: []
    property string error: ""
    property int current: 0
    readonly property int perPage: Math.max(1, Math.floor(listBox.height / (Cfg.rowHeight * s)))
    // The list pages a screenful at a time, as the console's did ("1 of 7").
    readonly property int first: Math.floor(current / perPage) * perPage

    function handle(btn) {
        switch (btn) {
        case "up": if (current > 0) { current--; ShellState.play("select"); } return true;
        case "down": if (current < items.length - 1) { current++; ShellState.play("select"); } return true;
        case "lt": current = Math.max(0, current - perPage); return true;
        case "rt": current = Math.min(items.length - 1, current + perPage); return true;
        case "b": ShellState.play("back"); ShellState.closePage(); return true;
        case "a": return true;
        }
        return false;
    }

    function fmtRate(b) {
        if (b <= 0) return "";
        if (b > 1048576) return (b / 1048576).toFixed(1) + " MB/s";
        return Math.round(b / 1024) + " KB/s";
    }
    function fmtEta(e) {
        if (e < 0) return "";
        if (e > 3600) return Math.floor(e / 3600) + " h " + Math.floor(e % 3600 / 60) + " min";
        if (e > 60) return Math.floor(e / 60) + " min";
        return e + " s";
    }
    function fmtSize(b) {
        if (b > 1073741824) return (b / 1073741824).toFixed(1) + " GB";
        return Math.round(b / 1048576) + " MB";
    }

    Process {
        id: poll
        command: [Cfg.downloadsCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    // Active first, then by progress, the way a queue reads.
                    list.sort((a, b) => (b.rate > 0) - (a.rate > 0) || a.pct - b.pct);
                    page.items = list;
                    page.error = "";
                    if (page.current >= list.length) page.current = Math.max(0, list.length - 1);
                } catch (e) {
                    page.error = "Can't reach the download server.";
                }
            }
        }
    }
    Timer {
        interval: 3000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    // ---- the list ----------------------------------------------------------
    Item {
        id: listBox
        x: 0
        y: 0
        width: parent.width * 0.5
        height: parent.height - 34 * page.s

        Column {
            width: parent.width
            Repeater {
                model: page.items.slice(page.first, page.first + page.perPage)
                delegate: MouseArea {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property int absolute: page.first + index
                    readonly property bool selected: absolute === page.current
                    width: listBox.width
                    height: Cfg.rowHeight * page.s
                    hoverEnabled: true
                    onPositionChanged: mouse => {
                        if (!selected && ShellState.pointerMoved(row, mouse.x, mouse.y)) {
                            page.current = absolute;
                            ShellState.play("select");
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 2 * page.s
                        radius: 4 * page.s
                        visible: row.selected
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.92) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.1) }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2 * page.s
                        color: "#" + page.bladeSpec.rule
                        opacity: 0.8
                    }
                    Text {
                        x: 10 * page.s
                        y: 4 * page.s
                        width: parent.width - 20 * page.s
                        elide: Text.ElideRight
                        text: row.modelData.name
                        font.family: Cfg.font
                        font.pixelSize: 19 * page.s
                        color: page.ink
                    }
                    // Progress: a slim bar along the bottom of the row.
                    Rectangle {
                        x: 10 * page.s
                        y: parent.height - 12 * page.s
                        width: parent.width - 20 * page.s
                        height: 5 * page.s
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.15)
                        Rectangle {
                            width: parent.width * row.modelData.pct
                            height: parent.height
                            radius: parent.radius
                            color: row.modelData.pct >= 1 ? "#43b039" : "#ffffff"
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: page.items.length === 0
            text: page.error !== "" ? page.error : "No downloads."
            font.family: Cfg.font
            font.pixelSize: 22 * page.s
            color: page.ink
        }
    }

    Text {
        anchors.horizontalCenter: listBox.horizontalCenter
        anchors.bottom: parent.bottom
        visible: page.items.length > 0
        text: (page.current + 1) + " of " + page.items.length
        font.family: Cfg.font
        font.pixelSize: 19 * page.s
        color: page.ink
    }

    // ---- details of the highlighted download ------------------------------
    Rectangle {
        id: detailBox
        x: parent.width * 0.53
        y: 0
        width: parent.width - x
        height: parent.height - 34 * page.s
        radius: 8 * page.s
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.55)
        visible: page.items.length > 0
        readonly property var it: page.items[page.current] || {}

        Column {
            x: 16 * page.s
            y: 12 * page.s
            width: parent.width - 32 * page.s
            spacing: 8 * page.s

            component Detail: Text {
                width: parent.width
                wrapMode: Text.WordWrap
                font.family: Cfg.font
                font.pixelSize: 21 * page.s
                color: page.ink
            }

            Detail { text: detailBox.it.name || ""; font.pixelSize: 23 * page.s; maximumLineCount: 3; elide: Text.ElideRight }
            Detail { text: Math.round((detailBox.it.pct || 0) * 100) + "% of " + page.fmtSize(detailBox.it.size || 0) }
            Detail { text: detailBox.it.statusText || "" }
            Detail { text: page.fmtRate(detailBox.it.rate || 0); visible: text !== "" }
            Detail { text: page.fmtEta(detailBox.it.eta === undefined ? -1 : detailBox.it.eta) !== ""
                         ? "About " + page.fmtEta(detailBox.it.eta) + " left" : ""; visible: text !== "" }
        }
    }
}
