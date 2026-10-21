// ~/nixos-config/modules/home-manager/themes/xbox360/shell/NotificationBlade.qml
// The console's notification blade (notification.png): a blade from the
// RIGHT, the rest dimmed, with an icon and title in the header, the message
// in the card, and its choices as rows underneath — "Yes, update now" / "No,
// don't update" there; here a notification's actions, or a system question
// like Turn Off Console. B backs out.
//
// What it shows is ShellState.message: { title, icon, body, actions: [{ label,
// run }] }.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Config.js" as Cfg

SidePanel {
    id: blade

    readonly property var msg: ShellState.message
    property var shown: null
    onMsgChanged: if (msg !== null) { shown = msg; cur = 0; }

    open: msg !== null
    fromLeft: false
    widthRef: 600
    title: shown ? shown.title : ""
    bandLabel: ""
    legend: ({ left: [{ btn: "y", label: "" }, { btn: "x", label: "" }],
               right: [{ btn: "b", label: "Back" }, { btn: "a", label: "Select" }] })
    onDismissed: ShellState.closeMessage()

    property int cur: 0
    readonly property var actions: shown ? shown.actions : []

    QtObject {
        id: handler
        property bool active: ShellState.message !== null
        property int priority: 15
        function handle(btn) { return blade.handle(btn); }
    }
    Component.onCompleted: ShellState.pushHandler(handler)
    Component.onDestruction: ShellState.removeHandler(handler)

    function handle(btn) {
        switch (btn) {
        case "up": if (cur > 0) { cur--; ShellState.play("select"); } return true;
        case "down": if (cur < actions.length - 1) { cur++; ShellState.play("select"); } return true;
        case "a":
            if (actions[cur]) {
                const a = actions[cur];
                ShellState.play("select-a");
                ShellState.closeMessage();
                a.run();
            }
            return true;
        case "b": ShellState.play("back"); ShellState.closeMessage(); return true;
        }
        return true;
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const map = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Return]: "a",
                          [Qt.Key_Enter]: "a", [Qt.Key_Escape]: "b", [Qt.Key_Backspace]: "b" };
            const btn = map[event.key];
            if (btn !== undefined && blade.handle(btn)) event.accepted = true;
        }

        Image {
            id: icon
            visible: blade.shown && blade.shown.icon !== ""
            width: 44 * blade.s
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: blade.shown && blade.shown.icon !== ""
                ? (blade.shown.icon.indexOf("/") >= 0 || blade.shown.icon.indexOf(":") >= 0
                   ? blade.shown.icon : Quickshell.iconPath(blade.shown.icon, true))
                : ""
        }

        Text {
            id: body
            x: 0
            y: icon.visible ? icon.height + 12 * blade.s : 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: blade.shown ? blade.shown.body.replace(/<[^>]*>/g, "") : ""
            font.family: Cfg.font
            font.pixelSize: 22 * blade.s
            lineHeight: 1.1
            color: "#" + Theme.guide.ink
        }

        Column {
            id: rows
            width: parent.width
            anchors.bottom: parent.bottom
            Repeater {
                model: blade.actions
                delegate: MenuRow {
                    required property var modelData
                    required property int index
                    width: rows.width
                    height: 40 * blade.s
                    s: blade.s
                    ink: "#" + Theme.guide.ink
                    rule: "#" + Theme.guide.rule
                    label: modelData.label
                    icon: ""
                    selected: blade.cur === index
                    onHovered: blade.cur = index
                    onClicked: { blade.cur = index; blade.handle("a"); }
                }
            }
        }
    }
}
