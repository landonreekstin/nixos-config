#!/usr/bin/env python3
# ~/nixos-config/scripts/test-screenshare.py
#
# Drives org.freedesktop.portal.ScreenCast through CreateSession -> SelectSources ->
# Start. Start is the call that makes the compositor's screen-picker dialog appear, so
# this exercises exactly the path Vesktop/OBS use for screen sharing — without needing
# to log into Discord first.
#
# Used from the test VMs (see hosts/vm-common.nix) to confirm which portal backend is
# actually serving ScreenCast and that the picker really shows. All three calls must
# happen on ONE D-Bus connection: the portal destroys the session as soon as the
# creating connection drops, which is why a shell loop of `busctl call` cannot work.

import random
import string
import sys

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

PORTAL = "org.freedesktop.portal.Desktop"
PORTAL_PATH = "/org/freedesktop/portal/desktop"

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
screencast = dbus.Interface(bus.get_object(PORTAL, PORTAL_PATH),
                            "org.freedesktop.portal.ScreenCast")

# Request objects are named after the caller's unique bus name, ':1.42' -> '1_42'.
sender = bus.get_unique_name()[1:].replace(".", "_")
loop = GLib.MainLoop()
session = {}


def tok():
    return "t" + "".join(random.choices(string.ascii_lowercase, k=10))


def on_reply(token, handler):
    """Listen for the Response signal on the Request object for `token`."""
    bus.add_signal_receiver(
        handler,
        signal_name="Response",
        dbus_interface="org.freedesktop.portal.Request",
        path="{}/request/{}/{}".format(PORTAL_PATH, sender, token),
    )


def fail(stage, code):
    # code 1 = user cancelled the dialog, 2 = ended some other way.
    print("[FAIL] {} returned code {}{}".format(
        stage, code, " (cancelled)" if code == 1 else ""))
    loop.quit()


def started(code, results):
    if code != 0:
        return fail("Start", code)
    streams = results.get("streams", [])
    print("[OK] picker accepted - portal returned {} stream(s)".format(len(streams)))
    for node_id, _props in streams:
        print("     pipewire node id: {}".format(node_id))
    print("[OK] screen sharing works in this session")
    loop.quit()


def sources_selected(code, _results):
    if code != 0:
        return fail("SelectSources", code)
    t = tok()
    on_reply(t, started)
    print("--> calling Start: the screen-picker dialog should appear NOW")
    screencast.Start(session["handle"], "", {"handle_token": t})


def session_created(code, results):
    if code != 0:
        return fail("CreateSession", code)
    session["handle"] = results["session_handle"]
    print("[OK] session created: {}".format(session["handle"]))
    t = tok()
    on_reply(t, sources_selected)
    screencast.SelectSources(session["handle"], {
        "handle_token": t,
        "types": dbus.UInt32(1 | 2),   # 1 = monitors, 2 = windows
        "multiple": False,
    })


def main():
    t = tok()
    on_reply(t, session_created)
    try:
        screencast.CreateSession({"handle_token": t, "session_handle_token": tok()})
    except dbus.DBusException as exc:
        print("[FAIL] could not reach the ScreenCast portal: {}".format(exc))
        return 1
    print("driving org.freedesktop.portal.ScreenCast ...")
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
