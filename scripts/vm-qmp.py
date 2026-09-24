#!/usr/bin/env python3
# ~/nixos-config/scripts/vm-qmp.py
"""Drive a headless `nixos-rebuild build-vm` guest over its QMP socket.

Screenshot it, press keys, type text, click. This is what makes the test VMs usable from
an SSH session with no display — see docs/test-vms-and-ci.md, "Driving a test VM
headlessly", for the launch incantation and the gotchas.

Requires python3 only (`nix shell nixpkgs#python3`). No QEMU guest agent, no VNC client,
and nothing installed inside the guest: QMP talks to the *hypervisor*, so it works at the
bootloader, in the display manager and in a desktop session alike.

Usage:
  QMP_SOCK=/path/qmp.sock python3 scripts/vm-qmp.py <command> [args]

  size                    print the guest's current framebuffer size
  status                  print the guest's run state (running / paused / ...)
  shot <file.png>         screenshot the guest framebuffer
  key <combo> [combo...]  press keys; a combo joins qcodes with "-", e.g. meta_l-ret
  type <text>             type a literal string (handles shifted characters)
  click <x> <y>           left-click at guest pixel coordinates
  move <x> <y>            move the pointer without clicking

Coordinates are guest pixels. The screen size is re-read from a throwaway screendump on
every run, so a resolution change — the display manager handing over to the desktop
usually causes one — cannot silently skew your clicks.

Clicking needs an absolute pointing device. The nixos build-vm runner already passes
`-device usb-tablet`; without one, `move`/`click` do nothing useful.
"""

import json
import os
import socket
import struct
import sys
import tempfile
import time

SOCK = os.environ.get("QMP_SOCK", "")

# Characters that need Shift, mapped to the unshifted qcode QEMU knows them by.
SHIFTED = {
    '!': '1', '@': '2', '#': '3', '$': '4', '%': '5', '^': '6', '&': '7', '*': '8',
    '(': '9', ')': '0', '_': 'minus', '+': 'equal', '{': 'bracket_left',
    '}': 'bracket_right', ':': 'semicolon', '"': 'apostrophe', '<': 'comma',
    '>': 'dot', '?': 'slash', '|': 'backslash', '~': 'grave_accent',
}
# Characters whose qcode name differs from the character itself.
NAMED = {
    ' ': 'spc', '-': 'minus', '=': 'equal', '[': 'bracket_left', ']': 'bracket_right',
    ';': 'semicolon', "'": 'apostrophe', ',': 'comma', '.': 'dot', '/': 'slash',
    '\\': 'backslash', '`': 'grave_accent', '\n': 'ret', '\t': 'tab',
}


class QMP:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            self.sock.connect(path)
        except OSError as exc:
            # By far the most common cause: the VM isn't running (or already powered off).
            raise SystemExit("vm-qmp: cannot connect to %s (%s) — is the VM running?"
                             % (path, exc.strerror or exc))
        self.io = self.sock.makefile("rw")
        self.io.readline()                 # server greeting
        self.cmd("qmp_capabilities")
        self._size = None

    def cmd(self, name, **args):
        self.io.write(json.dumps({"execute": name, "arguments": args}) + "\n")
        self.io.flush()
        while True:
            line = self.io.readline()
            if not line:
                raise SystemExit("vm-qmp: QMP connection closed (guest powered off?)")
            msg = json.loads(line)
            if "event" in msg:             # async guest events: ignore
                continue
            if "error" in msg:
                raise SystemExit("vm-qmp: %s" % msg["error"].get("desc", msg["error"]))
            return msg.get("return")

    def shot(self, path):
        """Screendump to path. Prefers PNG; falls back to PPM on older QEMU."""
        path = os.path.abspath(path)
        try:
            self.cmd("screendump", filename=path, format="png")
        except SystemExit:
            self.cmd("screendump", filename=path)
        return path

    def size(self):
        """(width, height) of the current framebuffer, read back from a screendump.

        QMP has no 'how big is the screen' query, so take a throwaway shot and read its
        header. Cached per run — call a fresh vm-qmp.py after a resolution change.
        """
        if self._size:
            return self._size
        fd, tmp = tempfile.mkstemp(suffix=".png")
        os.close(fd)
        try:
            self.shot(tmp)
            with open(tmp, "rb") as fh:
                head = fh.read(64)
            if head.startswith(b"\x89PNG"):
                w, h = struct.unpack(">II", head[16:24])
            elif head.startswith(b"P6"):
                dims = head.split()[1:3]
                w, h = int(dims[0]), int(dims[1])
            else:
                raise SystemExit("vm-qmp: unrecognised screendump format")
            self._size = (w, h)
            return self._size
        finally:
            os.unlink(tmp)

    def keys(self, *combos, settle=0.06):
        for combo in combos:
            self.cmd("send-key", keys=[{"type": "qcode", "data": part}
                                       for part in combo.split("-")])
            time.sleep(settle)

    def type(self, text, settle=0.03):
        for ch in text:
            if ch in SHIFTED:
                codes = ["shift", SHIFTED[ch]]
            elif ch in NAMED:
                codes = [NAMED[ch]]
            elif ch.isupper():
                codes = ["shift", ch.lower()]
            else:
                codes = [ch]
            self.cmd("send-key", keys=[{"type": "qcode", "data": c} for c in codes])
            time.sleep(settle)

    def move(self, x, y):
        # The absolute axes are a fixed 0..32767 range regardless of resolution, so guest
        # pixels have to be scaled against the live framebuffer size.
        w, h = self.size()
        self.cmd("input-send-event", events=[
            {"type": "abs", "data": {"axis": "x", "value": int(x * 32767 / (w - 1))}},
            {"type": "abs", "data": {"axis": "y", "value": int(y * 32767 / (h - 1))}}])

    def click(self, x, y, button="left"):
        self.move(x, y)
        time.sleep(0.15)                   # let the guest process the motion first
        self.cmd("input-send-event",
                 events=[{"type": "btn", "data": {"down": True, "button": button}}])
        time.sleep(0.08)
        self.cmd("input-send-event",
                 events=[{"type": "btn", "data": {"down": False, "button": button}}])


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        sys.exit(__doc__ or "see the header comment in scripts/vm-qmp.py")
    if not SOCK:
        sys.exit("vm-qmp: set QMP_SOCK to the guest's QMP unix socket")

    q = QMP(SOCK)
    op, args = argv[0], argv[1:]

    if op == "size":
        print("%dx%d" % q.size())
    elif op == "status":
        print(q.cmd("query-status").get("status"))
    elif op == "shot":
        print(q.shot(args[0]))
    elif op == "key":
        q.keys(*args)
    elif op == "type":
        q.type(args[0])
    elif op == "click":
        q.click(int(args[0]), int(args[1]))
    elif op == "move":
        q.move(int(args[0]), int(args[1]))
    else:
        sys.exit("vm-qmp: unknown command %r" % op)


if __name__ == "__main__":
    main(sys.argv[1:])
