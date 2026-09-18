#!/usr/bin/env python3
"""Pull an iOS camera roll over USB and reconstruct a browsable gallery.

Subcommands (``all`` runs the whole pipeline, which is what the `photos` command does):

    pull      copy the device's media partition into the archive (resumable)
    index     read the archive + Photos.sqlite, write the index (creates nothing)
    build     hardlink the organized trees
    convert   HEIC -> JPEG
    gallery   thumbnails + static HTML
    all       every stage above, in order

The archive is only ever appended to; the organized trees are hardlinks into it, so
they cost no extra disk. Nothing is written to or deleted from the phone.

Tool paths come from the environment (the Nix module supplies absolute store paths);
each falls back to a bare name on PATH so the script stays runnable by hand.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone

# Apple's reference date is 2001-01-01 UTC, not the Unix epoch.
APPLE_EPOCH = 978307200

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".gif", ".bmp", ".tiff"}
VIDEO_EXT = {".mov", ".mp4", ".m4v", ".avi"}
AUDIO_EXT = {".m4a", ".wav", ".mp3"}
MEDIA_EXT = IMAGE_EXT | VIDEO_EXT | AUDIO_EXT

# The camera roll plus voice memos and any iTunes-synced albums. The rest of
# PhotoData/ is a regenerable thumbnail cache that can run to gigabytes, but
# Photos.sqlite is the only record of album membership, so it comes along.
MEDIA_SUBDIRS = ["DCIM", "Photos", "Recordings"]

THUMB = 400


def tool(env, default):
    return os.environ.get(env, default)


IFUSE = tool("IOS_IFUSE", "ifuse")
RSYNC = tool("IOS_RSYNC", "rsync")
EXIFTOOL = tool("IOS_EXIFTOOL", "exiftool")
FFMPEG = tool("IOS_FFMPEG", "ffmpeg")
MAGICK = tool("IOS_MAGICK", "magick")
IDEVICE_ID = tool("IOS_IDEVICE_ID", "idevice_id")
IDEVICEPAIR = tool("IOS_IDEVICEPAIR", "idevicepair")
IDEVICEINFO = tool("IOS_IDEVICEINFO", "ideviceinfo")
FUSERMOUNT = tool("IOS_FUSERMOUNT", "fusermount")


def say(*a):
    print(*a, flush=True)


def run(cmd, **kw):
    kw.setdefault("capture_output", True)
    kw.setdefault("text", True)
    return subprocess.run(cmd, **kw)


# --------------------------------------------------------------------- device --

def device_info():
    """Return (udid, name, ios) for the attached device, or exit with advice."""
    out = run([IDEVICE_ID, "-l"]).stdout.strip()
    if not out:
        say("No iPhone or iPad found.")
        say("")
        say("  1. Plug it into this computer with a cable.")
        say("  2. Unlock the screen.")
        say("  3. If it asks 'Trust This Computer?', tap Trust.")
        sys.exit(1)
    udid = out.splitlines()[0].strip()

    if run([IDEVICEPAIR, "validate"]).returncode != 0:
        say("Pairing with the device...")
        if run([IDEVICEPAIR, "pair"]).returncode != 0:
            say("")
            say("The device refused to pair. Unlock it, tap Trust on its screen,")
            say("then run this again. (If no prompt appears, unplug and replug it.)")
            sys.exit(1)

    name = run([IDEVICEINFO, "-k", "DeviceName"]).stdout.strip() or "iPhone"
    ios = run([IDEVICEINFO, "-k", "ProductVersion"]).stdout.strip() or "?"
    return udid, name, ios


def device_slug(name, udid):
    s = re.sub(r"[^\w-]+", "-", name.strip().lower()).strip("-")
    return s or ("device-" + udid[:8])


# ----------------------------------------------------------------------- pull --

def is_mounted(path):
    try:
        with open("/proc/self/mounts") as f:
            return any(line.split()[1] == path.replace(" ", r"\040")
                       or line.split()[1] == path for line in f)
    except OSError:
        return False


def do_pull(args):
    _, name, ios = device_info()
    label = args.device or device_slug(name, "")
    say(f"Connected: {name} (iOS {ios})")

    dest = os.path.join(args.archive, label, "media")
    os.makedirs(dest, exist_ok=True)
    mnt = os.path.join(args.archive, ".mount")
    os.makedirs(mnt, exist_ok=True)

    # Plain ifuse (no --documents) mounts com.apple.afc, the media partition at
    # /var/mobile/Media -- that is where the Photos app actually keeps things.
    if not is_mounted(mnt):
        r = run([IFUSE, mnt])
        if r.returncode != 0:
            say("Could not open the phone's photo storage:")
            say("  " + (r.stderr or "").strip())
            sys.exit(1)
    try:
        say("")
        say("Copying photos and videos off the phone.")
        say("(Safe to interrupt -- running it again picks up where it left off.)")
        for sub in MEDIA_SUBDIRS:
            src = os.path.join(mnt, sub)
            if not os.path.isdir(src):
                continue
            say(f"  {sub}...")
            run([RSYNC, "-rt", "--partial", "--human-readable",
                 "--info=progress2", src + "/", os.path.join(dest, sub) + "/"],
                capture_output=False)
        pd = os.path.join(mnt, "PhotoData")
        if os.path.isdir(pd):
            os.makedirs(os.path.join(dest, "PhotoData"), exist_ok=True)
            run([RSYNC, "-rt", "--partial", "--include=Photos.sqlite*",
                 "--include=AlbumsMetadata/***", "--exclude=*",
                 pd + "/", os.path.join(dest, "PhotoData") + "/"])
        n = sum(len(f) for _, _, f in os.walk(dest))
        say(f"  copied -- {n} files now in the backup")
    finally:
        if is_mounted(mnt):
            run([FUSERMOUNT, "-u", mnt])
        try:
            os.rmdir(mnt)
        except OSError:
            pass


# ------------------------------------------------------------------ db schema --
# The databases span a decade of iOS and disagree on nearly every name: the asset
# table is ZGENERICASSET on older builds and ZASSET on newer ones, and the album
# join table is numbered differently on every device -- its own columns carry
# different numbers again (Z_23ASSETS holds Z_23ALBUMS and Z_30ASSETS). Nothing
# here can be hardcoded; it is all discovered at runtime.

def table_names(con):
    return {r[0] for r in con.execute(
        "select name from sqlite_master where type='table'")}


def columns(con, table):
    return [r[1] for r in con.execute(f"pragma table_info({table})")]


def find_asset_table(tables):
    for cand in ("ZASSET", "ZGENERICASSET"):
        if cand in tables:
            return cand
    return None


def find_album_join(con, tables):
    for t in sorted(tables):
        if not re.fullmatch(r"Z_\d+ASSETS", t):
            continue
        cols = columns(con, t)
        album_col = next((c for c in cols if c.endswith("ALBUMS")), None)
        asset_col = next((c for c in cols if c.endswith("ASSETS")), None)
        if album_col and asset_col:
            return t, album_col, asset_col
    return None


def apple_time(v):
    if v is None:
        return None
    try:
        ts = float(v) + APPLE_EPOCH
        if not (946684800 < ts < 2524608000):  # 2000..2050 sanity window
            return None
        return datetime.fromtimestamp(ts, tz=timezone.utc)
    except (TypeError, ValueError, OSError):
        return None


def read_db(archive, device):
    db = os.path.join(archive, device, "media", "PhotoData", "Photos.sqlite")
    if not os.path.exists(db):
        return {}, []
    # immutable=1: sqlite will not create -wal/-shm or write a single byte.
    con = sqlite3.connect(f"file:{db}?immutable=1", uri=True)
    con.text_factory = lambda b: b.decode("utf-8", "replace")
    try:
        tables = table_names(con)
        atab = find_asset_table(tables)
        if not atab:
            return {}, []
        acols = set(columns(con, atab))
        sel = [c for c in ("Z_PK", "ZFILENAME", "ZDIRECTORY", "ZDATECREATED",
                           "ZTRASHEDSTATE") if c in acols]
        if "ZFILENAME" not in sel:
            return {}, []

        by_pk, assets = {}, {}
        for row in con.execute(f"select {','.join(sel)} from {atab}"):
            rec = dict(zip(sel, row))
            fn = rec.get("ZFILENAME")
            if not fn:
                continue
            dt = apple_time(rec.get("ZDATECREATED"))
            info = {
                "date": dt.isoformat() if dt else None,
                "trashed": bool(rec.get("ZTRASHEDSTATE") or 0),
                "albums": [],
            }
            assets[((rec.get("ZDIRECTORY") or "").strip("/"), fn)] = info
            if "Z_PK" in rec:
                by_pk[rec["Z_PK"]] = info

        albums = []
        join = find_album_join(con, tables)
        if join and "ZGENERICALBUM" in tables and by_pk:
            jt, acol, ascol = join
            if "ZTITLE" in set(columns(con, "ZGENERICALBUM")):
                for pk, title in con.execute(
                        "select Z_PK, ZTITLE from ZGENERICALBUM "
                        "where ZTITLE is not null"):
                    title = (title or "").strip()
                    if not title:
                        continue
                    n = 0
                    for (m,) in con.execute(
                            f"select {ascol} from {jt} where {acol}=?", (pk,)):
                        info = by_pk.get(m)
                        if info is not None:
                            info["albums"].append(title)
                            n += 1
                    # Databases carry dangling album references with no asset rows
                    # and no files on disk; only count albums that resolved.
                    if n:
                        albums.append({"title": title, "count": n})
        return assets, albums
    finally:
        con.close()


# ---------------------------------------------------------------- index/build --

def devices(archive):
    if not os.path.isdir(archive):
        return []
    return sorted(d for d in os.listdir(archive)
                  if os.path.isdir(os.path.join(archive, d, "media")))


def exif_date(path):
    try:
        out = run([EXIFTOOL, "-s3", "-d", "%Y-%m-%dT%H:%M:%S",
                   "-DateTimeOriginal", "-CreateDate", "-MediaCreateDate",
                   path], timeout=25).stdout.strip()
        for line in out.splitlines():
            line = line.strip()
            if line and not line.startswith("0000"):
                return line
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def file_hash(path):
    h = hashlib.md5()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    except OSError:
        return None
    return h.hexdigest()


def src_path(archive, e):
    return os.path.join(archive, e["device"], "media", e["rel"])


def do_index(args):
    entries = []
    for dev in devices(args.archive):
        assets, albums = read_db(args.archive, dev)
        media = os.path.join(args.archive, dev, "media")
        n0 = len(entries)
        for root, dirnames, files in os.walk(media):
            dirnames[:] = [d for d in dirnames if d != "PhotoData"]
            for fn in files:
                ext = os.path.splitext(fn)[1].lower()
                if ext not in MEDIA_EXT:
                    continue
                full = os.path.join(root, fn)
                rel = os.path.relpath(full, media)
                info = assets.get((os.path.dirname(rel), fn), {})
                date = info.get("date")
                if not date:
                    date = exif_date(full) or datetime.fromtimestamp(
                        os.path.getmtime(full), tz=timezone.utc).isoformat()
                entries.append({
                    "device": dev, "rel": rel, "name": fn, "ext": ext,
                    "kind": ("image" if ext in IMAGE_EXT
                             else "video" if ext in VIDEO_EXT else "audio"),
                    "date": date, "size": os.path.getsize(full),
                    "trashed": info.get("trashed", False),
                    "albums": info.get("albums", []),
                })
        say(f"  {dev}: {len(entries) - n0} files, {len(albums)} albums")

    # Hash only same-size candidates -- cheap, and enough to find real duplicates.
    bysize = defaultdict(list)
    for e in entries:
        bysize[e["size"]].append(e)
    for group in bysize.values():
        if len(group) > 1:
            for e in group:
                e["md5"] = file_hash(src_path(args.archive, e))

    json.dump(entries, open(args.index, "w"), indent=0)
    say(f"  {len(entries)} photos and videos catalogued")


def slug(s):
    s = re.sub(r"[^\w\s.-]", "", s, flags=re.UNICODE).strip()
    return re.sub(r"\s+", " ", s) or "untitled"


def link(src, dst):
    """Hardlink src -> dst, uniquifying on collision. Never copies, never moves."""
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.exists(dst):
        if os.path.samefile(src, dst):
            return dst
        stem, ext = os.path.splitext(dst)
        n = 2
        while os.path.exists(f"{stem}_{n}{ext}"):
            if os.path.samefile(src, f"{stem}_{n}{ext}"):
                return f"{stem}_{n}{ext}"
            n += 1
        dst = f"{stem}_{n}{ext}"
    try:
        os.link(src, dst)
    except OSError:
        return None
    return dst


def do_build(args):
    entries = json.load(open(args.index))
    seen, counts = {}, defaultdict(int)
    for e in entries:
        src = src_path(args.archive, e)
        if not os.path.exists(src):
            continue
        dev, name, out = e["device"], e["name"], args.gallery
        year, ym = e["date"][:4], e["date"][:7]

        d = link(src, os.path.join(out, "by-device", dev, e["rel"]))
        if d:
            counts["by-device"] += 1
            e["out"] = os.path.relpath(d, out)

        if e["trashed"]:
            link(src, os.path.join(out, "deleted", dev, name))
            counts["deleted"] += 1
            continue

        h = e.get("md5")
        if h and h in seen:
            counts["duplicates skipped"] += 1
        else:
            if h:
                seen[h] = True
            if link(src, os.path.join(out, "by-date", year, ym, f"{dev}__{name}")):
                counts["by-date"] += 1
        for a in e["albums"]:
            if link(src, os.path.join(out, "by-album", f"{dev} - {slug(a)}", name)):
                counts["by-album"] += 1

    json.dump(entries, open(args.index, "w"), indent=0)
    for k in sorted(counts):
        say(f"  {k}: {counts[k]}")


def do_convert(args):
    entries = json.load(open(args.index))
    todo = [e for e in entries if e["ext"] in (".heic", ".heif")]
    if not todo:
        return
    say(f"  converting {len(todo)} HEIC photos to JPEG")
    ok = 0
    for e in todo:
        # Mirror the source folder: iOS reuses filenames across DCIM directories
        # (IMG_5835.HEIC exists in both 115APPLE and 125APPLE as *different*
        # photos), so keying on the basename alone silently overwrites one.
        dst = os.path.join(args.gallery, "jpeg", e["device"],
                           os.path.dirname(e["rel"]).replace("DCIM/", ""),
                           os.path.splitext(e["name"])[0] + ".jpg")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            ok += 1
            continue
        if run([MAGICK, src_path(args.archive, e), "-auto-orient",
                "-quality", "92", dst]).returncode == 0 and os.path.exists(dst):
            ok += 1
    say(f"  {ok}/{len(todo)} converted")


# ------------------------------------------------------------------- gallery --

CSS = """
:root{--bg:#faf9f7;--fg:#1c1b19;--mut:#6b6864;--card:#fff;--line:#e5e1db;--accent:#b4532a}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){
 --bg:#171614;--fg:#ece9e4;--mut:#9a958d;--card:#201f1c;--line:#302e2a;--accent:#e08a5f}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
 font:15px/1.5 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif}
