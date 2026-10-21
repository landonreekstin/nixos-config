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
    // Steam hours played, set by Games.qml.
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

    // ---- the Guide, messages and power ----------------------------------------
    property bool guideOpen: false

    // A tap of the Guide button: open or close the Guide, as on the console.
    function guide() { guideOpen = !guideOpen; }

    // What the notification blade shows: { title, icon, body, actions: [{ label, run }] }.
    property var message: null
    function openMessage(m) { message = m; }
    function closeMessage() { message = null; }

    function showNotification(n) {
        const acts = n.actions.map(a => ({ label: a.text, run: () => a.invoke() }));
        openMessage({
            title: n.summary,
            icon: n.image !== "" ? n.image : n.appIcon,
            body: n.body,
            actions: acts.concat([{ label: "Dismiss", run: () => n.dismiss() }])
        });
    }

    // Holding Guide, or the Guide's last row.
    function powerPrompt() {
        play("notification");
        openMessage({
            title: "Turn Off Console",
            icon: "system-shutdown",
            body: "Turn off the console, restart it, or sign out of this session.",
            actions: [
                { label: "Turn off", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
                { label: "Restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                { label: "Sign out", run: () => Hyprland.dispatch("exit") },
                { label: "Cancel", run: () => {} }
            ]
        });
    }
    onPowerRequested: powerPrompt()

    // The Guide's X: lock, the console's "sign out" of a profile (LockScreen.qml).
    property bool locked: false
    function signOut() { guideOpen = false; locked = true; }
    // Which screen carries the dashboard (set by shell.qml).
    property string primaryName: ""

    // Running apps for the Guide's Open Apps: each app workspace with windows.
    readonly property var apps: {
        const out = [];
        for (const ws of Hyprland.workspaces.values) {
            if (!isApp(ws)) continue;
            const tl = ws.toplevels ? ws.toplevels.values : [];
            if (tl.length === 0) continue;
            const m = metaFor(ws);
            const cls = tl[0].lastIpcObject && tl[0].lastIpcObject.class ? tl[0].lastIpcObject.class : "";
            const entry = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null;
            out.push({ id: ws.id, title: m.title, windows: tl.length, icon: entry ? entry.icon : "" });
        }
        return out.sort((a, b) => a.id - b.id);
    }
    readonly property int appCount: apps.length

    function closeApp(id) {
        const ws = workspaceById(id);
        if (!ws) return;
        for (const t of ws.toplevels.values)
            Hyprland.dispatch("closewindow address:" + (String(t.address).startsWith("0x") ? "" : "0x") + t.address);
    }

    function padLine(line) {
        padSeen = Date.now();
        const p = line.trim().split(" ");
        switch (p[0]) {
        case "hello": padLinked = true; padSend("ui " + (uiActive ? 1 : 0)); break;
        case "ping": break;
        case "btn": input(p[1]); break;
        case "guide": guide(); break;
        case "dashboard": dashboard(); break;
        case "keyboard": keyboardOpen = !keyboardOpen; break;
        case "power": powerRequested(); break;
        }
    }
    signal powerRequested()

    function padSend(msg) {
        if (padLinked && pad) {
            pad.write(msg + "\n");
            pad.flush();
        }
    }

    // The link is up only once the daemon says "hello". A Socket that failed
    // to connect does not retry, and toggling its `connected` did not make it
    // try again either (seen in the VM: one error at boot, then silence), so
    // each retry is a brand-new Socket, made with createObject (a Loader, being a
    // visual Item, never instantiated anything in this non-visual singleton).
    property bool padLinked: false
    property real padSeen: 0
    property var pad: null
    function padReconnect() {
        if (pad) pad.destroy();
        pad = padSocket.createObject(state);
    }
    Component {
        id: padSocket
        Socket {
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/xbox360-pad.sock"
            parser: SplitParser { onRead: data => state.padLine(data) }
            // Connect once the path is set: as a plain `connected: true` binding
            // the attempt could run before `path` was assigned.
            Component.onCompleted: connected = true
        }
    }
    // The link is judged ONLY by the daemon's ping (every 2 s): a dead daemon is
    // not always reported as a disconnect, and a replaced Socket reports its
    // own teardown after the new one is already up — reacting to that flapped
    // a good link down and tore it out (seen in the VM). Retry while unlinked.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (state.padLinked && Date.now() - state.padSeen > 5000) state.padLinked = false;
            if (!state.padLinked) state.padReconnect();
        }
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
