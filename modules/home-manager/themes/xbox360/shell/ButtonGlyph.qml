// ~/nixos-config/modules/home-manager/themes/xbox360/shell/ButtonGlyph.qml
// A controller button as the console draws it in its legends: a glossy
// sphere in the button's physical colour (light at the top, dark at the
// bottom, a blurred highlight) with its letter; the Guide button as the
// silver ring with green light; bumpers and triggers as small grey pills; the
// D-pad as a grey cross.
import QtQuick
import "Config.js" as Cfg

Item {
    id: glyph

    property string btn: "a"     // a b x y guide lb rb lt rt start back ls rs dpad
    property real size: 20
    property bool dim: false     // a slot with nothing to do keeps its shape, faded

    readonly property bool round: ["a", "b", "x", "y", "guide"].indexOf(btn) >= 0
    readonly property bool dpad: btn === "dpad"
    readonly property color base: btn === "guide" ? "#d9d9d9"
                                : round ? "#" + Cfg.buttons[btn] : "#5d5d5d"

    implicitWidth: round || dpad ? size : size * 1.6
    implicitHeight: size
    opacity: dim ? 0.45 : 1

    // The D-pad: two crossed bars in the pills' grey.
    Repeater {
        model: glyph.dpad ? 2 : 0
        delegate: Rectangle {
            required property int index
            anchors.centerIn: parent
            width: index === 0 ? glyph.size : glyph.size * 0.36
            height: index === 0 ? glyph.size * 0.36 : glyph.size
            radius: glyph.size * 0.08
            border.width: 1
            border.color: Qt.darker(glyph.base, 1.6)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(glyph.base, 1.45) }
                GradientStop { position: 1.0; color: Qt.darker(glyph.base, 1.35) }
            }
        }
    }

    Rectangle {
        visible: !glyph.dpad
        anchors.fill: parent
        radius: glyph.round ? width / 2 : height / 2.4
        border.width: 1
        border.color: Qt.darker(glyph.base, glyph.dim ? 1.1 : 1.6)
        gradient: Gradient {
            GradientStop { position: 0.0; color: glyph.dim ? "#c8c8c8" : Qt.lighter(glyph.base, 1.45) }
            GradientStop { position: 0.55; color: glyph.dim ? "#b4b4b4" : glyph.base }
            GradientStop { position: 1.0; color: glyph.dim ? "#9c9c9c" : Qt.darker(glyph.base, 1.35) }
        }

        // The highlight that makes it read as a sphere.
        Rectangle {
            visible: glyph.round
            x: parent.width * 0.2
            y: parent.height * 0.08
            width: parent.width * 0.6
            height: parent.height * 0.36
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.45)
        }

        // The Guide button's green ring of light.
        Rectangle {
            visible: glyph.btn === "guide"
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: width
            radius: width / 2
            color: "transparent"
            border.width: Math.max(2, parent.width * 0.12)
            border.color: "#5fc11f"
        }

        Text {
            visible: glyph.btn !== "guide"
            anchors.centerIn: parent
            text: glyph.btn.toUpperCase()
            font.family: Cfg.font
            font.bold: true
            font.pixelSize: glyph.size * (glyph.round ? 0.62 : 0.5)
            color: glyph.dim ? "#7a7a7a" : (glyph.round ? "#1a1a1a" : "white")
        }
    }
}
