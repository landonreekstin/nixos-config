// ~/nixos-config/modules/home-manager/themes/xbox360/shell/GamerCard.qml
// The gamer card at the top of every blade: the gamertag on a gold strip,
// then the gamerpic beside Rep stars, Gamerscore and Zone, on a translucent
// light card — the console's own layout (dashboard-games-blade.png).
import QtQuick
import Quickshell
import "Config.js" as Cfg

Rectangle {
    id: card

    property real s: 1

    radius: 8 * s
    // Frosted white by day; at night a smoked panel with light text.
    color: Theme.night ? Qt.rgba(0, 0, 0, 0.32) : Qt.rgba(1, 1, 1, 0.38)
    border.width: 1.5
    border.color: Theme.night ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.7)
    clip: true

    // The gamertag strip.
    Rectangle {
        id: strip
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 30 * card.s
        radius: card.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#f3e3a0" }
            GradientStop { position: 1.0; color: "#d7b84a" }
        }
        Rectangle {   // square the strip's bottom corners
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.radius
            color: "#d7b84a"
        }
        Text {
            x: 10 * card.s
            anchors.verticalCenter: parent.verticalCenter
            text: Cfg.gamertag
            font.family: Cfg.font
            font.pixelSize: 21 * card.s
            color: "#2a1f05"
        }
    }

    // The gamerpic: the user's own picture if there is one, else a tile with
    // their initial.
    Rectangle {
        id: pic
        x: 10 * card.s
        y: strip.height + 8 * card.s
        width: parent.height - y - 10 * card.s
        height: width
        radius: 4 * card.s
        color: "#3a3a3a"
        border.width: 2
        border.color: Qt.rgba(1, 1, 1, 0.8)
        clip: true
        Image {
            id: face
            anchors.fill: parent
            anchors.margins: 2
            source: Cfg.gamerpic
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !face.visible
            text: Cfg.gamertag.charAt(0).toUpperCase()
            font.family: Cfg.font
            font.pixelSize: parent.height * 0.6
            color: "white"
        }
    }

    Column {
        x: pic.x + pic.width + 12 * card.s
        y: pic.y - 2 * card.s
        width: parent.width - x - 12 * card.s
        spacing: 1 * card.s

        component StatRow: Item {
            property string label
            property string value
            width: parent.width
            height: 26 * card.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.label
                font.family: Cfg.font
                font.pixelSize: 19 * card.s
                color: Theme.night ? "#e4e6e9" : "#1d1d1d"
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.value
                font.family: Cfg.font
                font.pixelSize: 19 * card.s
                color: Theme.night ? "#e4e6e9" : "#1d1d1d"
            }
        }

        StatRow { label: "Rep"; value: "★★★★★" }
        StatRow { label: "Gamerscore"; value: String(ShellState.gamerscore) }
        StatRow { label: "Zone"; value: Cfg.zone }
    }
}
