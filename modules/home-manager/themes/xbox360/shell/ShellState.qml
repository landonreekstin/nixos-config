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
    // Hours played (Steam and Heroic), set by Games.qml.
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
    //
    // `single`: the app keeps one instance (Discord, Signal, Spotify, Steam),
    // so if it already has a window, go to that instead — launching it again
    // only raises the old window wherever it is, and the new workspace sat on
    // its loading ring for good.
    function launch(cmd, title, bladeIndex, single) {
        if (single) {
            const t = findRunning(cmd);
            if (t !== null) {
                Hyprland.dispatch("focuswindow address:" + (String(t.address).startsWith("0x") ? "" : "0x") + t.address);
                return;
            }
        }
        const n = freeWorkspace();
        setMeta(n, { title: title, blade: bladeIndex, seen: false });
        Hyprland.dispatch("workspace " + n);
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // The program a command runs, as a window class would name it: "discord",
    // "signal-desktop", a flatpak's last id segment, minus Nix's wrapper dots.
    function classHint(cmd) {
        const words = cmd.trim().split(/\s+/).filter(w => !w.startsWith("-") && w.indexOf("=") < 0);
        let prog = words.length > 0 ? words[0] : "";
        if (/(^|\/)flatpak$/.test(prog)) {
            const id = words.find(w => /^[\w-]+(\.[\w-]+){2,}$/.test(w));
            prog = id ? id.split(".").pop() : "";
        }
        return prog.split("/").pop().replace(/^\./, "").replace(/-wrapped$/, "").toLowerCase();
    }
    function classOf(t) {
        const ipc = t.lastIpcObject && t.lastIpcObject.class ? t.lastIpcObject.class : "";
        return ipc !== "" ? ipc : (t.wayland ? t.wayland.appId : "");
    }
    // A window of the app `cmd` runs, or null: the class and the program name
    // equal, or either containing the other ("signal" in "signal-desktop").
    function findRunning(cmd) {
        const hint = classHint(cmd);
        if (hint.length < 3) return null;
        const all = Hyprland.toplevels.values;
        // An exact match first: "steam" is the client, not steam_app_1234.
        const exact = all.find(t => classOf(t).toLowerCase() === hint);
        if (exact) return exact;
        // Then by letters only: jellyfin-desktop is org.jellyfin.JellyfinDesktop.
        const bare = x => x.toLowerCase().replace(/[^a-z0-9]/g, "");
        const h = bare(hint);
        return all.find(t => {
            const cls = bare(classOf(t));
            return cls.length >= 3 && (cls.indexOf(h) >= 0 || h.indexOf(cls) >= 0);
        }) || null;
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

    // Leaving the Guide for somewhere else. Its layer holds the keyboard while
    // it is open, and when it lets go Hyprland hands focus back to the window
    // that had it — so a workspace switch sent at the same moment was undone,
    // straight back to the fullscreen game it was meant to leave. Close first,
    // move once the Guide has slid away.
    function fromGuide(fn) {
        guideOpen = false;
        guideExit.fn = fn;
        guideExit.restart();
    }
    Timer {
        id: guideExit
        property var fn: null
        interval: Cfg.motionMs + 50
        onTriggered: { const f = fn; fn = null; if (f) f(); }
    }

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
    // ---- switches: Night Mode, TV Mode ----------------------------------------
    // TV Mode: the whole session on the TV alone, sound included (session.nix
    // tvScript, which also restores the monitors and the output after).
    property bool tvMode: false
    function setTv(on) {
        tvMode = on;
        tvProc.command = ["sh", "-c", Cfg.tvCmd + (on ? " on" : " off") + "; " + Cfg.tvCmd + " status"];
        tvProc.running = true;
    }
    Process {
        id: tvProc
        command: ["sh", "-c", Cfg.tvCmd + " status"]
        running: Cfg.tvCmd !== ""
        stdout: StdioCollector { onStreamFinished: state.tvMode = text.trim() === "on" }
    }
    function settingText(what) {
        if (what === "night") return Theme.modeText;
        if (what === "tv") return tvMode ? "On" : "Off";
        return "";
    }
    function changeSetting(what, dir) {
        if (what === "night") Theme.cycle(dir);
        else if (what === "tv" && Cfg.tvCmd !== "") setTv(!tvMode);
    }

    // ---- bookkeeping ---------------------------------------------------------
    // The active border follows the blade colour of whatever is on screen.
    function applyBorder(bladeIndex) {
        const b = Theme.blades[Math.max(0, Math.min(bladeIndex, Theme.blades.length - 1))];
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
    // binding, a link from a notification) gets a workspace of its own. So
    // does a game started from inside Steam or Heroic: it opens over its
    // launcher, and the Guide's Open Apps then only knew "Heroic".
    readonly property var gameClasses: Cfg.gameClasses.map(r => new RegExp(r))
    function isGameClass(cls) { return gameClasses.some(r => r.test(cls)); }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "openwindow") return;
            const p = event.data.split(",");
            if (p.length < 3) return;
            const addr = p[0], wsName = p[1], cls = p[2], title = p.slice(3).join(",");
            if (wsName === "dashboard") {
                const entry = DesktopEntries.heuristicLookup(cls);
                state.moveToOwn(addr, entry ? entry.name : cls, 5);
            } else if (state.isGameClass(cls)) {
                const ws = Hyprland.workspaces.values.find(w => w.name === wsName);
                if (!state.isApp(ws)) return;
                // Only off a launcher: a game's own second window (a splash, then
                // the game) stays together.
                const others = ws.toplevels.values.filter(t => String(t.address).replace(/^0x/, "") !== addr);
                if (others.length > 0 && !others.some(t => state.isGameClass(state.classOf(t))))
                    state.moveToOwn(addr, title !== "" ? title : cls, 2);
            }
        }
    }
    function moveToOwn(addr, title, bladeIndex) {
        const n = freeWorkspace();
        setMeta(n, { title: title, blade: bladeIndex, seen: false });
        Hyprland.dispatch("movetoworkspace " + n + ",address:0x" + addr);
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
