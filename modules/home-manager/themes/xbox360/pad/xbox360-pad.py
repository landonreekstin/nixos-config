"""xbox360-pad: the Xbox 360 rice's controller daemon.

Reads every gamepad (evdev; xpad and xpadneo both expose Guide as BTN_MODE) and
turns it into three things:

  * The GUIDE CHORD, always, even in games — no app ever gets the Guide button:
      tap Guide            open the Guide (the shell decides what that means)
      hold Guide ~1 s      the "turn off" prompt
      Guide + LB / RB      previous / next app workspace
      Guide + D-pad/stick  move focus between tiled windows
      Guide + Y            the dashboard
      Guide + X            the on-screen keyboard
      Guide + Back         close the focused window
      Guide + Start        toggle fullscreen
  * SHELL INPUT, while the shell's own UI (dashboard, Guide, keyboard, ...) is
    up: buttons go to the shell over a socket, with key repeat on directions,
    and the pads are GRABBED so the app underneath doesn't also see them.
  * DESKTOP EMULATION, for apps that can't use a controller (browser, file
    manager, terminal): right stick = pointer, RT/LT = left/right click, left
    stick = scroll, D-pad = arrows, A = Enter, B = Back, X = Backspace,
    Y = keyboard, LB/RB = previous/next tab. Games and players listed in
    `passthrough` (and anything fullscreen) get the pad untouched.

The shell connects to $XDG_RUNTIME_DIR/xbox360-pad.sock. Daemon -> shell lines:
`btn <name>`, `guide`, `power`, `dashboard`, `keyboard`. Shell -> daemon:
`ui 1` / `ui 0` (whether the shell has the controller).

Configuration is one JSON file, the only argument (built by pad.nix).
"""

import asyncio
import json
import os
import re
import sys
import time

import evdev
from evdev import UInput, ecodes as E

CFG = json.load(open(sys.argv[1]))
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SOCK = os.path.join(RUNTIME, "xbox360-pad.sock")
VIRTUAL_NAME = "xbox360-pad virtual input"

PASSTHROUGH = [re.compile(p) for p in CFG.get("passthrough", [])]
# Per-app key maps: { "match": regex, "keys": { button: "KEY_NAME", ... } }.
# A focused app matching one gets exactly those keys (e.g. mpv, which nixpkgs
# builds without SDL and so cannot read a controller itself).
PROFILES = [(re.compile(p["match"]), {b: getattr(E, k) for b, k in p["keys"].items()})
            for p in CFG.get("profiles", [])]
BROWSERS = [re.compile(p) for p in CFG.get("browsers", [])]

# xpad and xpadneo both report X as BTN_X (== BTN_NORTH) and Y as BTN_Y
# (== BTN_WEST) — the opposite of the Linux gamepad spec's compass names.
# `swapXY` is the escape hatch for a driver that follows the spec.
BUTTONS = {
    E.BTN_SOUTH: "a", E.BTN_EAST: "b",
    E.BTN_X: "y" if CFG.get("swapXY") else "x",
    E.BTN_Y: "x" if CFG.get("swapXY") else "y",
    E.BTN_TL: "lb", E.BTN_TR: "rb", E.BTN_TL2: "lt", E.BTN_TR2: "rt",
    E.BTN_SELECT: "back", E.BTN_START: "start", E.BTN_MODE: "guide",
    E.BTN_THUMBL: "ls", E.BTN_THUMBR: "rs",
}
DIRECTIONS = ("up", "down", "left", "right")


def log(*a):
    print("xbox360-pad:", *a, flush=True)


# ---------------------------------------------------------------------------
# Hyprland
# ---------------------------------------------------------------------------
def hypr_dir():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    return os.path.join(RUNTIME, "hypr", sig)


