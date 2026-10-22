// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Dash.qml
// One display's dashboard: which blade is open, the highlighted row on each,
// a page opened over it, and the app last used on that display (what its
// "Resume" goes back to). ShellState keeps one per monitor name
// (ShellState.dashFor), so a display turned off and on again finds its
// dashboard where it left it.
pragma ComponentBehavior: Bound

import QtQuick
import "Config.js" as Cfg

QtObject {
    id: dash

    property string monitor: ""
    property int blade: Cfg.startBlade
    property var rows: [0, 0, 0, 0, 0]
    property string page: ""
    property string pageTitle: ""
    property int pageBlade: Cfg.startBlade
    property int lastApp: -1

    function setRow(b, i) {
        const r = rows.slice();
        r[b] = i;
        rows = r;
    }
    function openPage(id, title, bladeIndex) {
        pageTitle = title;
        pageBlade = bladeIndex;
        page = id;
    }
    function closePage() { page = ""; }

    // The last app, while it is still on this display.
    readonly property var resumeWorkspace: {
        if (lastApp <= 0) return null;
        const ws = ShellState.workspaceById(lastApp);
        return ws && ws.monitor && ws.monitor.name === monitor ? ws : null;
    }
    readonly property string resumeTitle: resumeWorkspace ? ShellState.metaFor(resumeWorkspace).title : ""
}
