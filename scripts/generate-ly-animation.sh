#!/usr/bin/env bash
# ~/nixos-config/scripts/generate-ly-animation.sh
# Convert any MP4/GIF to a Ly .dur animation file.
#
# Runs mp4-to-dur.py inside a nix shell that provides ffmpeg, chafa, and python3.
# Default output: assets/ly/f18-animation.dur (committed to the repo)
#
# Usage:
#   bash scripts/generate-ly-animation.sh [INPUT] [OUTPUT] [extra mp4-to-dur.py flags]
#
#   INPUT  defaults to assets/wallpapers/F18_background.mp4
#   OUTPUT defaults to assets/ly/f18-animation.dur
#
# Examples:
#   bash scripts/generate-ly-animation.sh
#   bash scripts/generate-ly-animation.sh ~/Downloads/radar-scan.gif
#   bash scripts/generate-ly-animation.sh ~/Downloads/radar-scan.gif assets/ly/f18-animation.dur --fps 15

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INPUT="${1:-$REPO_ROOT/assets/wallpapers/F18_background.mp4}"
OUTPUT="${2:-$REPO_ROOT/assets/ly/f18-animation.dur}"
shift 2 2>/dev/null || true   # drop INPUT/OUTPUT; remaining args forwarded

echo "==> Generating Ly animation"
echo "    Input : $INPUT"
echo "    Output: $OUTPUT"
echo ""

exec nix shell nixpkgs#ffmpeg nixpkgs#chafa nixpkgs#python3 \
  --command python3 "$SCRIPT_DIR/mp4-to-dur.py" \
    "$INPUT" "$OUTPUT" \
    --cols 320 --rows 90 \
    "$@"
