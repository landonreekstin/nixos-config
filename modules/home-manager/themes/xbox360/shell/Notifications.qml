// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Notifications.qml
// The session's notification daemon (org.freedesktop.Notifications). Every
// notification pops a 360-style toast at the bottom of the screen with the
// console's notification chime; they are kept, newest first, for the Guide's
// Notifications list and the notification blade.
//
// The session stops dunst before the shell starts (session.nix): two owners
// of the bus name means whoever asked first wins and the other is silent.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Newest first.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length

    // The toast on screen now, if any, and what is waiting behind it.
    property var toast: null
    property var queue: []

    function showNext() {
        if (queue.length === 0) { toast = null; return; }
        toast = queue[0];
        queue = queue.slice(1);
        ShellState.play("notification");
        toastTimer.restart();
    }

    // A toast from the shell itself (Guide -> Audio): shown like any other,
    // but not kept in the Notifications list. One with a `tag` replaces the
    // toast of the same tag, on screen or waiting — flicking through outputs
    // should say where the sound IS, not queue up where it has been.
    function say(summary, body, icon, tag) {
        const t = { summary: summary, body: body, appName: "", appIcon: icon || "", image: "", tag: tag || "" };
        if (t.tag !== "" && toast !== null && toast.tag === t.tag) {
            toast = t;
            toastTimer.restart();
            return;
        }
        queue = queue.filter(q => t.tag === "" || q.tag !== t.tag).concat([t]);
        if (toast === null) showNext();
    }

    function dismissAll() {
        list.forEach(n => n.dismiss());
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.queue = root.queue.concat([{
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                appIcon: n.appIcon,
                image: n.image
            }]);
            if (root.toast === null) root.showNext();
        }
    }

    Timer {
        id: toastTimer
        interval: 4500
        onTriggered: {
            root.toast = null;
            gap.restart();
        }
    }
    // A breath between toasts, so two in a row read as two.
    Timer { id: gap; interval: 400; onTriggered: root.showNext() }
}
