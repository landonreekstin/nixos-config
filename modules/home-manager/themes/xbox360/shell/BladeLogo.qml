// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeLogo.qml
// The art at the top right of a blade: a silver orb beside a wordmark,
// "XBOX LIVE" on the Xbox LIVE blade and "XBOX 360" elsewhere. Drawn, not an
// image, so it takes the blade's light like the rest of the panel.
import QtQuick
import "Config.js" as Cfg

Item {
    id: logo

    property int blade: 0
    property real s: 1
    readonly property bool live: blade === 1

    Row {
        anchors.centerIn: parent
        spacing: 10 * logo.s

        // The orb: a silver sphere with a dark rim and a green core glow.
        Rectangle {
            width: 62 * logo.s
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            border.width: 2
            border.color: Qt.rgba(0.2, 0.2, 0.2, 0.55)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#fbfbfb" }
                GradientStop { position: 0.5; color: "#c9c9c9" }
                GradientStop { position: 1.0; color: "#8d8d8d" }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.62
                height: width
                radius: width / 2
                color: "transparent"
                border.width: parent.width * 0.09
                border.color: "#6fc23c"
                opacity: 0.85
            }
            Rectangle {
                x: parent.width * 0.22
                y: parent.height * 0.08
                width: parent.width * 0.56
                height: parent.height * 0.3
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.6)
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * logo.s
            Text {
                text: "XBOX"
                font.family: Cfg.font
                font.pixelSize: 38 * logo.s
                font.letterSpacing: -1
                color: logo.live ? "#5a9c2a" : "#d9dcd6"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
            Text {
                text: logo.live ? "LIVE" : "360"
                font.family: Cfg.font
                font.pixelSize: 38 * logo.s
                color: logo.live ? "#e0701c" : "#cfd8c4"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
        }
    }
}
