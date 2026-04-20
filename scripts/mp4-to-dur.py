#!/usr/bin/env python3
# ~/nixos-config/scripts/mp4-to-dur.py
# Convert an MP4 (or GIF/video) to a Ly display manager .dur animation file.
#
# Usage:
#   python3 mp4-to-dur.py <input.mp4> <output.dur> [--fps 10] [--cols 160] [--rows 45]
#
# Requirements: ffmpeg, chafa (available via `nix shell nixpkgs#ffmpeg nixpkgs#chafa`)
# Or run via: scripts/generate-ly-animation.sh

import argparse
import gzip
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_COLS = 160
DEFAULT_ROWS = 45
DEFAULT_FPS = 10


def extract_frames(mp4_path: str, output_dir: str, fps: int, cols: int, rows: int) -> list:
    """Extract frames from video, scaled to fit terminal dimensions."""
    # Scale pixel dimensions: each terminal cell is ~8x16 px (standard console font ratio)
    pixel_w = cols * 8
    pixel_h = rows * 16

    cmd = [
        "ffmpeg", "-i", mp4_path,
        "-vf", f"fps={fps},scale={pixel_w}:{pixel_h}:flags=lanczos",
        "-f", "image2",
        os.path.join(output_dir, "frame_%04d.png"),
        "-y", "-loglevel", "error",
    ]
    subprocess.run(cmd, check=True)

    frames = sorted(Path(output_dir).glob("frame_*.png"))
    return [str(f) for f in frames]


