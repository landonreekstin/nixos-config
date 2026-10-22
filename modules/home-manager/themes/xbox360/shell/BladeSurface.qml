// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeSurface.qml
// The blade's painted surface (blade.frag): gradient, sheen, ripples, gloss.
import QtQuick

ShaderEffect {
    id: surface

    // Four gradient stops (0/30/62/100 %) of whatever blade is showing.
    property color c0
    property color c1
    property color c2
    property color c3
    // Panel edges in reference units; masked = 0 paints the whole surface.
    property real panelL: 0
    property real panelR: 1280
    property real masked: 1
    // Freeze the ripples (e.g. behind a fullscreen game) to cost nothing.
    property bool animating: true

    property size res: Qt.size(width, height)
    property real time: 0

    fragmentShader: Qt.resolvedUrl("blade.frag.qsb")

    // The ripples loop every 9 s; 18 keeps both half-period rings continuous.
    NumberAnimation on time {
        from: 0
        to: 18
        duration: 18000
        loops: Animation.Infinite
        running: surface.animating && surface.visible
    }
}