header{padding:28px 24px 8px;max-width:1400px;margin:0 auto}
h1{margin:0 0 4px;font-size:26px;letter-spacing:-.02em}
.sub{color:var(--mut);font-size:14px}
main{max-width:1400px;margin:0 auto;padding:16px 24px 60px}
a{color:inherit;text-decoration:none}
.nav{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0 26px}
.nav a{padding:6px 12px;border:1px solid var(--line);border-radius:999px;
 background:var(--card);font-size:13px}
.nav a:hover{border-color:var(--accent);color:var(--accent)}
.sec{margin:34px 0 10px;font-size:13px;text-transform:uppercase;
 letter-spacing:.09em;color:var(--mut)}
.grid{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}
.cell{position:relative;aspect-ratio:1;border-radius:9px;overflow:hidden;
 background:var(--card);border:1px solid var(--line);display:block}
.cell img{width:100%;height:100%;object-fit:cover;display:block}
.cell:hover{border-color:var(--accent)}
.badge{position:absolute;left:6px;bottom:6px;background:rgba(0,0,0,.72);color:#fff;
 font-size:10px;padding:2px 6px;border-radius:5px;letter-spacing:.04em}
.miss{display:flex;align-items:center;justify-content:center;height:100%;
 color:var(--mut);font-size:11px;text-align:center;padding:8px;word-break:break-all}
