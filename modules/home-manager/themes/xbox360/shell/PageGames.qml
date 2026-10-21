// ~/nixos-config/modules/home-manager/themes/xbox360/shell/PageGames.qml
// Games -> Games Library, laid out like the console's "My Games"
// (games-submenu.png): a strip of filter tabs across the top (LB/RB), the
// games on the left with their icons, a screenful at a time ("1 of 7"), and
// the highlighted game's cover and details in a box on the right. A plays it
// on a workspace of its own.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Config.js" as Cfg

Item {
    id: page

    property real s: 1
    property var bladeSpec: Cfg.blades[2]
    readonly property color ink: "#" + bladeSpec.ink

    Component.onCompleted: Games.refresh()

    // Filter tabs; a tab with nothing in it is left out.
    readonly property var tabs: {
        const all = Games.list;
        const t = [{ label: "All Games", items: all }];
        for (const src of ["Steam", "Epic", "GOG"]) {
            const items = all.filter(g => g.source === src);
            if (items.length > 0) t.push({ label: src, items: items });
        }
        const recent = all.filter(g => g.lastPlayed > 0).slice(0, 12);
        if (recent.length > 0) t.push({ label: "Recently Played", items: recent });
        return t;
    }
    property int tab: 0
    property int current: 0
    readonly property var items: tabs[Math.min(tab, tabs.length - 1)].items
    readonly property int perPage: Math.max(1, Math.floor(listBox.height / (rowH)))
    readonly property int first: Math.floor(current / perPage) * perPage
    readonly property real rowH: 46 * s

    function setTab(t) {
        if (t < 0 || t >= tabs.length || t === tab) return;
        ShellState.play(t > tab ? "page-right" : "page-left");
        tab = t;
        current = 0;
    }

    function handle(btn) {
        switch (btn) {
        case "up": if (current > 0) { current--; ShellState.play("select"); } return true;
        case "down": if (current < items.length - 1) { current++; ShellState.play("select"); } return true;
        case "lb": case "left": setTab(tab - 1); return true;
        case "rb": case "right": setTab(tab + 1); return true;
        case "lt": current = Math.max(0, current - perPage); return true;
        case "rt": current = Math.min(items.length - 1, current + perPage); return true;
        case "a": if (items[current]) Games.play(items[current]); return true;
        case "b": ShellState.play("back"); ShellState.closePage(); return true;
        }
        return false;
    }

    function ago(ts) {
        if (!ts) return "Not played yet";
        const days = Math.floor((Date.now() / 1000 - ts) / 86400);
        if (days < 1) return "Last played today";
        if (days === 1) return "Last played yesterday";
        if (days < 30) return "Last played " + days + " days ago";
        return "Last played " + new Date(ts * 1000).toLocaleDateString(Qt.locale(), "MMMM d, yyyy");
    }

    // ---- the tab strip -------------------------------------------------------
    Row {
        id: tabRow
        x: 0
        y: 0
        spacing: 34 * page.s
        Repeater {
            model: page.tabs
            delegate: Text {
                required property var modelData
                required property int index
                text: modelData.label
                font.family: Cfg.font
                font.pixelSize: 24 * page.s
                color: "white"
                opacity: index === page.tab ? 1 : 0.55
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.28)
                MouseArea { anchors.fill: parent; onClicked: page.setTab(parent.index) }
            }
        }
    }
    Rectangle {   // the rule under the strip
        y: tabRow.height + 8 * page.s
        width: parent.width
        height: 2 * page.s
        color: Qt.rgba(1, 1, 1, 0.45)
    }

    // ---- the list ------------------------------------------------------------
    Item {
        id: listBox
        y: tabRow.height + 20 * page.s
        width: parent.width * 0.48
        height: parent.height - y - 34 * page.s

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
                    height: page.rowH
                    hoverEnabled: true
                    onPositionChanged: mouse => {
                        if (!selected && ShellState.pointerMoved(row, mouse.x, mouse.y)) {
                            page.current = absolute;
                            ShellState.play("select");
                        }
                    }
                    onClicked: Games.play(modelData)

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
                    Image {
                        id: ic
                        x: 6 * page.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: page.rowH - 12 * page.s
                        height: width
                        sourceSize: Qt.size(width * 2, height * 2)
                        fillMode: Image.PreserveAspectCrop
                        source: row.modelData.icon
                        asynchronous: true
                    }
                    Text {
                        x: ic.x + ic.width + 12 * page.s
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - 8 * page.s
                        elide: Text.ElideRight
                        text: row.modelData.name
                        font.family: Cfg.font
                        font.pixelSize: Cfg.rowSize * page.s
                        color: page.ink
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: page.items.length === 0
            text: Games.loaded ? "No games installed." : "Finding your games…"
            font.family: Cfg.font
            font.pixelSize: 22 * page.s
            color: page.ink
        }
    }
    Text {
        anchors.horizontalCenter: listBox.horizontalCenter
        anchors.bottom: parent.bottom
        visible: page.items.length > page.perPage
        text: (Math.floor(page.current / page.perPage) + 1) + " of " + Math.ceil(page.items.length / page.perPage)
        font.family: Cfg.font
        font.pixelSize: 19 * page.s
        color: page.ink
    }

    // ---- the highlighted game ----------------------------------------------------
    Rectangle {
        id: detail
        readonly property var g: page.items[page.current] || null
        x: parent.width * 0.52
        y: listBox.y
        width: parent.width - x
        height: listBox.height
        radius: 8 * page.s
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.55)
        visible: g !== null
        clip: true

        Rectangle {   // header strip, as in the capture
            width: parent.width
            height: 38 * page.s
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, 0.25)
            Text {
                x: 12 * page.s
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 * page.s
                elide: Text.ElideRight
                text: detail.g ? detail.g.name : ""
                font.family: Cfg.font
                font.pixelSize: 22 * page.s
                color: page.ink
            }
        }
        Image {
            id: art
            x: 14 * page.s
            y: 50 * page.s
            height: parent.height - y - 14 * page.s
            width: Math.min(parent.width * 0.5, height * 2 / 3)
            fillMode: Image.PreserveAspectFit
            verticalAlignment: Image.AlignTop
            sourceSize.height: height * 1.5
            source: detail.g ? detail.g.art : ""
            asynchronous: true
        }
        Column {
            x: art.x + art.width + 16 * page.s
            y: art.y
            width: parent.width - x - 14 * page.s
            spacing: 8 * page.s
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: detail.g ? detail.g.source : ""
                font.family: Cfg.font
                font.pixelSize: 21 * page.s
                color: page.ink
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: detail.g ? page.ago(detail.g.lastPlayed) : ""
                font.family: Cfg.font
                font.pixelSize: 19 * page.s
                color: page.ink
                opacity: 0.85
            }
        }
    }
}
