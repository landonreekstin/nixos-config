// ~/nixos-config/modules/home-manager/themes/xbox360/shell/BladeBands.qml
// What sits in the panel's header and footer bands, as on the console:
// the title on the left of the header and the clock on its right; the footer
// is the button legend — Y over X on the left, B over A on the right — saying
// what the buttons do right now. Legend entries can be clicked.
import QtQuick
import Quickshell
import "Config.js" as Cfg
import "Geometry.js" as Geo

Item {
    id: bands

    property string mode: "blades"
    property string title
    property bool forward: true
    property real panelL
    property real panelR
    property real cf: 1
    property var g      // reference frame (Geometry.js), cf = 1

    readonly property real s: g.s
    function leftAt(y) { return (panelL - cf * Geo.curveAt(y, g)) * s; }
    function rightAt(y) { return (panelR + cf * Geo.curveAt(y, g)) * s; }

    readonly property real footerTop: g.H - Cfg.footerHeight

    // What each footer slot says in each mode. A legend entry is
    // { btns: [...], label, action }.
    readonly property var legend: {
        if (mode === "blades") return {
            left: [ ShellState.resumeTitle !== ""
                      ? { btns: ["y"], label: "Resume " + ShellState.resumeTitle, action: () => ShellState.resume() }
                      : { btns: ["y"], label: "" },
                    { btns: ["x"], label: "" } ],
            right: [ { btns: ["b"], label: "" },
                     { btns: ["a"], label: "Select" } ]
        };
        if (mode === "page") return {
            left: [ { btns: ["y"], label: "" }, { btns: ["x"], label: "" } ],
            right: [ { btns: ["b"], label: "Back", action: () => { ShellState.play("back"); ShellState.closePage(); } },
                     { btns: ["a"], label: "Select" } ]
        };
        return {
            left: [ { btns: ["guide", "y"], label: "Xbox Dashboard", action: () => ShellState.dashboard() },
                    { btns: ["guide"], label: "Guide" } ],
            right: [ { btns: ["guide", "lb", "rb"], label: "Switch" },
                     { btns: ["guide", "dpad"], label: "Window" } ]
        };
    }

    component BandText: Text {
        font.family: Cfg.font
        color: "white"
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.28)
    }

    // ---- header: title and clock -------------------------------------------
    // The title lands from the direction of travel: 28 reference px off,
    // fading in over one tempo after a third-of-a-tempo delay, so the chrome
    // is seen moving first.
    Item {
        id: titleBox
        x: bands.leftAt(Cfg.titleCentre) + Cfg.titleInset * bands.s
        y: Cfg.titleCentre * bands.s - titleText.implicitHeight / 2
        width: titleText.implicitWidth
        height: titleText.implicitHeight

        BandText {
            id: titleText
            text: bands.title
            font.pixelSize: Cfg.titleSize * bands.s
        }
        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }

    onTitleChanged: land.restart()
    SequentialAnimation {
        id: land
        PropertyAction { target: titleText; property: "opacity"; value: 0 }
        PropertyAction { target: titleText; property: "x"; value: (bands.forward ? 28 : -28) * bands.s }
        PauseAnimation { duration: Cfg.motionMs / 3 }
        ParallelAnimation {
            NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: Cfg.motionMs }
            NumberAnimation {
                target: titleText; property: "x"; to: 0; duration: Cfg.motionMs
                easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    BandText {
        text: Qt.formatTime(clock.date, "h:mm AP")
        font.pixelSize: Cfg.footerSize * bands.s
        x: bands.rightAt(Cfg.titleCentre) - Cfg.titleInset * bands.s - implicitWidth
        y: Cfg.titleCentre * bands.s - implicitHeight / 2
        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }

    // ---- footer: the button legend -------------------------------------------
    component LegendEntry: MouseArea {
        id: entry
        property var spec
        property bool rightSide: false
        readonly property bool live: spec.label !== ""
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        enabled: live && spec.action !== undefined
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: spec.action()

        Row {
            id: row
            spacing: 6 * bands.s
            layoutDirection: entry.rightSide ? Qt.RightToLeft : Qt.LeftToRight
            Row {
                spacing: 2 * bands.s
                anchors.verticalCenter: parent.verticalCenter
                layoutDirection: Qt.LeftToRight
                Repeater {
                    model: entry.spec.btns.filter(b => b !== "dpad")
                    delegate: ButtonGlyph {
                        required property string modelData
                        btn: modelData
                        size: 20 * bands.s
                        dim: !entry.live
                    }
                }
                Text {
                    visible: entry.spec.btns.indexOf("dpad") >= 0
                    text: "✛"
                    font.pixelSize: 20 * bands.s
                    color: "white"
                }
            }
            BandText {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.spec.label
                font.pixelSize: Cfg.footerSize * bands.s
                font.underline: entry.containsMouse && entry.enabled
            }
        }
    }

    Column {
        x: bands.leftAt(footerTop + 30) + Cfg.titleInset * bands.s
        y: (bands.footerTop + 6) * bands.s
        spacing: 2 * bands.s
        Repeater {
            model: bands.legend.left
            delegate: LegendEntry {
                required property var modelData
                spec: modelData
            }
        }
        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }

    Column {
        x: bands.rightAt(footerTop + 30) - Cfg.titleInset * bands.s - width
        y: (bands.footerTop + 6) * bands.s
        spacing: 2 * bands.s
        Repeater {
            model: bands.legend.right
            delegate: LegendEntry {
                required property var modelData
                spec: modelData
                rightSide: true
                anchors.right: parent ? parent.right : undefined
            }
        }
        Behavior on x {
            NumberAnimation { duration: Cfg.motionMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Cfg.motionBezier }
        }
    }
}
