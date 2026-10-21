// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Jellyfin.qml
// The Videos library's Jellyfin client: sign-in and the API.
//
// Sign-in is Quick Connect, because a couch has no keyboard: the shell asks
// the server for a six-digit code, shows it, and the user approves it from
// any signed-in Jellyfin (phone app or web: Settings -> Quick Connect). The
// resulting token is kept in Quickshell's state directory and shared with the
// playback helper (pad/xbox360-jellyfin-play.py), which reports progress.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Singleton {
    id: jf

    readonly property string url: Cfg.jellyfinUrl.replace(/\/$/, "")
    readonly property bool configured: url !== ""
    property string token: ""
    property string userId: ""
    property string userName: ""
    property string deviceId: ""
    readonly property bool signedIn: token !== "" && userId !== ""
    readonly property string statePath: store.path

    // Quick Connect: "" idle, "waiting" for approval, "error".
    property string qcState: ""
    property string qcCode: ""
    property string qcSecret: ""
    property string error: ""

    function authHeader() {
        return 'MediaBrowser Client="Xbox 360 Dashboard", Device="' + Cfg.hostname
            + '", DeviceId="' + deviceId + '", Version="1.0"'
            + (token !== "" ? ', Token="' + token + '"' : "");
    }

    // cb(error, data): error is "" on success.
    function request(method, path, body, cb) {
        const x = new XMLHttpRequest();
        x.open(method, url + path);
        x.setRequestHeader("Authorization", authHeader());
        if (body !== null) x.setRequestHeader("Content-Type", "application/json");
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status >= 200 && x.status < 300) {
                let data = null;
                try { data = x.responseText !== "" ? JSON.parse(x.responseText) : null; } catch (e) {}
                cb("", data);
            } else {
                if (x.status === 401 && token !== "") signOut();
                cb(x.status === 0 ? "Can't reach the media server." : "The media server said " + x.status + ".", null);
            }
        };
        x.send(body !== null ? JSON.stringify(body) : null);
    }

    function image(id, height) {
        return url + "/Items/" + id + "/Images/Primary?maxHeight=" + Math.round(height) + "&quality=90";
    }

    // ---- Quick Connect ----------------------------------------------------------
    function startQuickConnect() {
        error = "";
        qcState = "waiting";
        qcCode = "";
        request("POST", "/QuickConnect/Initiate", null, (err, d) => {
            if (err !== "" || !d) {
                qcState = "error";
                error = err !== "" ? err : "Quick Connect is turned off on the server.";
                return;
            }
            qcCode = d.Code;
            qcSecret = d.Secret;
            qcPoll.start();
        });
    }

    Timer {
        id: qcPoll
        interval: 3000
        repeat: true
        onTriggered: jf.request("GET", "/QuickConnect/Connect?Secret=" + jf.qcSecret, null, (err, d) => {
            if (err !== "") { stop(); jf.qcState = "error"; jf.error = "The code expired. Get a new one."; return; }
            if (!d || !d.Authenticated) return;
            stop();
            jf.request("POST", "/Users/AuthenticateWithQuickConnect", { Secret: jf.qcSecret }, (err2, a) => {
                if (err2 !== "" || !a) { jf.qcState = "error"; jf.error = err2; return; }
                jf.token = a.AccessToken;
                jf.userId = a.User.Id;
                jf.userName = a.User.Name;
                jf.qcState = "";
                jf.save();
                ShellState.play("notification");
            });
        })
    }

    function signOut() {
        token = "";
        userId = "";
        userName = "";
        save();
    }

    // ---- persistence ---------------------------------------------------------------
    function save() {
        store.setText(JSON.stringify({ url: url, token: token, userId: userId,
                                       userName: userName, deviceId: deviceId }));
    }

    FileView {
        id: store
        path: Quickshell.statePath("jellyfin.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                // A token belongs to the server it came from.
                if (d.url === jf.url) {
                    jf.token = d.token || "";
                    jf.userId = d.userId || "";
                    jf.userName = d.userName || "";
                }
                jf.deviceId = d.deviceId || "";
            } catch (e) {}
            if (jf.deviceId === "") { jf.deviceId = "xbox360-" + Math.random().toString(16).slice(2, 14); jf.save(); }
        }
        onLoadFailed: { jf.deviceId = "xbox360-" + Math.random().toString(16).slice(2, 14); jf.save(); }
    }
}
