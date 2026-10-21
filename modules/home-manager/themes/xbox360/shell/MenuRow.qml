// ~/nixos-config/modules/home-manager/themes/xbox360/shell/MenuRow.qml
// One menu row as on the console: an icon, the label in the blade's dark ink,
// a thin rule underneath in the blade's rule colour, and — when it is the
// highlighted row — a white wash brightest at the left that fades out to the
// right, with a soft bevel.
import QtQuick
import Quickshell
import "Config.js" as Cfg

MouseArea {
    id: row

    property real s: 1
    property color ink: "black"
    property color rule: "gray"
    property string label
    property string icon
    property bool selected: false
    property bool enabled_: true

    signal hovered()

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    // Only a pointer that moved on screen selects (ShellState.pointerMoved).
    onPositionChanged: mouse => { if (ShellState.pointerMoved(row, mouse.x, mouse.y)) hovered(); }

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 2 * row.s
        radius: 4 * row.s
        visible: row.selected
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.92) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.75) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05) }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: Qt.rgba(1, 1, 1, 0.9)
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 2 * row.s
        color: row.rule
        opacity: 0.85
    }

    Image {
        id: iconImg
        x: 8 * row.s
        anchors.verticalCenter: parent.verticalCenter
        width: 30 * row.s
        height: width
        sourceSize: Qt.size(width * 2, height * 2)
        // The row's own icon if the theme has it, else a generic one.
        source: {
            const own = row.icon !== "" ? Quickshell.iconPath(row.icon, true) : "";
            return own !== "" ? own : Quickshell.iconPath("application-x-executable", true);
        }
        smooth: true
    }

    Text {
        x: iconImg.x + iconImg.width + 14 * row.s
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 8 * row.s
        elide: Text.ElideRight
        text: row.label
        font.family: Cfg.font
        font.pixelSize: Cfg.rowSize * row.s
        color: row.ink
    }
}