def frame_to_ansi(frame_path: str, cols: int, rows: int) -> str:
    """Convert a single frame image to ANSI 256-color text art using chafa."""
    cmd = [
        "chafa",
        "--colors=256",
        f"--size={cols}x{rows}",
        "--format=ansi",
        "--color-extractor=average",
        "--color-space=din99d",
        "--optimize=5",
        frame_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return result.stdout


def rgb_to_256(r: int, g: int, b: int) -> int:
    """Convert an RGB triplet to the nearest xterm 256-color palette index."""
    if r == g == b:
        if r < 8:
            return 16
        if r > 248:
            return 231
        return round((r - 8) / 247 * 24) + 232
    r_i = round(r / 255 * 5)
    g_i = round(g / 255 * 5)
    b_i = round(b / 255 * 5)
    return 16 + 36 * r_i + 6 * g_i + b_i


def parse_ansi_frame(ansi_text: str, cols: int, rows: int):
    """
    Parse ANSI SGR-colored terminal art into the .dur frame data structures.

    Returns:
        content   — list of `rows` strings, each `cols` chars wide
        color_map — list indexed as color_map[col][row] = [fg_idx, bg_idx]
                    (column-first, matching the durdraw .dur format spec)
    """
    content = [[" "] * cols for _ in range(rows)]
    # color_map[x][y]: x=column (0..cols-1), y=row (0..rows-1)
    color_map = [[[7, 0] for _ in range(rows)] for _ in range(cols)]

    lines = ansi_text.rstrip("\n").split("\n")

    for row_idx, line in enumerate(lines[:rows]):
        fg = 7   # default: white
        bg = 0   # default: black
        col_idx = 0
        i = 0

        while i < len(line) and col_idx < cols:
            if line[i] == "\x1b" and i + 1 < len(line) and line[i + 1] == "[":
                # Find end of CSI sequence
                j = i + 2
                while j < len(line) and line[j] not in "mABCDHfJKSTnRu@":
                    j += 1

                if j < len(line) and line[j] == "m":
                    params_str = line[i + 2:j]
                    params = params_str.split(";") if params_str else ["0"]
                    k = 0
                    while k < len(params):
                        try:
                            code = int(params[k]) if params[k] else 0
                        except ValueError:
                            k += 1
                            continue

                        if code == 0:
                            fg, bg = 7, 0
                        elif 30 <= code <= 37:
                            fg = code - 30
                        elif code == 39:
                            fg = 7
                        elif 40 <= code <= 47:
                            bg = code - 40
                        elif code == 49:
                            bg = 0
                        elif 90 <= code <= 97:
                            fg = code - 90 + 8
                        elif 100 <= code <= 107:
                            bg = code - 100 + 8
                        elif code == 38 and k + 1 < len(params):
                            sel = int(params[k + 1]) if params[k + 1] else 0
                            if sel == 5 and k + 2 < len(params):
                                fg = int(params[k + 2]) & 0xFF
                                k += 2
                            elif sel == 2 and k + 4 < len(params):
                                fg = rgb_to_256(int(params[k+2]), int(params[k+3]), int(params[k+4]))
                                k += 4
                        elif code == 48 and k + 1 < len(params):
                            sel = int(params[k + 1]) if params[k + 1] else 0
                            if sel == 5 and k + 2 < len(params):
                                bg = int(params[k + 2]) & 0xFF
                                k += 2
                            elif sel == 2 and k + 4 < len(params):
                                bg = rgb_to_256(int(params[k+2]), int(params[k+3]), int(params[k+4]))
                                k += 4
                        k += 1

                i = j + 1
            else:
                content[row_idx][col_idx] = line[i]
                color_map[col_idx][row_idx] = [fg, bg]
                col_idx += 1
                i += 1

    content_strings = ["".join(row) for row in content]
    return content_strings, color_map


def build_dur_bytes(frames_data: list, cols: int, rows: int, fps: int, name: str) -> bytes:
    """Build a gzip-compressed .dur JSON blob from parsed frame data."""
    dur_frames = []
    for i, (content, color_map) in enumerate(frames_data, 1):
        dur_frames.append({
            "frameNumber": i,
            "delay": round(1.0 / fps, 6),
            "contents": content,
            "colorMap": color_map,
        })

    dur_data = {
        "DurMovie": {
            "formatVersion": 7,
            "colorFormat": "256",
            "encoding": "utf-8",
            "name": name,
            "artist": "nixos-config",
            "framerate": float(fps),
            "columns": cols,
            "lines": rows,
            "preferredFont": "fixed",
            "extra": None,
            "frames": dur_frames,
        }
    }

    json_bytes = json.dumps(dur_data, separators=(",", ":")).encode("utf-8")
    return gzip.compress(json_bytes, compresslevel=9)


def main():
    parser = argparse.ArgumentParser(
        description="Convert an MP4/GIF to a Ly display manager .dur animation file"
    )
    parser.add_argument("input", help="Input video file (MP4, GIF, etc.)")
    parser.add_argument("output", help="Output .dur file path")
    parser.add_argument("--fps",  type=int, default=DEFAULT_FPS,  help=f"Frames per second (default: {DEFAULT_FPS})")
    parser.add_argument("--cols", type=int, default=DEFAULT_COLS, help=f"Terminal columns (default: {DEFAULT_COLS})")
    parser.add_argument("--rows", type=int, default=DEFAULT_ROWS, help=f"Terminal rows (default: {DEFAULT_ROWS})")
    parser.add_argument("--name", default="f18-animation", help="Animation name stored in the .dur file")
    args = parser.parse_args()

    print(f"Input : {args.input}")
    print(f"Output: {args.output}")
    print(f"Size  : {args.cols}x{args.rows} chars @ {args.fps} FPS")

    with tempfile.TemporaryDirectory() as tmpdir:
        print("\nExtracting frames with ffmpeg...")
        frame_paths = extract_frames(args.input, tmpdir, args.fps, args.cols, args.rows)
        total = len(frame_paths)
        print(f"  {total} frames extracted")

        print("Converting frames to ANSI art with chafa...")
        frames_data = []
        for i, fp in enumerate(frame_paths):
            sys.stdout.write(f"\r  Frame {i+1}/{total} ({(i+1)*100//total}%)")
            sys.stdout.flush()
            ansi = frame_to_ansi(fp, args.cols, args.rows)
            content, color_map = parse_ansi_frame(ansi, args.cols, args.rows)
            frames_data.append((content, color_map))
        print(f"\r  {total}/{total} frames converted.     ")

        print("Assembling and compressing .dur file...")
        dur_bytes = build_dur_bytes(frames_data, args.cols, args.rows, args.fps, args.name)

        Path(args.output).parent.mkdir(parents=True, exist_ok=True)
        Path(args.output).write_bytes(dur_bytes)

        size_kb = len(dur_bytes) / 1024
        print(f"Done! Written {args.output} ({size_kb:.0f} KB, {total} frames)")


if __name__ == "__main__":
    main()
