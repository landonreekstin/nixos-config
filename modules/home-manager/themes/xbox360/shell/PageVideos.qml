// ~/nixos-config/modules/home-manager/themes/xbox360/shell/PageVideos.qml
// Media -> Videos: the Jellyfin library, in the console's list-and-details
// layout (games-submenu.png). Tabs across the top (LB/RB): Continue Watching,
// Next Up, then each of the server's movie and show libraries. A on a movie or
// episode plays it in mpv on a workspace of its own, from where you left off;
// A on a show opens its episodes, and B steps back out.
//
// Not signed in yet: the page shows a Quick Connect code to approve from any
// signed-in Jellyfin (Settings -> Quick Connect).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Config.js" as Cfg

Item {
    id: page

    property real s: 1
    property var bladeSpec: Theme.blades[3]
    readonly property color ink: "#" + bladeSpec.ink

    // ---- data -----------------------------------------------------------------
    property var tabs: []           // [{ label, path }]
    property int tab: 0
    property var stack: []          // drilled-in levels: [{ label, items, current }]
    property var items: []
    property int current: 0
    property bool loading: false
    property string error: ""

    readonly property string uid: Jellyfin.userId
    readonly property string fields: "&Fields=Overview,ProductionYear,RunTimeTicks,UserData"

    Component.onCompleted: if (Jellyfin.signedIn) loadTabs(); else if (Jellyfin.configured) Jellyfin.startQuickConnect();
    Connections {
        target: Jellyfin
        function onSignedInChanged() { if (Jellyfin.signedIn) page.loadTabs(); }
    }

    function loadTabs() {
        const t = [
            { label: "Continue Watching", path: "/Users/" + uid + "/Items/Resume?Limit=40&MediaTypes=Video" + fields },
            { label: "Next Up", path: "/Shows/NextUp?UserId=" + uid + "&Limit=40" + fields }
        ];
        Jellyfin.request("GET", "/Users/" + uid + "/Views", null, (err, d) => {
            if (err === "" && d) {
                for (const v of d.Items) {
                    if (v.CollectionType !== "movies" && v.CollectionType !== "tvshows") continue;
                    t.push({ label: v.Name, path: "/Users/" + uid + "/Items?ParentId=" + v.Id
                        + "&Recursive=true&SortBy=SortName&IncludeItemTypes=Movie,Series&Limit=2000" + fields });
                }
            }
            tabs = t;
            tab = 0;
            loadTab();
        });
    }

    function load(path, cb) {
        loading = true;
        error = "";
        Jellyfin.request("GET", path, null, (err, d) => {
            loading = false;
            if (err !== "") { error = err; cb([]); return; }
            cb(d && d.Items ? d.Items : []);
        });
    }

    function loadTab() {
        stack = [];
        items = [];
        current = 0;
        if (tabs[tab]) load(tabs[tab].path, list => { items = list; });
    }

    function setTab(t) {
        if (t < 0 || t >= tabs.length || t === tab || stack.length > 0) return;
        ShellState.play(t > tab ? "page-right" : "page-left");
        tab = t;
        loadTab();
    }

    function open(it) {
        if (!it) return;
        if (it.Type === "Series") {
            ShellState.play("select-a");
            stack = stack.concat([{ label: it.Name, items: items, current: current }]);
            items = [];
            current = 0;
            load("/Shows/" + it.Id + "/Episodes?UserId=" + uid + fields, list => {
                items = list;
                // Start on the first episode not yet watched.
                const i = list.findIndex(e => !(e.UserData && e.UserData.Played));
                current = Math.max(0, i);
            });
            return;
        }
        ShellState.play("select-a");
        ShellState.launch(Cfg.jellyfinPlay + " " + Jellyfin.statePath + " " + it.Id, label(it), 3);
    }

    function back() {
        ShellState.play("back");
        if (stack.length > 0) {
            const top = stack[stack.length - 1];
            stack = stack.slice(0, -1);
            items = top.items;
            current = top.current;
        } else {
            ShellState.closePage();
        }
    }

    function label(it) {
        if (it.Type === "Episode")
            return (it.SeriesName && stack.length === 0 ? it.SeriesName + " — " : "")
                + "S" + (it.ParentIndexNumber || 0) + " E" + (it.IndexNumber || 0) + "  " + it.Name;
        return it.Name + (it.ProductionYear ? " (" + it.ProductionYear + ")" : "");
    }

    function handle(btn) {
        if (!Jellyfin.signedIn) {
            if (btn === "b") { back(); return true; }
            if (btn === "a" && Jellyfin.qcState !== "waiting") { Jellyfin.startQuickConnect(); return true; }
            return true;
        }
        switch (btn) {
        case "up": if (current > 0) { current--; ShellState.play("select"); } return true;
        case "down": if (current < items.length - 1) { current++; ShellState.play("select"); } return true;
        case "lb": case "left": setTab(tab - 1); return true;
        case "rb": case "right": setTab(tab + 1); return true;
        case "lt": current = Math.max(0, current - perPage); return true;
        case "rt": current = Math.min(items.length - 1, current + perPage); return true;
        case "a": open(items[current]); return true;
        case "b": back(); return true;
        }
        return false;
    }

    // ---- sign-in ------------------------------------------------------------------
    Column {
        anchors.centerIn: parent
        width: parent.width * 0.8
        spacing: 18 * page.s
        visible: !Jellyfin.signedIn

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: !Jellyfin.configured ? "No media server is set up for this console."
                : Jellyfin.qcState === "error" ? Jellyfin.error + "\nPress A to try again."
                : "Sign in to your media server. On your phone or another screen, open Jellyfin, go to Settings → Quick Connect, and enter this code:"
            font.family: Cfg.font
            font.pixelSize: 24 * page.s
            color: page.ink
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: Jellyfin.qcState === "waiting"
            text: Jellyfin.qcCode !== "" ? Jellyfin.qcCode.split("").join(" ") : "…"
            font.family: Cfg.font
            font.pixelSize: 72 * page.s
            font.letterSpacing: 6 * page.s
            color: "white"
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.3)
        }
        LoadingRing {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Jellyfin.qcState === "waiting"
            size: 50 * page.s
        }
    }

    // ---- the library ----------------------------------------------------------------
    readonly property real rowH: 46 * s
    readonly property int perPage: Math.max(1, Math.floor(listBox.height / rowH))
    readonly property int first: Math.floor(current / perPage) * perPage

    Item {
        anchors.fill: parent
        visible: Jellyfin.signedIn

        // Tab strip, or the show's name when drilled in.
        Row {
            id: tabRow
            spacing: 34 * page.s
            Repeater {
                model: page.stack.length > 0 ? [{ label: page.stack[page.stack.length - 1].label }] : page.tabs
                delegate: Text {
                    required property var modelData
                    required property int index
                    text: modelData.label
                    font.family: Cfg.font
                    font.pixelSize: 24 * page.s
                    color: "white"
                    opacity: page.stack.length > 0 || index === page.tab ? 1 : 0.55
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.28)
                    MouseArea { anchors.fill: parent; onClicked: page.setTab(parent.index) }
                }
            }
        }
        Rectangle {
            y: tabRow.height + 8 * page.s
            width: parent.width
            height: 2 * page.s
            color: Qt.rgba(1, 1, 1, 0.45)
        }

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
                        readonly property var ud: modelData.UserData || {}
                        width: listBox.width
                        height: page.rowH
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            if (!selected && ShellState.pointerMoved(row, mouse.x, mouse.y)) {
                                page.current = absolute;
                                ShellState.play("select");
                            }
                        }
                        onClicked: { page.current = absolute; page.open(modelData); }

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
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 50 * page.s
                            elide: Text.ElideRight
                            text: page.label(row.modelData)
                            font.family: Cfg.font
                            font.pixelSize: 21 * page.s
                            color: row.selected ? Theme.onWash(page.ink) : page.ink
                        }
                        Text {   // watched
                            anchors.right: parent.right
                            anchors.rightMargin: 12 * page.s
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.ud.Played === true
                            text: "✓"
                            font.pixelSize: 20 * page.s
                            color: "#43b039"
                        }
                        Rectangle {   // partly watched
                            visible: (row.ud.PlayedPercentage || 0) > 0 && row.ud.Played !== true
                            x: 10 * page.s
                            y: parent.height - 9 * page.s
                            width: parent.width - 20 * page.s
                            height: 4 * page.s
                            radius: height / 2
                            color: Qt.rgba(0, 0, 0, 0.15)
                            Rectangle {
                                width: parent.width * (row.ud.PlayedPercentage || 0) / 100
                                height: parent.height
                                radius: parent.radius
                                color: "white"
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: page.items.length === 0
                text: page.loading ? "Loading…" : page.error !== "" ? page.error : "Nothing here yet."
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

        // The highlighted item.
        Rectangle {
            id: detail
            readonly property var it: page.items[page.current] || null
            x: parent.width * 0.52
            y: listBox.y
            width: parent.width - x
            height: listBox.height
            radius: 8 * page.s
            color: Qt.rgba(1, 1, 1, 0.16)
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.55)
            visible: it !== null
            clip: true

            Image {
                id: poster
                x: 14 * page.s
                y: 14 * page.s
                width: parent.width * 0.42
                height: Math.min(width * 1.5, parent.height - 28 * page.s)
                fillMode: Image.PreserveAspectFit
                verticalAlignment: Image.AlignTop
                sourceSize.height: height * 1.2
                asynchronous: true
                source: detail.it ? Jellyfin.image(detail.it.Id, 450) : ""
            }
            Column {
                x: poster.x + poster.width + 14 * page.s
                y: poster.y
                width: parent.width - x - 14 * page.s
                spacing: 6 * page.s
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: detail.it ? detail.it.Name : ""
                    font.family: Cfg.font
                    font.pixelSize: 23 * page.s
                    color: page.ink
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: {
                        const it = detail.it;
                        if (!it) return "";
                        const bits = [];
                        if (it.ProductionYear) bits.push(it.ProductionYear);
                        if (it.RunTimeTicks) bits.push(Math.round(it.RunTimeTicks / 600000000) + " min");
                        if (it.Type === "Series") bits.push("Show");
                        return bits.join("  ·  ");
                    }
                    font.family: Cfg.font
                    font.pixelSize: 18 * page.s
                    color: page.ink
                    opacity: 0.8
                }
                Text {
                    width: parent.width
                    height: detail.height - y - 28 * page.s
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    text: detail.it && detail.it.Overview ? detail.it.Overview : ""
                    font.family: Cfg.font
                    font.pixelSize: 17 * page.s
                    color: page.ink
                }
            }
        }
    }
}
