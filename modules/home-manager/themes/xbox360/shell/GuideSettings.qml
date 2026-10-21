// ~/nixos-config/modules/home-manager/themes/xbox360/shell/GuideSettings.qml
// The Guide's Console Settings list: where century-series' waybar widgets live
// in this session. Each row is one of the SAME widget scripts waybar runs
// (read from the merged waybar config by session.nix, Config.widgets), shown
// as label + value, with the widget's click on A and its right-click on X.
// Volume is native, adjusted with left/right.
//
// Values come from one generated script (Config.statusCmd) returning a JSON
// object keyed by widget id, polled every 3 s while the list is open.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Cfg

Item {
    id: settings

    property bool active: false
    property var status: ({})

    // Waybar texts carry Nerd Font glyphs (private-use code points) that the
    // Convection font cannot draw, and some carry Pango markup.
    // U+E000-U+F8FF and the supplementary private-use planes (surrogate pairs
    // DB80-DBFF), built from code points so no invisible glyphs sit in the source.
    readonly property var privateUse: new RegExp("[" + String.fromCharCode(0xE000) + "-" + String.fromCharCode(0xF8FF)
        + "]|[" + String.fromCharCode(0xDB80) + "-" + String.fromCharCode(0xDBFF) + "][" + String.fromCharCode(0xDC00)
        + "-" + String.fromCharCode(0xDFFF) + "]", "g")
    function clean(s) {
        return (s || "").replace(/<[^>]*>/g, "")
            .replace(privateUse, "").trim();
    }
    // A widget whose text is only a picture (the Claude radar's grid of dots)
    // is shown by its state class instead: "rwr-waiting" -> "Waiting".
    function valueOf(v) {
        const t = clean(v.text);
        if (/[A-Za-z0-9]/.test(t) || !v["class"]) return t.replace(/\s+/g, " ");
        const c = String(v["class"]).replace(/^[a-z]+-/, "");
        return c.charAt(0).toUpperCase() + c.slice(1);
    }
    function run(cmd) { if (cmd) Quickshell.execDetached(["sh", "-c", cmd]); }

    readonly property var rows: {
        const st = status;
        const out = [];
        const vol = st.volume;
        out.push({
            label: "Volume", icon: "audio-volume-high",
            value: vol !== undefined ? Math.round(vol * 100) + "%" : "",
            detail: "Left and right change the volume of the current output.",
            adjust: dir => { run(Cfg.volumeCmd + " " + (dir > 0 ? "5%+" : "5%-")); poll.restartSoon(); },
            run: () => {}
        });
        for (const w of Cfg.widgets) {
            const v = st[w.id] || {};
            out.push({
                label: w.label, icon: w.icon,
                value: settings.valueOf(v),
                detail: settings.clean(v.tooltip) + (w.right ? "\n\nX: " + w.rightLabel : ""),
                run: () => { settings.run(w.click); poll.restartSoon(); },
                x: w.right ? () => { settings.run(w.right); poll.restartSoon(); } : undefined
            });
        }
        if (st.network !== undefined) out.push({
            label: "Network", icon: "network-wired", value: st.network,
            detail: "The active connection. A opens the connection editor.",
            run: () => run(Cfg.networkEditor)
        });
        return out;
    }

    Process {
        id: proc
        command: [Cfg.statusCmd]
        stdout: StdioCollector {
            onStreamFinished: {
                try { settings.status = JSON.parse(text); } catch (e) {}
            }
        }
    }
    Timer {
        id: poll
        interval: 3000
        running: settings.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
        function restartSoon() { soon.restart(); }
    }
    Timer { id: soon; interval: 400; onTriggered: if (!proc.running) proc.running = true }
}
