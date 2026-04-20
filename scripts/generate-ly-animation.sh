#!/usr/bin/env bash
# ~/nixos-config/scripts/generate-ly-animation.sh
# Regenerate the Ly login-screen animation from the F-18 wallpaper MP4.
#
# Runs mp4-to-dur.py inside a nix shell that provides ffmpeg, chafa, and python3.
# Output: assets/ly/f18-animation.dur (committed to the repo)
#
# Usage:
#   bash scripts/generate-ly-animation.sh
#   bash scripts/generate-ly-animation.sh --fps 8 --cols 140 --rows 40

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INPUT="$REPO_ROOT/assets/wallpapers/F18_background.mp4"
OUTPUT="$REPO_ROOT/assets/ly/f18-animation.dur"

echo "==> Generating Ly animation from F-18 MP4"
echo "    Input : $INPUT"
echo "    Output: $OUTPUT"
echo ""

exec nix shell nixpkgs#ffmpeg nixpkgs#chafa nixpkgs#python3 \
  --command python3 "$SCRIPT_DIR/mp4-to-dur.py" \
    "$INPUT" "$OUTPUT" \
    --name "f18-century-series" \
    "$@"
