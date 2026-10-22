// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Guide.qml
// The Guide, as the 2005 console had it (guide.png): a blade from the LEFT
// over whatever is running, the rest dimmed — not the later centre box. It
// opens with a tap of the Guide button (or SUPER+Space).
//
// Main page, top to bottom: the gamer card; Open Apps, Messages (Signal),
// Party Chat (Discord), Notifications, Console Settings, Turn Off Console; the
// music player strip (MPRIS — Spotify when it is running) with Select Music;
// and the big XBOX 360 button back to the dashboard. Y anywhere is "Xbox
// Dashboard", as on the console. Rows that open a list widen the blade into a
// submenu (guide-submenu.png): Open Apps, Console Settings, Notifications.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "Config.js" as Cfg

SidePanel {
    id: guide

    open: ShellState.guideOpen
    fromLeft: true
    widthRef: page === "" ? 560 : 880
    title: ({ "": "", apps: "Open Apps", settings: "Console Settings", notifications: "Notifications" })[page]
    bandLabel: Cfg.gamertag
    onDismissed: close()

    property string page: ""          // "" = the main page, else a submenu
    property int cur: 0               // focused entry on the current page
    property int mediaCur: 0          // focused button within the music strip

    legend: page === ""
        ? { left: [{ btn: "y", label: "Xbox Dashboard" }, { btn: "x", label: "Sign Out" }],
            right: [{ btn: "b", label: "Back" }, { btn: "a", label: "Select" }] }
        : { left: [{ btn: "y", label: "Xbox Dashboard" },
                   { btn: "x", label: page === "apps" ? "Close App" : page === "notifications" ? "Dismiss" : page === "settings" ? "More" : "" }],
            right: [{ btn: "b", label: "Back" }, { btn: "a", label: "Select" }] }

    onOpenChanged: if (open) { page = ""; cur = 0; ShellState.play("select-a"); }

    function close() {
        ShellState.play("back");
        ShellState.guideOpen = false;
    }

    // ---- input -------------------------------------------------------------
    QtObject {
        id: handler
        property bool active: ShellState.guideOpen
        property int priority: 10
        function handle(btn) { return guide.handle(btn); }
    }
    Component.onCompleted: ShellState.pushHandler(handler)
    Component.onDestruction: ShellState.removeHandler(handler)

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const map = {
                [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                [Qt.Key_Return]: "a", [Qt.Key_Enter]: "a", [Qt.Key_Space]: "a",
                [Qt.Key_Escape]: "b", [Qt.Key_Backspace]: "b", [Qt.Key_X]: "x", [Qt.Key_Y]: "y"
            };
            const btn = map[event.key];
            if (btn !== undefined && guide.handle(btn)) event.accepted = true;
        }
    }

    function handle(btn) {
        if (btn === "y") { ShellState.play("select-a"); ShellState.fromGuide(() => ShellState.dashboard()); return true; }
        if (btn === "b") {
            if (page !== "") { page = ""; cur = 0; ShellState.play("back"); }
            else close();
            return true;
        }
        if (page === "") return mainHandle(btn);
        return listHandle(btn);
    }

    // ---- the main page -----------------------------------------------------
    readonly property var player: {
        const ps = Mpris.players.values;
        return ps.find(p => /spotify/i.test(p.identity)) || ps.find(p => p.isPlaying) || ps[0] || null;
    }

    readonly property var rows: [
        { label: "Open Apps", icon: "view-app-grid", value: String(ShellState.appCount),
          run: () => { page = "apps"; cur = 0; } },
        { label: "Messages", icon: "signal-desktop", value: "", show: Cfg.guide.messages !== "",
          run: () => launch(Cfg.guide.messages, "Messages") },
        { label: "Party Chat", icon: "discord", value: "", show: Cfg.guide.party !== "",
          run: () => launch(Cfg.guide.party, "Party Chat") },
        { label: "Notifications", icon: "preferences-desktop-notification", value: String(Notifications.count),
          run: () => { page = "notifications"; cur = 0; } },
        { label: "Console Settings", icon: "preferences-system", value: "",
          run: () => { page = "settings"; cur = 0; } },
        { label: "Turn Off Console", icon: "system-shutdown", value: "",
          run: () => { ShellState.guideOpen = false; ShellState.powerPrompt(); } }
    ].filter(r => r.show !== false)

    // Entries in order: the rows, the music strip, Select Music, the big button.
    readonly property int stripIndex: rows.length
    readonly property int selectMusicIndex: rows.length + 1
    readonly property int bigIndex: rows.length + 2

    function launch(cmd, title) {
        ShellState.play("select-a");
        ShellState.fromGuide(() => ShellState.launch(cmd, title, 1, true));
    }

    function mediaAction(i) {
        const p = player;
        if (!p) { launch(Cfg.guide.music, "Music"); return; }
        switch (i) {
        case 0: p.togglePlaying(); break;
        case 1: p.previous(); break;
        case 2: p.stop(); break;
        case 3: p.next(); break;
        case 4: if (p.shuffleSupported) p.shuffle = !p.shuffle; break;
        case 5: page = "settings"; cur = 0; break;
        }
        ShellState.play("select-a");
    }

    function mainHandle(btn) {
        switch (btn) {
        case "up": if (cur > 0) { cur--; ShellState.play("select"); } return true;
        case "down": if (cur < bigIndex) { cur++; ShellState.play("select"); } return true;
        case "left": if (cur === stripIndex && mediaCur > 0) { mediaCur--; ShellState.play("select"); } return true;
        case "right": if (cur === stripIndex && mediaCur < 5) { mediaCur++; ShellState.play("select"); } return true;
        case "x": ShellState.guideOpen = false; ShellState.signOut(); return true;
        case "a":
            if (cur < rows.length) { ShellState.play("select-a"); rows[cur].run(); }
            else if (cur === stripIndex) mediaAction(mediaCur);
            else if (cur === selectMusicIndex) launch(Cfg.guide.music, "Music");
            else { ShellState.play("select-a"); ShellState.fromGuide(() => ShellState.dashboard()); }
            return true;
        }
        return true;   // the Guide is modal
    }

    Item {
        id: mainPage
        anchors.fill: parent
        visible: guide.page === ""

        GamerCard {
            id: card
            width: parent.width
            height: Cfg.gamerCardHeight * guide.s
            s: guide.s
        }

        Column {
            id: rowCol
            y: card.height + 10 * guide.s
            width: parent.width
            Repeater {
                model: guide.rows
                delegate: MenuRow {
                    required property var modelData
                    required property int index
                    width: rowCol.width
                    height: 40 * guide.s
                    s: guide.s
                    ink: "#" + Theme.guide.ink
                    rule: "#" + Theme.guide.rule
                    label: modelData.label + (modelData.value !== "" ? "  (" + modelData.value + ")" : "")
                    icon: modelData.icon
                    selected: guide.cur === index
                    onHovered: guide.cur = index
                    onClicked: { guide.cur = index; guide.handle("a"); }
                }
            }
        }

        // The music strip: the console's bevelled transport buttons.
        Row {
            id: strip
            y: rowCol.y + rowCol.height + 12 * guide.s
            spacing: 6 * guide.s
            Repeater {
                model: [guide.player && guide.player.isPlaying ? "⏸" : "▶", "⏮", "■", "⏭", "⇄", "🔊"]
                delegate: Rectangle {
                    id: mb
                    required property string modelData
                    required property int index
                    readonly property bool hot: guide.cur === guide.stripIndex && guide.mediaCur === index
                    width: (strip.parent.width - 5 * strip.spacing) / 6
                    height: 34 * guide.s
                    radius: 5 * guide.s
                    border.width: hot ? 2 : 1.2
                    border.color: hot ? "white" : Qt.rgba(0.35, 0.25, 0, 0.6)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: mb.hot ? "#fffbe6" : "#f9dc6a" }
                        GradientStop { position: 1.0; color: mb.hot ? "#f3d35a" : "#e3b228" }
                    }
                    opacity: guide.player || index === 0 ? 1 : 0.6
                    Text {
                        anchors.centerIn: parent
                        text: (index === 4 && guide.player && guide.player.shuffle ? "⇄•" : mb.modelData)
                        font.pixelSize: 17 * guide.s
                        color: "#4a3505"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { guide.cur = guide.stripIndex; guide.mediaCur = mb.index; guide.mediaAction(mb.index); }
                    }
                }
            }
        }

        // Select Music, showing what is playing.
        Rectangle {
            id: selectMusic
            y: strip.y + strip.height + 6 * guide.s
            width: parent.width
            height: 34 * guide.s
            radius: 5 * guide.s
            readonly property bool hot: guide.cur === guide.selectMusicIndex
            color: hot ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(1, 1, 1, 0.25)
            border.width: 1.2
            border.color: Qt.rgba(0.35, 0.25, 0, 0.6)
            Text {
                x: 10 * guide.s
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 20 * guide.s
                elide: Text.ElideRight
                text: guide.player && guide.player.trackTitle !== ""
                    ? guide.player.trackTitle + (guide.player.trackArtist !== "" ? " — " + guide.player.trackArtist : "")
                    : "Select Music"
                font.family: Cfg.font
                font.pixelSize: 20 * guide.s
                color: selectMusic.hot ? Theme.onWash("#" + Theme.guide.ink) : "#" + Theme.guide.ink
            }
            MouseArea { anchors.fill: parent; onClicked: { guide.cur = guide.selectMusicIndex; guide.handle("a"); } }
        }

        // The big XBOX 360 button: back to the dashboard.
        Rectangle {
            y: selectMusic.y + selectMusic.height + 10 * guide.s
            width: parent.width
            height: Math.max(48 * guide.s, parent.height - y)
            radius: 8 * guide.s
            readonly property bool hot: guide.cur === guide.bigIndex
            border.width: hot ? 3 : 1.5
            border.color: hot ? "#8bd450" : Qt.rgba(0.4, 0.4, 0.4, 0.8)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffff" }
                GradientStop { position: 1.0; color: "#d4d4d4" }
            }
            BladeLogo {
                anchors.fill: parent
                blade: 2
                s: guide.s * 0.8
            }
            MouseArea { anchors.fill: parent; onClicked: { guide.cur = guide.bigIndex; guide.handle("a"); } }
        }
    }

    // ---- submenus ------------------------------------------------------------
    // A list on the left, the highlighted item's details on the right.
    readonly property var listItems: {
        if (page === "apps") return ShellState.apps.map(a => ({
            label: a.title, icon: a.icon, detail: a.windows + (a.windows === 1 ? " window" : " windows"),
            run: () => ShellState.fromGuide(() => Hyprland.dispatch("workspace " + a.id)),
            x: () => ShellState.closeApp(a.id) }));
        if (page === "notifications") return Notifications.list.map(n => ({
            label: n.summary, icon: n.appIcon, detail: (n.appName !== "" ? n.appName + "\n\n" : "") + n.body.replace(/<[^>]*>/g, ""),
            run: () => { ShellState.guideOpen = false; ShellState.showNotification(n); },
            x: () => n.dismiss() }));
        if (page === "settings") return settings.rows;
        return [];
    }

    function listHandle(btn) {
        const n = listItems.length;
        switch (btn) {
        case "up": if (cur > 0) { cur--; ShellState.play("select"); } return true;
        case "down": if (cur < n - 1) { cur++; ShellState.play("select"); } return true;
        case "left": case "right":
            if (page === "settings" && listItems[cur] && listItems[cur].adjust) {
                listItems[cur].adjust(btn === "right" ? 1 : -1);
                ShellState.play("select");
            }
            return true;
        case "a": if (listItems[cur]) { ShellState.play("select-a"); listItems[cur].run(); } return true;
        case "x": if (listItems[cur] && listItems[cur].x) { ShellState.play("select-a"); listItems[cur].x(); } return true;
        }
        return true;
    }

    Item {
        anchors.fill: parent
        visible: guide.page !== ""

        Column {
            id: listCol
            width: parent.width * 0.5
            Repeater {
                model: guide.listItems
                delegate: MenuRow {
                    required property var modelData
                    required property int index
                    width: listCol.width
                    height: 40 * guide.s
                    s: guide.s
                    ink: "#" + Theme.guide.ink
                    rule: "#" + Theme.guide.rule
                    label: modelData.label + (modelData.value ? "    " + modelData.value : "")
                    icon: modelData.icon || ""
                    selected: guide.cur === index
                    onHovered: guide.cur = index
                    onClicked: { guide.cur = index; guide.handle("a"); }
                }
            }
        }
        Text {
            anchors.centerIn: listCol
            visible: guide.listItems.length === 0
            text: guide.page === "apps" ? "Nothing is open." : guide.page === "notifications" ? "No notifications." : ""
            font.family: Cfg.font
            font.pixelSize: 22 * guide.s
            color: "#" + Theme.guide.ink
        }

        Rectangle {
            x: parent.width * 0.53
            width: parent.width - x
            height: parent.height
            radius: 8 * guide.s
            color: Qt.rgba(1, 1, 1, 0.2)
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.6)
            visible: guide.listItems.length > 0
            Text {
                x: 14 * guide.s
                y: 12 * guide.s
                width: parent.width - 28 * guide.s
                wrapMode: Text.WordWrap
                text: guide.listItems[guide.cur] ? guide.listItems[guide.cur].detail || "" : ""
                font.family: Cfg.font
                font.pixelSize: 20 * guide.s
                color: "#" + Theme.guide.ink
            }
        }
    }

    GuideSettings {
        id: settings
        active: guide.open && guide.page === "settings"
    }
}
