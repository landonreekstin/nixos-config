// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Keyboard.qml
// The console's on-screen keyboard (Captures/xbox360-examples/keyboard.png): a
// silver panel from the left with the letter grid, the digit block, Cursor /
// Symbols / Caps down the left, Cursor / Accents / Done down the right, and
// Space and Backspace along the bottom; the rest of the screen dims.
//
// Every key is typed straight into the focused window (wtype, the Wayland
// virtual-keyboard protocol). The panel never takes the keyboard focus, so the
// app keeps it and the text lands where the user was typing; the field at the
// top just echoes what has been sent.
//
// Controller: D-pad/stick moves, A presses, Y space, X backspace, LB/RB move
// the app's text cursor, LT symbols, LS caps, Start or B closes.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Config.js" as Cfg

PanelWindow {
    id: win

    property real s: Math.min(screen.width / 1280, screen.height / 720)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ShellState.keyboardOpen || fade.running
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "xbox360-keyboard"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ---- input -------------------------------------------------------------
    QtObject {
        id: handler
        property bool active: ShellState.keyboardOpen
        property int priority: 20
        function handle(btn) { return win.handle(btn); }
    }
    Component.onCompleted: ShellState.pushHandler(handler)
    Component.onDestruction: ShellState.removeHandler(handler)

    property bool caps: false
    property bool symbols: false
    property string typed: ""
    property int current: 6       // index into `keys`: 6 is "a"

    readonly property var letters: "abcdefghijklmnopqrstuvwxyz-@".split("")
    readonly property var symbolSet: "!?#$%&*()[]{}<>/\\|=+;:'\",.~".split("")
    readonly property var digits: "123456789_0.".split("")

    // The keys as cells on a grid: r/c with spans. 13 columns: 0-1 left side
    // buttons, 2-8 letters, 9-11 digits, 12-13 right side buttons.
    readonly property var keys: {
        const k = [];
        const set = symbols ? symbolSet : letters;
        // Left side.
        k.push({ r: 0, c: 0, rs: 1, cs: 2, label: "Cursor", btn: "lb", act: "left" });
        k.push({ r: 1, c: 0, rs: 1, cs: 2, label: "Symbols", btn: "lt", act: "symbols" });
        k.push({ r: 2, c: 0, rs: 2, cs: 2, label: "Caps", btn: "ls", act: "caps" });
        // Right side.
        k.push({ r: 0, c: 12, rs: 1, cs: 2, label: "Cursor", btn: "rb", act: "right" });
        k.push({ r: 1, c: 12, rs: 1, cs: 2, label: "Accents", btn: "rt", act: "", dim: true });
        k.push({ r: 2, c: 12, rs: 3, cs: 2, label: "Done", btn: "start", act: "done" });
        // Letters (index 6 onward... "a" is index 6+0 after the side keys).
        for (let i = 0; i < 28; i++) {
            const ch = set[i] || "";
            k.push({ r: Math.floor(i / 7), c: 2 + i % 7, rs: 1, cs: 1,
                     label: caps && !symbols ? ch.toUpperCase() : ch, act: "char" });
        }
        for (let i = 0; i < 12; i++)
            k.push({ r: Math.floor(i / 3), c: 9 + i % 3, rs: 1, cs: 1, label: digits[i], act: "char" });
        // Bottom row.
        k.push({ r: 4, c: 2, rs: 1, cs: 4, label: "Space", btn: "y", act: "space" });
        k.push({ r: 4, c: 6, rs: 1, cs: 6, label: "Backspace", btn: "x", act: "backspace" });
        return k;
    }

    function type(args) { Quickshell.execDetached([Cfg.wtype].concat(args)); }

    function press(key) {
        switch (key.act) {
        case "char":
            if (key.label === "") return;
            type(["--", key.label]);
            typed += key.label;
            break;
        case "space": type(["-k", "space"]); typed += " "; break;
        case "backspace": type(["-k", "BackSpace"]); typed = typed.slice(0, -1); break;
        case "left": type(["-k", "Left"]); break;
        case "right": type(["-k", "Right"]); break;
        case "symbols": symbols = !symbols; break;
        case "caps": caps = !caps; break;
        case "done": close(); return;
        default: return;
        }
        ShellState.play("select-a");
    }

    function close() {
        ShellState.play("back");
        ShellState.keyboardOpen = false;
    }

    // Move to the nearest key in a direction, measuring from cell centres.
    function move(dx, dy) {
        const a = keys[current];
        const ax = a.c + a.cs / 2, ay = a.r + a.rs / 2;
        let best = -1, bestD = 1e9;
        for (let i = 0; i < keys.length; i++) {
            if (i === current) continue;
            const b = keys[i];
            const bx = b.c + b.cs / 2, by = b.r + b.rs / 2;
            const along = (bx - ax) * dx + (by - ay) * dy;
            if (along <= 0.01) continue;
            const across = Math.abs((bx - ax) * dy) + Math.abs((by - ay) * dx);
            const d = along + across * 2.5;
            if (d < bestD) { bestD = d; best = i; }
        }
        if (best >= 0) { current = best; ShellState.play("select"); }
    }

    function handle(btn) {
        switch (btn) {
        case "up": move(0, -1); return true;
        case "down": move(0, 1); return true;
        case "left": move(-1, 0); return true;
        case "right": move(1, 0); return true;
        case "a": press(keys[current]); return true;
        case "b": case "start": close(); return true;
        case "y": press({ act: "space" }); return true;
        case "x": press({ act: "backspace" }); return true;
        case "lb": press({ act: "left" }); return true;
        case "rb": press({ act: "right" }); return true;
        case "lt": press({ act: "symbols" }); return true;
        case "ls": press({ act: "caps" }); return true;
        }
        return true;   // the keyboard is modal: swallow everything else
    }

    onVisibleChanged: if (visible) { typed = ""; caps = false; symbols = false; current = 6; }

    // ---- look ------------------------------------------------------------------
    Item {
        id: stage
        anchors.fill: parent
        opacity: ShellState.keyboardOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Cfg.motionMs } }

        // The rest of the screen dims, as on the console.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            MouseArea { anchors.fill: parent; onClicked: win.close() }
        }

        Rectangle {
            id: panel
            x: -radius
            y: 10 * win.s
            width: 880 * win.s + radius
            height: parent.height - 20 * win.s
            radius: 26 * win.s
            border.width: 2
            border.color: "#f2f2f2"
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#b8bbbe" }
                GradientStop { position: 0.13; color: "#a9adb1" }
                GradientStop { position: 0.131; color: "#d6d8da" }
                GradientStop { position: 0.6; color: "#c4c7ca" }
                GradientStop { position: 0.86; color: "#bfc2c5" }
                GradientStop { position: 0.861; color: "#a3a7ab" }
                GradientStop { position: 1.0; color: "#8f9397" }
            }
            MouseArea { anchors.fill: parent }   // clicks on the panel don't close it

            readonly property real contentLeft: radius + 70 * win.s

            SystemClock { id: clock; precision: SystemClock.Minutes }
            Text {
                x: panel.contentLeft
                y: 40 * win.s
                text: "Keyboard"
                font.family: Cfg.font
                font.pixelSize: Cfg.titleSize * win.s
                color: "white"
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.3)
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 50 * win.s
                y: 46 * win.s
                text: Qt.formatTime(clock.date, "h:mm AP")
                font.family: Cfg.font
                font.pixelSize: Cfg.footerSize * win.s
                color: "white"
            }
            Text {
                x: panel.contentLeft
                y: 112 * win.s
                text: "Type with the controller. Keys go to the window you were using."
                font.family: Cfg.font
                font.pixelSize: 20 * win.s
                color: "#1d1d1d"
            }

            // The echo field.
            Rectangle {
                x: panel.contentLeft
                y: 160 * win.s
                width: panel.width - x - 50 * win.s
                height: 40 * win.s
                radius: 3 * win.s
                color: "#bfc2c5"
                border.width: 1.5
                border.color: "#8f9397"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10 * win.s
                    width: parent.width - 20 * win.s
                    elide: Text.ElideLeft
                    text: win.typed + "▏"
                    font.family: Cfg.font
                    font.pixelSize: 22 * win.s
                    color: "#1d1d1d"
                }
            }

            // The keys.
            Item {
                id: grid
                x: panel.contentLeft
                y: 225 * win.s
                width: panel.width - x - 50 * win.s
                height: 5 * cell + 4 * gap
                readonly property real gap: 6 * win.s
                readonly property real cell: 42 * win.s
                readonly property real colW: (width - 13 * gap) / 14

                Repeater {
                    model: win.keys
                    delegate: Rectangle {
                        id: key
                        required property var modelData
                        required property int index
                        readonly property bool side: modelData.btn !== undefined && modelData.act !== "space" && modelData.act !== "backspace"
                        readonly property bool hot: index === win.current
                        readonly property bool on: (modelData.act === "caps" && win.caps) || (modelData.act === "symbols" && win.symbols)
                        x: modelData.c * (grid.colW + grid.gap) + (modelData.c >= 12 ? grid.gap * 2 : 0) - (modelData.c < 2 ? 0 : 0)
                        y: modelData.r * (grid.cell + grid.gap)
                        width: modelData.cs * grid.colW + (modelData.cs - 1) * grid.gap
                        height: modelData.rs * grid.cell + (modelData.rs - 1) * grid.gap
                        radius: 5 * win.s
                        opacity: modelData.dim || modelData.label === "" ? 0.45 : 1
                        border.width: hot ? 2 : 1.5
                        border.color: hot ? "#5fae34" : "#7d8185"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: key.hot ? "#e9f7dc" : key.on ? "#dfe6d6" : "#f4f5f6" }
                            GradientStop { position: 1.0; color: key.hot ? "#b5e08e" : key.on ? "#b9c6ad" : "#c9ccce" }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6 * win.s
                            ButtonGlyph {
                                visible: key.modelData.btn !== undefined
                                anchors.verticalCenter: parent.verticalCenter
                                btn: key.modelData.btn || "a"
                                size: 20 * win.s
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: key.modelData.label
                                font.family: Cfg.font
                                font.pixelSize: (key.side || key.modelData.act === "space" || key.modelData.act === "backspace" ? 19 : 22) * win.s
                                color: "#2a2a2a"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onPositionChanged: mouse => {
                                if (ShellState.pointerMoved(key, mouse.x, mouse.y)) win.current = key.index;
                            }
                            onClicked: { win.current = key.index; win.press(key.modelData); }
                        }
                    }
                }
            }

            // Legend, as in the capture: Y Space / X Backspace, B Cancel / A Select.
            Column {
                x: panel.contentLeft
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18 * win.s
                spacing: 2 * win.s
                Repeater {
                    model: [["y", "Space"], ["x", "Backspace"]]
                    delegate: Row {
                        required property var modelData
                        spacing: 6 * win.s
                        ButtonGlyph { btn: parent.modelData[0]; size: 20 * win.s; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: parent.modelData[1]; font.family: Cfg.font; font.pixelSize: Cfg.footerSize * win.s; color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.3) }
                    }
                }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 50 * win.s
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18 * win.s
                spacing: 2 * win.s
                Repeater {
                    model: [["b", "Cancel"], ["a", "Select"]]
                    delegate: Row {
                        required property var modelData
                        anchors.right: parent ? parent.right : undefined
                        spacing: 6 * win.s
                        Text { text: parent.modelData[1]; font.family: Cfg.font; font.pixelSize: Cfg.footerSize * win.s; color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.3) }
                        ButtonGlyph { btn: parent.modelData[0]; size: 20 * win.s; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