.cards{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(230px,1fr))}
.card{border:1px solid var(--line);border-radius:11px;overflow:hidden;background:var(--card)}
.card:hover{border-color:var(--accent)}
.card .ct{padding:10px 12px}.card .cn{font-weight:600;font-size:14px}
.card .cc{color:var(--mut);font-size:12px;margin-top:2px}
.card img{width:100%;height:118px;object-fit:cover;display:block}
"""


def page(title, sub, nav, body):
    return (f'<!doctype html><html><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f"<title>{title}</title><style>{CSS}</style></head><body>"
            f'<header><h1>{title}</h1><div class="sub">{sub}</div></header>'
            f'<main><div class="nav">{nav}</div>{body}</main></body></html>')


def thumb_for(archive, e, tdir):
    key = hashlib.md5((e["device"] + "/" + e["rel"]).encode()).hexdigest()[:16]
    dst = os.path.join(tdir, key + ".jpg")
    if os.path.exists(dst):
        return key + ".jpg"
    src = src_path(archive, e)
    geom = (f"scale={THUMB}:{THUMB}:force_original_aspect_ratio=increase,"
            f"crop={THUMB}:{THUMB}")
    try:
        if e["kind"] == "image":
            run([MAGICK, src + "[0]", "-auto-orient",
                 "-thumbnail", f"{THUMB}x{THUMB}^", "-gravity", "center",
                 "-extent", f"{THUMB}x{THUMB}", "-quality", "82", dst], timeout=120)
        elif e["kind"] == "video":
            r = run([FFMPEG, "-y", "-loglevel", "error", "-ss", "1", "-i", src,
                     "-frames:v", "1", "-vf", geom, dst], timeout=180)
            if r.returncode != 0 or not os.path.exists(dst):
                # Very short clips have no frame at 1s -- retry from the start.
                run([FFMPEG, "-y", "-loglevel", "error", "-i", src,
                     "-frames:v", "1", "-vf", geom, dst], timeout=180)
        else:
            return None  # audio has no thumbnail, and that is not an error
    except (OSError, subprocess.SubprocessError):
        return None
    return key + ".jpg" if os.path.exists(dst) else None


def cells(items, prefix):
    out = []
    for e in items:
        t = e.get("thumb")
        inner = (f'<img loading="lazy" src="thumbs/{t}" alt="">' if t
                 else f'<div class="miss">{e["name"]}</div>')
        badge = ""
        if e["kind"] == "video":
            badge = '<span class="badge">VIDEO</span>'
        elif e["kind"] == "audio":
            badge = '<span class="badge">AUDIO</span>'
        elif e["ext"] in (".heic", ".heif"):
            badge = '<span class="badge">HEIC</span>'
        href = prefix + e.get("out", "").replace(os.sep, "/")
        out.append(f'<a class="cell" href="{href}">{inner}{badge}</a>')
    return '<div class="grid">' + "".join(out) + "</div>"


def do_gallery(args):
    entries = json.load(open(args.index))
    gdir = os.path.join(args.gallery, "gallery")
    tdir = os.path.join(gdir, "thumbs")
    os.makedirs(tdir, exist_ok=True)

    live = [e for e in entries if not e["trashed"] and e.get("out")]
    todo = [e for e in live if not os.path.exists(
        os.path.join(tdir, hashlib.md5(
            (e["device"] + "/" + e["rel"]).encode()).hexdigest()[:16] + ".jpg"))]
    if todo:
        say(f"  making {len(todo)} thumbnails -- this is the slow part, "
            f"please leave it running")
    t0 = time.time()
    for i, e in enumerate(live, 1):
        e["thumb"] = thumb_for(args.archive, e, tdir)
        if todo and i % 200 == 0:
            say(f"    {i}/{len(live)}  ({int(time.time() - t0)}s elapsed)")

    live.sort(key=lambda x: x["date"])
    by_year, by_album = defaultdict(list), defaultdict(list)
    for e in live:
        by_year[e["date"][:4]].append(e)
        for a in e["albums"]:
            by_album[f'{e["device"]} - {slug(a)}'].append(e)

    nav = ('<a href="index.html">Overview</a>'
           + "".join(f'<a href="year-{y}.html">{y}</a>' for y in sorted(by_year))
           + "".join(f'<a href="album-{slug(a)}.html">{a}</a>'
                     for a in sorted(by_album)))

    for y, items in by_year.items():
        body, bym = "", defaultdict(list)
        for e in items:
            bym[e["date"][:7]].append(e)
        for m in sorted(bym):
            label = datetime.strptime(m, "%Y-%m").strftime("%B %Y")
            body += f'<div class="sec">{label} &mdash; {len(bym[m])}</div>'
            body += cells(bym[m], "../")
        open(os.path.join(gdir, f"year-{y}.html"), "w").write(
            page(y, f"{len(items)} items", nav, body))

    for a, items in by_album.items():
        open(os.path.join(gdir, f"album-{slug(a)}.html"), "w").write(
            page(a, f"{len(items)} items", nav,
                 cells(sorted(items, key=lambda x: x["date"]), "../")))

    def cover(items):
        return next((e["thumb"] for e in items if e.get("thumb")), None)

    def card(href, nm, n, cv):
        img = f'<img loading="lazy" src="thumbs/{cv}" alt="">' if cv else ""
        return (f'<a class="card" href="{href}">{img}<div class="ct">'
                f'<div class="cn">{nm}</div><div class="cc">{n} items</div></div></a>')

    body = '<div class="sec">Years</div><div class="cards">'
    for y in sorted(by_year, reverse=True):
        body += card(f"year-{y}.html", y, len(by_year[y]), cover(by_year[y]))
    body += '</div><div class="sec">Albums</div><div class="cards">'
    for a in sorted(by_album, key=lambda k: -len(by_album[k])):
        body += card(f"album-{slug(a)}.html", a, len(by_album[a]), cover(by_album[a]))
    body += "</div>"

    nimg = sum(1 for e in live if e["kind"] == "image")
    nvid = sum(1 for e in live if e["kind"] == "video")
    ndev = len({e["device"] for e in live})
    open(os.path.join(gdir, "index.html"), "w").write(page(
        "My Photos",
        f"{len(live)} items &mdash; {nimg} photos, {nvid} videos &mdash; "
        f"{len(by_album)} albums, {ndev} device(s)",
        nav, body))
    json.dump(entries, open(args.index, "w"), indent=0)
    return os.path.join(gdir, "index.html")


# ----------------------------------------------------------------------- main --

def do_all(args):
    do_pull(args)
    say("")
    say("Sorting them by date and album...")
    do_index(args)
    do_build(args)
    do_convert(args)
    say("")
    say("Building your gallery...")
    index_html = do_gallery(args)
    say("")
    say("Done. Your photos are at:")
    say(f"  {args.gallery}")
    browser = os.environ.get("IOS_BROWSER", "").strip()
    if browser and not args.no_open:
        say("")
        say("Opening the gallery...")
        subprocess.Popen(browser.split() + [index_html],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        say(f"  open this file in a browser: {index_html}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("command", choices=["pull", "index", "build", "convert",
                                       "gallery", "all"], nargs="?", default="all")
    p.add_argument("--archive", required=True)
    p.add_argument("--gallery", required=True)
    p.add_argument("--index")
    p.add_argument("--device", help="label for this device (default: its name)")
    p.add_argument("--no-open", action="store_true")
    args = p.parse_args()
    if not args.index:
        args.index = os.path.join(args.archive, ".photo-index.json")
    os.makedirs(args.archive, exist_ok=True)
    os.makedirs(args.gallery, exist_ok=True)

    # build/convert/gallery consume the index; pull/index/all create it.
    if args.command in ("build", "convert", "gallery") \
            and not os.path.exists(args.index):
        sys.exit(f"no index yet -- run 'index' first (looked for {args.index})")

    {"pull": do_pull, "index": do_index, "build": do_build,
     "convert": do_convert, "gallery": do_gallery, "all": do_all}[args.command](args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        say("\nStopped. Nothing was lost -- run it again to carry on.")
        sys.exit(130)
