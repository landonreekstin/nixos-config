#!/usr/bin/env bash
# ~/nixos-config/scripts/tty-size.sh
# Report the character dimensions of a TTY device.
#
# Usage:
#   tty-size.sh          # checks /dev/tty1 (default)
#   tty-size.sh /dev/tty2

set -euo pipefail

TTY="${1:-/dev/tty1}"

nix shell nixpkgs#python3 --command python3 - "$TTY" << 'EOF'
import fcntl, termios, struct, sys

tty = sys.argv[1]
try:
    with open(tty, 'rb') as f:
        r = fcntl.ioctl(f, termios.TIOCGWINSZ, b'\0' * 8)
    rows, cols, xpix, ypix = struct.unpack('HHHH', r)
    print(f"{cols}x{rows}  ({xpix}x{ypix} pixels)")
except PermissionError:
    print(f"Permission denied on {tty} — try with sudo", file=sys.stderr)
    sys.exit(1)
except FileNotFoundError:
    print(f"Device not found: {tty}", file=sys.stderr)
    sys.exit(1)
EOF