async def hyprctl(*args):
    proc = await asyncio.create_subprocess_exec(
        CFG["hyprctl"], *args,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    out, _ = await proc.communicate()
    return out.decode(errors="replace")


async def hyprjson(what):
    try:
        return json.loads(await hyprctl("-j", what))
    except ValueError:
        return None


class Focus:
    """The focused window's class and whether it is fullscreen, from socket2."""

    def __init__(self):
        self.cls = ""
        self.fullscreen = False

    async def refresh(self):
        w = await hyprjson("activewindow") or {}
        self.cls = w.get("class", "") or ""
        self.fullscreen = bool(w.get("fullscreen", 0))

    async def watch(self):
        await self.refresh()
        while True:
            try:
                r, _ = await asyncio.open_unix_connection(os.path.join(hypr_dir(), ".socket2.sock"))
                while line := await r.readline():
                    ev = line.decode(errors="replace").rstrip("\n")
                    if ev.startswith("activewindow>>"):
                        self.cls = ev[len("activewindow>>"):].split(",", 1)[0]
                        await self.refresh()
                    elif ev.startswith("fullscreen>>"):
                        self.fullscreen = ev.endswith("1")
            except OSError as e:
                log("hyprland events:", e)
            await asyncio.sleep(2)

    def passthrough(self):
        return self.fullscreen or any(p.search(self.cls) for p in PASSTHROUGH)

    def browser(self):
        return any(p.search(self.cls) for p in BROWSERS)

    def profile(self):
        for rx, keys in PROFILES:
            if rx.search(self.cls):
                return keys
        return None


# ---------------------------------------------------------------------------
# The shell link
# ---------------------------------------------------------------------------
class Shell:
    def __init__(self):
        self.writers = set()
        self.ui = False          # the shell's own UI has the controller
        self.on_ui_change = None

    async def serve(self):
        try:
            os.unlink(SOCK)
        except FileNotFoundError:
            pass
        server = await asyncio.start_unix_server(self.client, SOCK)
        async with server:
            await server.serve_forever()

    async def client(self, reader, writer):
        self.writers.add(writer)
        log("shell connected")
        try:
            while line := await reader.readline():
                msg = line.decode().strip()
                if msg in ("ui 1", "ui 0"):
                    ui = msg == "ui 1"
                    if ui != self.ui:
                        self.ui = ui
                        if self.on_ui_change:
                            self.on_ui_change()
        finally:
            self.writers.discard(writer)
            if not self.writers and self.ui:
                self.ui = False
                if self.on_ui_change:
                    self.on_ui_change()
            log("shell disconnected")

    @property
    def connected(self):
        return bool(self.writers)

    def send(self, msg):
        for w in list(self.writers):
            try:
                w.write((msg + "\n").encode())
            except (ConnectionError, RuntimeError):
                self.writers.discard(w)


# ---------------------------------------------------------------------------
# Desktop emulation: one virtual keyboard + mouse
# ---------------------------------------------------------------------------
KEYS = [E.KEY_ENTER, E.KEY_ESC, E.KEY_BACKSPACE, E.KEY_UP, E.KEY_DOWN, E.KEY_LEFT,
        E.KEY_RIGHT, E.KEY_TAB, E.KEY_LEFTCTRL, E.KEY_LEFTSHIFT, E.KEY_LEFTALT,
        E.BTN_LEFT, E.BTN_RIGHT, E.BTN_MIDDLE] + sorted(
    {c for _, keys in PROFILES for c in keys.values()})


class Virtual:
    def __init__(self):
        self.ui = UInput({
            E.EV_KEY: KEYS,
            E.EV_REL: [E.REL_X, E.REL_Y, E.REL_WHEEL, E.REL_HWHEEL],
        }, name=VIRTUAL_NAME)

    def key(self, code, down):
        self.ui.write(E.EV_KEY, code, 1 if down else 0)
        self.ui.syn()

    def combo(self, *codes):
        for c in codes:
            self.ui.write(E.EV_KEY, c, 1)
        for c in reversed(codes):
            self.ui.write(E.EV_KEY, c, 0)
        self.ui.syn()

    def move(self, dx, dy):
        if dx:
            self.ui.write(E.EV_REL, E.REL_X, dx)
        if dy:
            self.ui.write(E.EV_REL, E.REL_Y, dy)
        self.ui.syn()

    def scroll(self, v, h):
        if v:
            self.ui.write(E.EV_REL, E.REL_WHEEL, v)
        if h:
            self.ui.write(E.EV_REL, E.REL_HWHEEL, h)
        self.ui.syn()


# ---------------------------------------------------------------------------
# One controller
# ---------------------------------------------------------------------------
class Pad:
    def __init__(self, dev, daemon):
        self.dev = dev
        self.d = daemon
        self.axes = {}
        self.ranges = {}
        for code, info in dev.capabilities().get(E.EV_ABS, []):
            self.ranges[code] = (info.min, info.max)
        self.down = set()        # normalised buttons currently held
        self.grabbed = False

    def norm(self, code):
        """Stick axes to -1..1, triggers to 0..1."""
        lo, hi = self.ranges.get(code, (-32768, 32767))
        v = self.axes.get(code, (lo + hi) / 2)
        if lo >= 0:   # a trigger
            return (v - lo) / max(hi - lo, 1)
        return max(-1.0, min(1.0, (2 * (v - lo) / max(hi - lo, 1)) - 1))

    def stick(self, xc, yc):
        return self.norm(xc), self.norm(yc)

    def set_grab(self, on):
        if on == self.grabbed:
            return
        try:
            if on:
                self.dev.grab()
            else:
                self.dev.ungrab()
            self.grabbed = on
        except OSError as e:
            log("grab", self.dev.path, e)

    def press(self, btn):
        if btn not in self.down:
            self.down.add(btn)
            self.d.press(btn)

    def release(self, btn):
        if btn in self.down:
            self.down.discard(btn)
            self.d.release(btn)

    def update_dir(self, prefix, x, y, on=0.5, off=0.35):
        """Turn an analogue pair into virtual up/down/left/right, with
        hysteresis and only the dominant axis on a diagonal."""
        for name, val in (("left", -x), ("right", x), ("up", -y), ("down", y)):
            key = prefix + name
            dominant = (abs(x) >= abs(y)) == (name in ("left", "right"))
            if key in self.down:
                if val < off or not dominant:
                    self.release(key)
            elif val > on and dominant:
                self.press(key)

    async def run(self):
        log("reading", self.dev.path, self.dev.name)
        try:
            async for ev in self.dev.async_read_loop():
                if ev.type == E.EV_KEY and ev.code in BUTTONS:
                    (self.press if ev.value else self.release)(BUTTONS[ev.code])
                elif ev.type == E.EV_ABS:
                    self.axes[ev.code] = ev.value
                    c = ev.code
                    if c in (E.ABS_HAT0X, E.ABS_HAT0Y):
                        # Both axes from state: a horizontal event must not
                        # release a vertical direction that is still held.
                        self.update_dir("", self.axes.get(E.ABS_HAT0X, 0),
                                        self.axes.get(E.ABS_HAT0Y, 0), 0.5, 0.5)
                    elif c in (E.ABS_X, E.ABS_Y):
                        x, y = self.stick(E.ABS_X, E.ABS_Y)
                        self.update_dir("ls-", x, y)
                    elif c in (E.ABS_Z, E.ABS_BRAKE):
                        (self.press if self.norm(c) > 0.5 else self.release)("lt")
                    elif c in (E.ABS_RZ, E.ABS_GAS):
                        (self.press if self.norm(c) > 0.5 else self.release)("rt")
        except OSError:
            log("lost", self.dev.path)
        finally:
            for b in list(self.down):
                self.release(b)
            self.d.pads.pop(self.dev.path, None)


# ---------------------------------------------------------------------------
# The daemon
# ---------------------------------------------------------------------------
class Daemon:
    def __init__(self):
        self.pads = {}
        self.focus = Focus()
        self.shell = Shell()
        self.shell.on_ui_change = self.ui_changed
        self.virtual = Virtual()
        self.guide_down = False
        self.chord_used = False
        self.repeat_task = None
        self.loop = None

    # -- device discovery ---------------------------------------------------
    async def scan(self):
        while True:
            for path in evdev.list_devices():
                if path in self.pads:
                    continue
                try:
                    dev = evdev.InputDevice(path)
                except OSError:
                    continue
                keys = dev.capabilities().get(E.EV_KEY, [])
                if dev.name == VIRTUAL_NAME or E.BTN_SOUTH not in keys or E.BTN_MODE not in keys:
                    dev.close()
                    continue
                pad = Pad(dev, self)
                self.pads[path] = pad
                pad.set_grab(self.shell.ui)
                self.loop.create_task(pad.run())
            await asyncio.sleep(2)

    def ui_changed(self):
        # While the shell's UI has the controller, the app underneath must not
        # also act on it (a game would jump while you pick a Guide row).
        for p in self.pads.values():
            p.set_grab(self.shell.ui)
        self.stop_repeat()

    # -- dispatch ------------------------------------------------------------
    def press(self, btn):
        base = btn[3:] if btn.startswith("ls-") else btn
        if base == "guide":
            self.guide_down = True
            self.chord_used = False
            self.loop.create_task(self.long_guide())
            return
        if self.guide_down:
            self.chord_used = True
            self.loop.create_task(self.chord(base))
            return
        if self.shell.ui:
            self.shell.send("btn " + base)
            if base in DIRECTIONS:
                self.start_repeat(base)
            return
        self.app_press(btn)

    def release(self, btn):
        base = btn[3:] if btn.startswith("ls-") else btn
        if base == "guide":
            self.guide_down = False
            if not self.chord_used:
                self.guide()
            return
        self.stop_repeat()
        self.app_release(btn)

    async def long_guide(self):
        await asyncio.sleep(1.0)
        if self.guide_down and not self.chord_used:
            self.chord_used = True
            self.shell.send("power")

    def guide(self):
        if self.shell.connected:
            self.shell.send("guide")
        else:
            self.loop.create_task(hyprctl("dispatch", "workspace", "name:dashboard"))

    def start_repeat(self, btn):
        self.stop_repeat()

        async def rep():
            await asyncio.sleep(0.3)
            while True:
                self.shell.send("btn " + btn)
                await asyncio.sleep(0.1)
        self.repeat_task = self.loop.create_task(rep())

    def stop_repeat(self):
        if self.repeat_task:
            self.repeat_task.cancel()
            self.repeat_task = None

    async def chord(self, btn):
        if btn in ("lb", "rb"):
            await self.cycle(-1 if btn == "lb" else 1)
        elif btn in DIRECTIONS:
            await hyprctl("dispatch", "movefocus", btn[0])
        elif btn == "y":
            self.shell.send("dashboard") if self.shell.connected else \
                await hyprctl("dispatch", "workspace", "name:dashboard")
        elif btn == "x":
            self.shell.send("keyboard")
        elif btn == "back":
            await hyprctl("dispatch", "killactive")
        elif btn == "start":
            await hyprctl("dispatch", "fullscreen")

    async def cycle(self, step):
        """Next/previous app workspace (numbered, with windows), wrapping."""
        wss = await hyprjson("workspaces") or []
        ids = sorted(w["id"] for w in wss if w["id"] > 0 and w.get("windows", 0) > 0)
        if not ids:
            return
        cur = (await hyprjson("activeworkspace") or {}).get("id", 0)
        if cur in ids:
            nxt = ids[(ids.index(cur) + step) % len(ids)]
        else:
            nxt = ids[0] if step > 0 else ids[-1]
        await hyprctl("dispatch", "workspace", str(nxt))

    # -- desktop emulation ----------------------------------------------------
    def emulating(self):
        # A profiled app (mpv) gets its keys even fullscreen, which otherwise
        # means "a game: hands off".
        return self.focus.profile() is not None or not self.focus.passthrough()

    def app_press(self, btn):
        if not self.emulating():
            return
        v = self.virtual
        prof = self.focus.profile()
        if prof is not None:
            if btn in prof:
                v.key(prof[btn], True)
            return
        arrows = {"up": E.KEY_UP, "down": E.KEY_DOWN, "left": E.KEY_LEFT, "right": E.KEY_RIGHT}
        if btn in arrows:
            v.key(arrows[btn], True)
        elif btn == "a":
            v.key(E.KEY_ENTER, True)
        elif btn == "b":
            if self.focus.browser():
                v.combo(E.KEY_LEFTALT, E.KEY_LEFT)
            else:
                v.key(E.KEY_ESC, True)
        elif btn == "x":
            v.key(E.KEY_BACKSPACE, True)
        elif btn == "y":
            self.shell.send("keyboard")
        elif btn == "lb":
            v.combo(E.KEY_LEFTCTRL, E.KEY_LEFTSHIFT, E.KEY_TAB)
        elif btn == "rb":
            v.combo(E.KEY_LEFTCTRL, E.KEY_TAB)
        elif btn == "rt":
            v.key(E.BTN_LEFT, True)
        elif btn == "lt":
            v.key(E.BTN_RIGHT, True)
        elif btn == "rs":
            v.key(E.BTN_MIDDLE, True)

    def app_release(self, btn):
        # Release whatever this button may have pressed — harmless if it
        # pressed nothing, and safe across a focus change mid-press.
        v = self.virtual
        prof = self.focus.profile()
        if prof is not None and btn in prof:
            v.key(prof[btn], False)
            return
        codes = {"up": E.KEY_UP, "down": E.KEY_DOWN, "left": E.KEY_LEFT, "right": E.KEY_RIGHT,
                 "a": E.KEY_ENTER, "b": E.KEY_ESC, "x": E.KEY_BACKSPACE,
                 "rt": E.BTN_LEFT, "lt": E.BTN_RIGHT, "rs": E.BTN_MIDDLE}
        if btn in codes:
            v.key(codes[btn], False)

    async def analog(self):
        """60 Hz: right stick moves the pointer, left stick scrolls."""
        acc_v = acc_h = 0.0
        while True:
            await asyncio.sleep(1 / 60)
            if self.shell.ui or self.guide_down or not self.emulating() or self.focus.profile() is not None:
                continue
            for p in list(self.pads.values()):
                rx, ry = p.stick(E.ABS_RX, E.ABS_RY)
                mag = (rx * rx + ry * ry) ** 0.5
                if mag > 0.15:
                    speed = CFG.get("pointerSpeed", 1500) * ((mag - 0.15) / 0.85) ** 2 / 60
                    self.virtual.move(int(round(rx / mag * speed)), int(round(ry / mag * speed)))
                lx, ly = p.stick(E.ABS_X, E.ABS_Y)
                if abs(ly) > 0.25:
                    acc_v += -ly * CFG.get("scrollSpeed", 14) / 60
                if abs(lx) > 0.4:
                    acc_h += lx * CFG.get("scrollSpeed", 14) / 60
            if abs(acc_v) >= 1 or abs(acc_h) >= 1:
                self.virtual.scroll(int(acc_v), int(acc_h))
                acc_v -= int(acc_v)
                acc_h -= int(acc_h)

    async def main(self):
        self.loop = asyncio.get_running_loop()
        await asyncio.gather(self.shell.serve(), self.focus.watch(), self.scan(), self.analog())


if __name__ == "__main__":
    try:
        asyncio.run(Daemon().main())
    except KeyboardInterrupt:
        pass
