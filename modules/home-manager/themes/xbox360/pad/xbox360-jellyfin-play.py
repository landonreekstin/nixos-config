"""xbox360-jellyfin-play: play one Jellyfin item in mpv, keeping Jellyfin's
resume point and watched state in step — the dashboard's Videos library
launches this on a workspace of its own.

  xbox360-jellyfin-play <mpv> <state.json> <itemId>

state.json is what the shell saved at sign-in: { url, token, userId, deviceId }.
Starts at the item's resume point, loads its external subtitles (Bazarr's),
and reports start / progress (every 10 s) / stop to /Sessions/Playing so the
position is saved and anything past ~90 % counts as watched.
"""

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
import uuid

MPV, STATE, ITEM = sys.argv[1], sys.argv[2], sys.argv[3]
st = json.load(open(STATE))
URL, TOKEN, USER = st["url"].rstrip("/"), st["token"], st["userId"]
AUTH = ('MediaBrowser Client="Xbox 360 Dashboard", Device="%s", DeviceId="%s", '
        'Version="1.0", Token="%s"' % (socket.gethostname(), st.get("deviceId", "xbox360"), TOKEN))
TICKS = 10_000_000


def api(method, path, body=None):
    req = urllib.request.Request(URL + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": AUTH, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


item = api("GET", "/Users/%s/Items/%s" % (USER, ITEM))
start = (item.get("UserData") or {}).get("PlaybackPositionTicks", 0) / TICKS
source = (item.get("MediaSources") or [{}])[0]
msid = source.get("Id", ITEM)
title = item.get("Name", "")
if item.get("SeriesName"):
    title = "%s — S%02dE%02d %s" % (item["SeriesName"], item.get("ParentIndexNumber") or 0,
                                     item.get("IndexNumber") or 0, title)

subs = []
for s in source.get("MediaStreams", []):
    if s.get("Type") == "Subtitle" and s.get("IsExternal"):
        subs.append("--sub-file=%s/Videos/%s/%s/Subtitles/%d/Stream.%s?api_key=%s"
                    % (URL, ITEM, msid, s["Index"], s.get("Codec") or "srt", TOKEN))

session = uuid.uuid4().hex
sock = "/tmp/xbox360-mpv-%s.sock" % session
stream = "%s/Videos/%s/stream?static=true&MediaSourceId=%s&api_key=%s" % (URL, ITEM, msid, TOKEN)
mpv = subprocess.Popen([MPV, "--fs", "--force-window=immediate", "--input-ipc-server=" + sock,
                        "--force-media-title=" + title, "--start=%d" % int(start),
                        "--osd-on-seek=msg-bar"] + subs + [stream])


def mpv_get(prop):
    try:
        c = socket.socket(socket.AF_UNIX)
        c.settimeout(2)
        c.connect(sock)
        c.sendall(json.dumps({"command": ["get_property", prop]}).encode() + b"\n")
        data = b""
        while not data.endswith(b"\n"):
            chunk = c.recv(4096)
            if not chunk:
                break
            data += chunk
        c.close()
        for line in data.splitlines():
            msg = json.loads(line)
            if "data" in msg:
                return msg["data"]
    except (OSError, ValueError):
        pass
    return None


def report(path, pos, paused=False):
    try:
        api("POST", path, {"ItemId": ITEM, "MediaSourceId": msid, "PlaySessionId": session,
                           "PositionTicks": int(pos * TICKS), "IsPaused": paused,
                           "CanSeek": True, "PlayMethod": "DirectPlay"})
    except OSError as e:
        print("report", path, e, flush=True)


pos = start
report("/Sessions/Playing", pos)
# Read the position every 2 s (local and cheap) so quitting saves where you
# really were; tell Jellyfin every 10 s.
tick = 0
while mpv.poll() is None:
    time.sleep(2)
    p = mpv_get("time-pos")
    if p is not None:
        pos = p
    tick += 1
    if tick % 5 == 0:
        report("/Sessions/Playing/Progress", pos, bool(mpv_get("pause")))
report("/Sessions/Playing/Stopped", pos)
try:
    os.unlink(sock)
except OSError:
    pass
