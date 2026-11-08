# ~/nixos-config/modules/nixos/hardware/case-rgb.nix
# Pure Nix file — import with: import ./case-rgb.nix { inherit pkgs; }
# Returns the `case-rgb` CLI, which drives the case fans on gaming-pc's B650 GAMING X AX V2
# D_LED1 header through its Gigabyte RGB Fusion 2 chip (ITE 048d:5702, IT5701).
#
# Protocol: 64-byte HID feature reports, report ID 0xCC. Reverse-engineered from Gigabyte
# Control Center's RgbMotherboard.dll (MCU_8297) and proven on hardware. Notes and evidence
# live in ~/reverse-engineering/gigabyte-rgb (notes/01-protocol.md, 00-handoff.md).
#
# The one thing that matters: `CC 32 00` turns the D-LED strips' direct (per-LED frame) mode
# OFF before an effect is written. OpenRGB's init sends `CC 32 1b` (direct mode ON for every
# strip) and never streams frames for them, so the fans freeze on their last frame and ignore
# every effect packet until a reboot. That is why OpenRGB must not run alongside this.
#
# The board re-initialises the chip at every boot (back to its rainbow), and `CC 5E` (save)
# does not survive that, so the saved state is re-applied at login by a user service.
# Each apply blanks the other effect slots too (see apply()), so this assumes the fans are
# the only lighting on the board's RGB headers.
#
# State lives in ~/.cache/case-rgb-state as `colourIndex:brightness:effect`, the same shape
# as the keyboard's ~/.cache/ckb-color-state plus the effect. The palette must match
# modules/home-manager/hyprland/desktops/century-series/ckb-scripts.nix.
{ pkgs }:

