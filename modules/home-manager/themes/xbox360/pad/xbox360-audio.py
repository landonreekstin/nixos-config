# ~/nixos-config/modules/home-manager/themes/xbox360/pad/xbox360-audio.py
# Guide -> Audio: switches the output AND the microphone together, between the
# host's audioDevices (session.nix writes them to the JSON file in argv[1]).
#
#   list          JSON: every device, whether it is plugged in, and which is in use
#   set <label>   make it the default output + input and move what is playing
#   current       the label in use, or nothing
#   keeps-tv      exit 0 when the device in use stays put in TV Mode (keepOnTv)
#
# Sinks and sources are matched by "<name>|<description>|<alsa.name>" — never
# by pro-output-N, which renumbers whenever an HDMI/DP output comes or goes.
import json
import os
import subprocess
import sys

with open(sys.argv[1]) as f:
    DEVICES = json.load(f)
FLIP_SINK = "flip-lr-sink"
FLIP_STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "audio-flip-lr.state")


def pactl(*args):
    return subprocess.run(["pactl", *args], capture_output=True, text=True).stdout


def nodes(kind):
    try:
        out = json.loads(pactl("-f", "json", "list", kind) or "[]")
    except ValueError:
        return []
    # A sink's monitor carries the sink's own alsa.name: never a microphone.
    return [n for n in out
            if not n["name"].endswith(".monitor") and n["name"] != FLIP_SINK
            and n.get("properties", {}).get("device.class") != "monitor"]


def key(n):
    p = n.get("properties", {})
    return "%s|%s|%s" % (n["name"], n.get("description", ""), p.get("alsa.name", ""))


def resolve(dev, sinks, sources):
    """The sink and source a device means right now (None if absent)."""
    sink = next((s for s in sinks if dev["output"] in key(s)), None)
    if sink is None:
        return None, None
    if dev["input"] == "same":
        # The input on the output's own card: same alsa.card, else the same
        # device in the name (alsa_output.usb-X-00.analog-stereo ->
        # alsa_input.usb-X-00.mono-fallback).
        card = sink.get("properties", {}).get("alsa.card")
        stem = "alsa_input." + sink["name"].removeprefix("alsa_output.").rsplit(".", 1)[0] + "."
        src = next((s for s in sources if card is not None
                    and s.get("properties", {}).get("alsa.card") == card), None) \
            or next((s for s in sources if s["name"].startswith(stem)), None)
    else:
        src = next((s for s in sources if dev["input"] in key(s)), None)
    return sink, src


def shown(n):
    """What a person calls it: the display's own name over HDMI, else the description."""
    if n is None:
        return ""
    name = n.get("properties", {}).get("alsa.name", "")
    return name if name and name != "USB Audio" else n.get("description", n["name"])


def state():
    sinks, sources = nodes("sinks"), nodes("sources")
    cur_sink = pactl("get-default-sink").strip()
    cur_src = pactl("get-default-source").strip()
    flipped = os.path.exists(FLIP_STATE)
    flip_real = open(FLIP_STATE).read().strip() if flipped else ""
    out = []
    for d in DEVICES:
        sinkN, srcN = resolve(d, sinks, sources)
        sink = sinkN["name"] if sinkN else None
        src = srcN["name"] if srcN else None
        # While the L/R flip is on, the default sink is the virtual flip sink;
        # the device under it is the one the state file remembers.
        active = sink is not None and (
            sink == cur_sink or (flipped and cur_sink == FLIP_SINK and sink == flip_real))
        out.append({
            "label": d["label"], "icon": d["icon"], "present": sink is not None,
            "active": active, "micActive": src is not None and src == cur_src,
            "sink": sink or "", "source": src or "",
            "outputName": shown(sinkN), "micName": shown(srcN), "keepOnTv": d.get("keepOnTv", False),
        })
    return out


def current():
    return next((d["label"] for d in state() if d["active"]), "")


def switch(label):
    sinks, sources = nodes("sinks"), nodes("sources")
    dev = next((d for d in DEVICES if d["label"] == label), None)
    if dev is None:
        sys.exit("no such device: " + label)
    sinkN, srcN = resolve(dev, sinks, sources)
    sink = sinkN["name"] if sinkN else None
    src = srcN["name"] if srcN else None
    if sink is None:
        sys.exit(label + " is not connected")
    # Back to real hardware first, as switch-audio-sink does: the flip sink
    # would otherwise keep playing to the old output.
    if os.path.exists(FLIP_STATE):
        subprocess.run(["toggle-audio-flip", "off"], capture_output=True)
    pactl("set-default-sink", sink)
    for line in pactl("list", "short", "sink-inputs").splitlines():
        pactl("move-sink-input", line.split()[0], sink)
    if src:
        pactl("set-default-source", src)
        # Only what records a microphone: the visualizer and screen recorders
        # listen to an output's monitor, and must stay on it.
        mics = {line.split()[0] for line in pactl("list", "short", "sources").splitlines()
                if not line.split()[1].endswith(".monitor")}
        for line in pactl("list", "short", "source-outputs").splitlines():
            if line.split()[1] in mics:
                pactl("move-source-output", line.split()[0], src)
    print(label)


cmd = sys.argv[2] if len(sys.argv) > 2 else "list"
if cmd == "list":
    print(json.dumps(state()))
elif cmd == "current":
    print(current())
elif cmd == "set":
    switch(sys.argv[3])
elif cmd == "keeps-tv":
    # TV Mode leaves the sound alone while a keepOnTv device (a headset) is in use.
    sys.exit(0 if any(d["active"] and d["keepOnTv"] for d in state()) else 1)
else:
    sys.exit("usage: xbox360-audio CONFIG list|current|set LABEL|keeps-tv")
