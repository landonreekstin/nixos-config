// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeMenu.qml
// One blade's menu, laid out like the console's (Captures/xbox360-examples,
// dashboard-*-blade.png): the gamer card at the top left, the menu rows below
// it, the blade's logo top right and the highlighted row's description beside
// the rows, and a wide pill along the bottom — the console's "Open Tray",
// here "Resume" for the last app.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Config.js" as Cfg

Item {
    id: menu

    property var dash           // the display's Dash: highlighted rows, last app
    property int blade: 0
    property real s: 1

    readonly property var spec: Theme.blades[blade]
    readonly property var rows: Cfg.menus[Math.min(blade, Cfg.menus.length - 1)]
    readonly property int current: Math.min(dash.rows[blade], Math.max(0, rows.length - 1))
    readonly property color ink: "#" + spec.ink

    readonly property real leftW: width * 0.47
    readonly property real rowH: Cfg.rowHeight * s
    readonly property real rowsTop: (Cfg.gamerCardHeight + 22) * s

    function select(i) {
        if (i < 0 || i >= rows.length || i === current) return;
        dash.setRow(blade, i);
        ShellState.play("select");
    }

    // A turned dashboard stepping onto the blade above or below: land on the
    // row next to where you came from.
    function landOn(where) {
        const n = Cfg.menus[Math.min(dash.blade, Cfg.menus.length - 1)].length;
        dash.setRow(dash.blade, where === "last" ? Math.max(0, n - 1) : 0);
    }

    function activate(i) {
        const r = rows[i];
        if (!r) return;
        const a = r.action;
        ShellState.play("select-a");
        if (a.type === "launch") ShellState.launch(a.cmd, a.title, blade, a.single === true);
        else if (a.type === "page") ShellState.openPage(a.page, a.title, blade);
        else if (a.type === "ipc") ShellState.input(a.btn);
        else if (a.type === "setting") ShellState.changeSetting(a.setting, 1);
        else if (a.type === "guide") ShellState.openGuideAt(a.page);
        else if (a.type === "lastPlayed" && Games.list.length > 0) Games.play(Games.list[0]);
    }

    function handle(btn) {
        switch (btn) {
        case "up": select(current - 1); return true;
        case "down": select(current + 1); return true;
        case "lt": select(0); return true;
        case "rt": select(rows.length - 1); return true;
        case "a": activate(current); return true;
        case "left": case "right": {
            // A switch row changes with left/right too; anything else lets the
            // dashboard page between blades.
            const r = rows[current];
            if (!r || r.action.type !== "setting") return false;
            ShellState.changeSetting(r.action.setting, btn === "right" ? 1 : -1);
            ShellState.play("select");
            return true;
        }
        case "y": ShellState.resume(); return true;
        }
        return false;
    }

    // ---- left column: gamer card and rows ---------------------------------
    GamerCard {
        x: 0
        y: 0
        width: menu.leftW
        height: Cfg.gamerCardHeight * menu.s
        s: menu.s
    }

    Column {
        id: rowsCol
        x: 0
        y: menu.rowsTop
        width: menu.leftW

        Repeater {
            model: menu.rows
            delegate: MenuRow {
                required property var modelData
                required property int index
                width: rowsCol.width
                height: menu.rowH
                s: menu.s
                ink: menu.ink
                rule: "#" + menu.spec.rule
                label: modelData.label + (modelData.action.type === "setting"
                    ? ":  " + ShellState.settingText(modelData.action.setting) : "")
                icon: modelData.icon
                selected: index === menu.current
                onHovered: menu.select(index)
                onClicked: menu.activate(index)
            }
        }
    }

    // ---- right column: logo and description ---------------------------------
    BladeLogo {
        x: menu.leftW + 30 * menu.s
        y: 4 * menu.s
        width: menu.width - x
        height: Cfg.gamerCardHeight * menu.s
        blade: menu.blade
        s: menu.s
    }

    Text {
        x: menu.leftW + 30 * menu.s
        y: menu.rowsTop + 6 * menu.s
        width: menu.width - x
        text: {
            const r = menu.rows[menu.current];
            if (!r) return "";
            // Last Played names the game it will start.
            if (r.action.type === "lastPlayed")
                return Games.list.length > 0 ? Games.list[0].name + ".\n\n" + r.desc : "No games played yet.";
            return r.desc;
        }
        wrapMode: Text.WordWrap
        font.family: Cfg.font
        font.pixelSize: Cfg.descSize * menu.s
        lineHeight: 1.1
        color: menu.ink
    }

    // ---- bottom pill: Resume ----------------------------------------------------
    Rectangle {
        id: pill
        readonly property bool live: menu.dash.resumeTitle !== ""
        x: 0
        width: parent.width
        height: 40 * menu.s
        anchors.bottom: parent.bottom
        radius: height / 2
        color: Qt.rgba(1, 1, 1, pillArea.containsMouse && live ? 0.22 : 0.12)
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.45)

        Rectangle {
            width: parent.height * 1.3
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: -parent.height * 0.15
            color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.45)
            Text {
                anchors.centerIn: parent
                text: "▶"
                font.pixelSize: 14 * menu.s
                color: Qt.rgba(0, 0, 0, 0.35)
            }
        }
        Text {
            x: parent.height * 1.4
            anchors.verticalCenter: parent.verticalCenter
            text: pill.live ? "Resume " + menu.dash.resumeTitle : "Nothing to resume"
            opacity: pill.live ? 1 : 0.5
            font.family: Cfg.font
            font.pixelSize: Cfg.rowSize * menu.s
            color: menu.ink
        }
        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pill.live ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: ShellState.resume()
        }
    }
}
