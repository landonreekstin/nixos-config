// ~/nixos-config/modules/home-manager/themes/xbox360/shell/LockScreen.qml
// The session lock, as the console's profile sign-in: a full-screen silver
// frame titled "Sign In" with the gamer card, and the account password to get
// back in (checked by PAM through the same `swaylock` service the default
// session's locker uses). Reached from the Guide (X, Sign Out), SUPER+Escape,
// and swayidle (services/swayidle.nix routes its lock here in this session).
//
// It is a real ext-session-lock: if the shell dies while locked, the
// compositor keeps the screen locked rather than revealing it.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "Config.js" as Cfg
import "Geometry.js" as Geo

Scope {
    id: root

    property string message: ""
    property bool failed: false
    property string pending: ""

    function submit(pw) {
        if (pw === "" || pam.active) return;
        pending = pw;
        message = "Signing in…";
        failed = false;
        pam.start();
    }

    PamContext {
        id: pam
        config: "swaylock"
        user: Cfg.gamertag
        onResponseRequiredChanged: if (responseRequired && root.pending !== "") {
            respond(root.pending);
            root.pending = "";
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.message = "";
                ShellState.play("select-a");
                ShellState.locked = false;
            } else {
                root.failed = true;
                root.message = "That password is not right. Try again.";
                ShellState.play("back");
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: ShellState.locked

        WlSessionLockSurface {
            id: surface
            color: "black"

            readonly property var g: Geo.frameFor(width, height)
            readonly property bool primary: !screen || ShellState.primaryName === "" || screen.name === ShellState.primaryName

            BladeSurface {
                anchors.fill: parent
                c0: "#" + Theme.blades[5].stops[0]
                c1: "#" + Theme.blades[5].stops[1]
                c2: "#" + Theme.blades[5].stops[2]
                c3: "#" + Theme.blades[5].stops[3]
                panelL: Cfg.frameMargin
                panelR: surface.g.W - Cfg.frameMargin
                curveAmt: 0
                masked: surface.primary ? 1 : 0
                refSize: Qt.size(surface.g.W, surface.g.H)
            }

            Item {
                id: signin
                anchors.fill: parent
                visible: surface.primary
                readonly property real s: surface.g.s

                SystemClock { id: clock; precision: SystemClock.Minutes }
                Text {
                    x: (Cfg.frameMargin + Cfg.titleInset) * signin.s
                    y: Cfg.titleCentre * signin.s - height / 2
                    text: "Sign In"
                    font.family: Cfg.font
                    font.pixelSize: Cfg.titleSize * signin.s
                    color: "white"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.3)
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: (Cfg.frameMargin + Cfg.titleInset) * signin.s
                    y: Cfg.titleCentre * signin.s - height / 2
                    text: Qt.formatTime(clock.date, "h:mm AP")
                    font.family: Cfg.font
                    font.pixelSize: Cfg.footerSize * signin.s
                    color: "white"
                }

                Column {
                    anchors.centerIn: parent
                    width: 460 * signin.s
                    spacing: 18 * signin.s

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "This console is locked. Enter your password to sign back in."
                        wrapMode: Text.WordWrap
                        font.family: Cfg.font
                        font.pixelSize: 22 * signin.s
                        color: "#1c2128"
                    }
                    GamerCard {
                        width: parent.width
                        height: Cfg.gamerCardHeight * signin.s
                        s: signin.s
                    }
                    Rectangle {
                        width: parent.width
                        height: 44 * signin.s
                        radius: 4 * signin.s
                        color: "#f4f5f6"
                        border.width: 2
                        border.color: root.failed ? "#fa3a2f" : "#5fae34"
                        TextInput {
                            id: pw
                            anchors.fill: parent
                            anchors.margins: 10 * signin.s
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            font.pixelSize: 22 * signin.s
                            color: "#1d1d1d"
                            focus: surface.primary
                            enabled: !pam.active
                            onAccepted: { root.submit(text); text = ""; }
                        }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.message
                        wrapMode: Text.WordWrap
                        font.family: Cfg.font
                        font.pixelSize: 20 * signin.s
                        color: root.failed ? "#a4140c" : "#1c2128"
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: (Cfg.frameMargin + Cfg.titleInset) * signin.s
                    y: (surface.g.H - Cfg.footerHeight / 2) * signin.s - height / 2
                    spacing: 6 * signin.s
                    Text {
                        text: "Sign In"
                        font.family: Cfg.font
                        font.pixelSize: Cfg.footerSize * signin.s
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ButtonGlyph { btn: "a"; size: 20 * signin.s }
                }
            }
        }
    }
}
