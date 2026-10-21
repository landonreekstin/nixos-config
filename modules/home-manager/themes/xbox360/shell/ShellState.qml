// ~/nixos-config/modules/home-manager/themes/xbox360/shell/ShellState.qml
// Everything the dashboard remembers, shared by every screen's frame, the
// dashboard menus and (later) the Guide and the controller.
//
// The model, as on the console:
//   - the DASHBOARD is its own Hyprland workspace (name:dashboard) where the
//     blades are menus; nothing tiles there;
//   - launching anything puts it on a NEW numbered workspace, drawn as a
//     full-width "submenu" frame in the colour of the blade it came from, with
//     the app's name in the header (`meta` remembers which is which);
//   - when an app's last window closes, its workspace returns to the dashboard,
//     the way quitting a game did.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Config.js" as Cfg

Singleton {
    id: state

    // ---- dashboard selection ----------------------------------------------
    property int blade: Cfg.startBlade
    property var rows: [0, 0, 0, 0, 0]      // the highlighted row on each blade
    property string page: ""                // a full-screen page open over the dashboard
    property string pageTitle: ""
    property int pageBlade: Cfg.startBlade

    function setRow(b, i) {
        const r = rows.slice();
        r[b] = i;
        rows = r;
    }

    // ---- app workspaces ----------------------------------------------------
    // id -> { title, blade, seen }: `seen` once a window has appeared, so an
    // app that is still loading is not mistaken for one that has quit.
    // Achievements are a later milestone; the card shows this meanwhile.
    property int gamerscore: 0

    property var meta: ({})
    property int lastApp: -1

    readonly property HyprlandWorkspace focused: Hyprland.focusedWorkspace
    readonly property bool onDashboard: focused !== null && focused.name === "dashboard"

    function isApp(ws) { return ws !== null && ws.id > 0 && ws.name === String(ws.id); }

    function workspaceById(id) {
        const all = Hyprland.workspaces.values;
        for (let i = 0; i < all.length; i++) if (all[i].id === id) return all[i];
        return null;
    }

    // What the frame around an app workspace shows: the recorded launch, else
    // the first window's app name, else just the number.
    function metaFor(ws) {
        if (!ws) return { title: "", blade: 5 };
        const m = meta[ws.id];
        if (m) return m;
        const tl = ws.toplevels ? ws.toplevels.values : [];
        if (tl.length > 0) {
            const t = tl[0];
            const cls = t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : "";
            const entry = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null;
            return { title: entry ? entry.name : (cls !== "" ? cls : t.title), blade: 5 };
        }
        if (ws.id < 0) return { title: ws.name.replace(/^special:/, ""), blade: 5 };
        return { title: isApp(ws) ? "Workspace " + ws.id : ws.name, blade: 5 };
    }

    function setMeta(id, m) {
        const c = Object.assign({}, meta);
        if (m === null) delete c[id]; else c[id] = m;
        meta = c;
        store.setText(JSON.stringify(c));
    }

    function freeWorkspace() {
        const used = Hyprland.workspaces.values.map(w => w.id);
        let n = 1;
        while (used.indexOf(n) >= 0) n++;
        return n;
    }

    // Run `cmd` on a fresh workspace. Switching FIRST and launching second
    // means the window lands there even when the process that maps it is not
    // the one we started (flatpak, Steam, single-instance apps), which an
    // `exec [workspace n]` rule would miss.
    function launch(cmd, title, bladeIndex) {
        const n = freeWorkspace();
        setMeta(n, { title: title, blade: bladeIndex, seen: false });
        Hyprland.dispatch("workspace " + n);
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function dashboard() {
        page = "";
        Hyprland.dispatch("workspace name:dashboard");
    }

    function resume() {
        if (lastApp > 0 && workspaceById(lastApp) !== null) {
            play("select-a");
            Hyprland.dispatch("workspace " + lastApp);
        }
    }
    readonly property string resumeTitle: {
        if (lastApp <= 0) return "";
        const ws = workspaceById(lastApp);
        return ws ? metaFor(ws).title : "";
    }

    function openPage(id, title, bladeIndex) {
        pageTitle = title;
        pageBlade = bladeIndex;
        page = id;
    }
    function closePage() { page = ""; }

    // ---- pointer -----------------------------------------------------------
    // Rows and bands select on hover, but only for a pointer that really moved
    // ON SCREEN: when a menu slides in under a parked pointer, Qt reports
    // motion relative to the moving item, and a couch user's idle mouse would
    // otherwise pick rows at random. Every shell window is full-screen at the
    // same origin, so window coordinates are screen coordinates.
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(item, x, y) {
        const p = item.mapToItem(null, x, y);
        // The first sighting is only a baseline: a pointer already parked over
        // the menu when the shell starts has not "moved".
        if (lastPointer.x < 0) { lastPointer = Qt.point(p.x, p.y); return false; }
        if (Math.abs(p.x - lastPointer.x) < 1 && Math.abs(p.y - lastPointer.y) < 1) return false;
        lastPointer = Qt.point(p.x, p.y);
        return true;
    }

    // ---- sounds ------------------------------------------------------------
    function play(cue) {
        Quickshell.execDetached([Cfg.pwPlay, Cfg.sounds + "/" + cue + ".wav"]);
    }

    // ---- input routing -----------------------------------------------------
    // Whatever is on screen (the dashboard menu, the Guide, the keyboard, a
    // dialog) registers a handler { active, priority, handle(btn) }; the
    // keyboard, the controller daemon and IPC all send buttons to input(), and
    // the highest-priority active handler gets them. Returns whether one did.
    property var handlers: []
    function pushHandler(h) { handlers = handlers.concat([h]); }
    function removeHandler(h) { handlers = handlers.filter(x => x !== h); }
    function input(btn) {
        let best = null;
        for (let i = 0; i < handlers.length; i++) {
            const h = handlers[i];
            if (h.active && (best === null || (h.priority || 0) >= (best.priority || 0))) best = h;
        }
        return best !== null && best.handle(btn);
    }
    // Whether the shell's own UI has the controller right now. The daemon
    // grabs the pads while it does, so the app underneath doesn't also react.
    readonly property bool uiActive: handlers.some(h => h.active)
    onUiActiveChanged: padSend("ui " + (uiActive ? 1 : 0))

    // ---- the controller daemon (pad/xbox360-pad.py) -------------------------
    property bool keyboardOpen: false

    // What a Guide tap does. The Guide blade replaces this in a later milestone;
    // until then it is the dashboard <-> last-app toggle.
    function guide() {
        if (onDashboard) resume();
        else dashboard();
    }

    function padLine(line) {
        const p = line.trim().split(" ");
        switch (p[0]) {
        case "btn": input(p[1]); break;
        case "guide": guide(); break;
        case "dashboard": dashboard(); break;
        case "keyboard": keyboardOpen = !keyboardOpen; break;
        case "power": powerRequested(); break;
        }
    }
    signal powerRequested()

    function padSend(msg) {
        if (pad.connected) {
            pad.write(msg + "\n");
            pad.flush();
        }
    }

    Socket {
        id: pad
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/xbox360-pad.sock"
        connected: true
        parser: SplitParser { onRead: data => state.padLine(data) }
        onConnectedChanged: if (connected) state.padSend("ui " + (state.uiActive ? 1 : 0))
    }
    // The daemon may start after the shell, or restart: keep trying.
    Timer {
        interval: 2000
        running: !pad.connected
        repeat: true
        onTriggered: pad.connected = true
    }
    // ---- bookkeeping ---------------------------------------------------------
    // The active border follows the blade colour of whatever is on screen.
    function applyBorder(bladeIndex) {
        const b = Cfg.blades[Math.max(0, Math.min(bladeIndex, Cfg.blades.length - 1))];
        Quickshell.execDetached([Cfg.hyprctl, "keyword", "general:col.active_border",
            "rgb(ffffff) rgb(" + b.base + ") rgb(" + b.stops[3] + ") 90deg"]);
    }
    onFocusedChanged: {
        if (focused && isApp(focused)) applyBorder(metaFor(focused).blade);
    }

    Timer {
        interval: 700
        running: true
        repeat: true
        onTriggered: {
            const ws = state.focused;
            if (!state.isApp(ws)) return;
            const count = ws.toplevels ? ws.toplevels.values.length : 0;
            const m = state.meta[ws.id];
            if (count > 0) {
                state.lastApp = ws.id;
                if (m && !m.seen) state.setMeta(ws.id, Object.assign({}, m, { seen: true }));
            } else if (m && m.seen) {
                // Its last window closed: back to the dashboard, as on the console.
                state.setMeta(ws.id, null);
                if (state.lastApp === ws.id) state.lastApp = -1;
                state.dashboard();
            }
        }
    }

    // Anything that opens ON the dashboard (an app started from a terminal
    // binding, a link from a notification) gets a workspace of its own.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "openwindow") return;
            const p = event.data.split(",");
            if (p.length < 3 || p[1] !== "dashboard") return;
            const n = state.freeWorkspace();
            const entry = DesktopEntries.heuristicLookup(p[2]);
            state.setMeta(n, { title: entry ? entry.name : p[2], blade: 5, seen: false });
            Hyprland.dispatch("movetoworkspace " + n + ",address:0x" + p[0]);
        }
    }

    // `meta` survives a shell restart, so a reload doesn't strip every open
    // app's frame of its name.
    FileView {
        id: store
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/xbox360-workspaces.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try { state.meta = JSON.parse(text()); } catch (e) { state.meta = {}; }
        }
    }
}