pkgs.writers.writePython3Bin "case-rgb" { flakeIgnore = [ "E501" ]; } ''
  """case-rgb: case fan lighting on the B650's D_LED1 header (RGB Fusion 2, 048d:5702).

  usage: case-rgb apply [--wait SECONDS]   send the saved state to the fans
         case-rgb cycle-color              next palette colour, then apply
         case-rgb cycle-effect             next effect, then apply
         case-rgb bright up|down           brightness +/-10, then apply
         case-rgb set-color INDEX          select palette INDEX (0-3), then apply
         case-rgb set INDEX BRIGHTNESS     set colour and brightness (link with the keyboard)
         case-rgb get                      print the state: index brightness effect
         case-rgb pulse-daemon             animate PULSE (run by the case-rgb-pulse user service)
  """
  import fcntl
  import glob
  import math
  import os
  import struct
  import sys
  import time

  # 0=RADAR green, 1=AMBER, 2=RED, 3=MIG turquoise. Same order as ckb-scripts.nix.
  COLORS = [0x39FF14, 0xFF7A1A, 0xCC0000, 0x00C8B4]
  EFFECTS = ["stdy", "pulse"]
  DEFAULT = (0, 80, "stdy")
  STATE = os.path.join(
      os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
      "case-rgb-state",
  )

  REPORT_ID = 0xCC
  LEN = 64
  HIDIOCSFEATURE = (3 << 30) | (LEN << 16) | (ord("H") << 8) | 0x06
  DIV = 5  # D_LED1. Effect command is 0x20 + div, zone mask 1 << div.


  def read_state():
      try:
          with open(STATE) as f:
              idx, bright, effect = f.read().strip().split(":")
          idx, bright = int(idx), int(bright)
          if 0 <= idx < len(COLORS) and 0 <= bright <= 100 and effect in EFFECTS:
              return idx, bright, effect
      except (OSError, ValueError):
          pass
      return DEFAULT


  def write_state(idx, bright, effect):
      os.makedirs(os.path.dirname(STATE), exist_ok=True)
      tmp = STATE + ".new"
      with open(tmp, "w") as f:
          f.write(f"{idx}:{bright}:{effect}\n")
      os.replace(tmp, STATE)


  def find_dev():
      for p in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
          try:
              with open(p + "/device/uevent") as f:
                  if "HID_ID=0003:0000048D:00005702" in f.read():
                      return "/dev/" + os.path.basename(p)
          except OSError:
              continue
      return None


  def send(fd, payload):
      buf = bytearray(LEN)
      buf[:len(payload)] = payload
      fcntl.ioctl(fd, HIDIOCSFEATURE, bytes(buf))


  def scaled(rgb, bright):
      r, g, b = (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF
      return ((r * bright // 100) << 16) | ((g * bright // 100) << 8) | (b * bright // 100)


  def static_packet(rgb):
      # struct DataFormat_8297: u32 zone_sel0, u32 zone_sel1, u8 reserved, u8 mode,
      # u8 max_bri, u8 min_bri, u32 colour0 (0x00RRGGBB LE), u32 colour1,
      # u16 time0..time3, u8 ctrl0, ctrl1, oem0, oem1  (32 bytes). Mode 1 = static.
      #
      # PULSE is NOT the chip's own pulse (mode 2). On this firmware that one
      # ignores colour0: with CtrlVal0 = 0 (what GCC sends) D_LED1 stays dark,
      # and with CtrlVal0 = 1 it breathes in a built-in red whatever colour is
      # asked for (webcam, 2026-11-07). So pulse-daemon animates the brightness
      # of a static colour instead, which keeps the theme colour.
      body = struct.pack("<IIBBBBIIHHHHBBBB", 1 << DIV, 0, 0, 1, 0xFF, 0x00,
                         rgb, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      return bytes([REPORT_ID, 0x20 + DIV]) + body


  def apply(wait=0):
      idx, bright, effect = read_state()
      dev = find_dev()
      deadline = time.monotonic() + wait
      while dev is None and time.monotonic() < deadline:
          time.sleep(1)
          dev = find_dev()
      if dev is None:
          print("case-rgb: RGB controller 048d:5702 not found", file=sys.stderr)
          return 1
      fd = os.open(dev, os.O_RDWR)
      try:
          send(fd, [REPORT_ID, 0x32, 0x00])        # D-LED direct mode off (see header)
          send(fd, [REPORT_ID, 0x34, 0x00, 0x00])  # strip length: 32-LED class
          # From a cold boot the board's rainbow sits in the other effect slots
          # (0x20 doubles as the all-zones slot) and wins over a D_LED1-only
          # apply: verified 2026-11-07, `CC 28 20` alone left the rainbow
          # running. So blank every other slot and apply them all together,
          # as OpenRGB's init does. Other RGB headers on the board go dark.
          for slot in range(8):
              if slot != DIV:
                  send(fd, [REPORT_ID, 0x20 + slot])
          send(fd, static_packet(scaled(COLORS[idx], bright)))
          send(fd, [REPORT_ID, 0x28, 0xFF])        # apply all slots
      finally:
          os.close(fd)
      return 0


  PULSE_PERIOD = 2.6  # seconds per breath, about the chip's own pulse
  PULSE_FPS = 20


  def pulse_daemon():
      """Breathe the saved colour while the effect is PULSE; idle otherwise.

      Sends only the D_LED1 effect + a D_LED1 apply per frame: the login
      service's full apply has already cleared the cold-boot rainbow.
      """
      fd = None
      was_pulsing = False
      while True:
          idx, bright, effect = read_state()
          if effect != "pulse":
              if was_pulsing:
                  apply()  # land on the steady colour, not a mid-breath frame
                  was_pulsing = False
              time.sleep(0.5)
              continue
          if fd is None:
              dev = find_dev()
              if dev is None:
                  time.sleep(2)
                  continue
              try:
                  fd = os.open(dev, os.O_RDWR)
              except OSError:
                  time.sleep(2)
                  continue
          if not was_pulsing:
              apply()
              was_pulsing = True
          phase = (time.monotonic() % PULSE_PERIOD) / PULSE_PERIOD
          level = (1 - math.cos(2 * math.pi * phase)) / 2  # 0 -> 1 -> 0, smooth
          try:
              send(fd, static_packet(scaled(COLORS[idx], round(bright * level))))
              send(fd, [REPORT_ID, 0x28, 1 << DIV])
          except OSError:
              os.close(fd)
              fd = None  # device went away (replug, resume); find it again
          time.sleep(1 / PULSE_FPS)


  def main(argv):
      if not argv:
          sys.exit(__doc__)
      cmd = argv[0]
      idx, bright, effect = read_state()
      if cmd == "get":
          print(idx, bright, effect)
          return 0
      if cmd == "pulse-daemon":
          pulse_daemon()
          return 0
      if cmd == "apply":
          wait = int(argv[2]) if len(argv) > 2 and argv[1] == "--wait" else 0
          return apply(wait)
      if cmd == "cycle-color":
          idx = (idx + 1) % len(COLORS)
      elif cmd == "cycle-effect":
          effect = EFFECTS[(EFFECTS.index(effect) + 1) % len(EFFECTS)]
      elif cmd == "bright" and len(argv) > 1 and argv[1] in ("up", "down"):
          bright = min(100, bright + 10) if argv[1] == "up" else max(0, bright - 10)
      elif cmd == "set-color" and len(argv) > 1 and argv[1].isdigit() and int(argv[1]) < len(COLORS):
          idx = int(argv[1])
      elif cmd == "set" and len(argv) > 2 and argv[1].isdigit() and argv[2].isdigit() and int(argv[1]) < len(COLORS) and int(argv[2]) <= 100:
          idx, bright = int(argv[1]), int(argv[2])
      else:
          sys.exit(__doc__)
      write_state(idx, bright, effect)
      return apply()


  if __name__ == "__main__":
      sys.exit(main(sys.argv[1:]))
''
