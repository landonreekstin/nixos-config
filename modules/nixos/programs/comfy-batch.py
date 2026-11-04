"""comfy-batch: run one image-edit prompt over every image under a directory.

Each result is saved next to its source as <name><suffix>.png. Files that already
have a result are skipped, so a run can be resumed. Results themselves are never fed
back in: anything ComfyUI generated carries a "prompt" PNG text chunk, whatever its name.

The workflow is an API-format JSON in ComfyUI's saved workflows (on the private share),
fetched over ComfyUI's API, so no model name lives in this script. It needs:
  - one LoadImage node            (the source image)
  - one node whose title contains "positive" with a `prompt` or `text` input
  - one SaveImage node            (swapped for PreviewImage, so results go to the
                                   RAM-only temp area and are only written next to
                                   the input)
Uploads also go to ComfyUI's temp area, so nothing else is kept.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}


def made_by_comfyui(path):
    """True for PNGs ComfyUI generated: they carry a "prompt" text chunk before the pixels.
    So earlier results are never fed back in, whatever suffix they were saved with."""
    if not path.lower().endswith(".png"):
        return False
    try:
        with open(path, "rb") as f:
            if f.read(8) != b"\x89PNG\r\n\x1a\n":
                return False
            while True:
                head = f.read(8)
                if len(head) < 8:
                    return False
                length, kind = int.from_bytes(head[:4], "big"), head[4:]
                if kind == b"IDAT" or kind == b"IEND":
                    return False
                data = f.read(length)
                f.read(4)  # CRC
                if kind in (b"tEXt", b"iTXt", b"zTXt") and data.split(b"\0", 1)[0] == b"prompt":
                    return True
    except OSError:
        return False


def api(base, path, data=None, headers=None):
    req = urllib.request.Request(base + path, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def upload(base, path):
    boundary = uuid.uuid4().hex
    name = uuid.uuid4().hex + os.path.splitext(path)[1].lower()
    with open(path, "rb") as f:
        content = f.read()
    parts = []
    for key, val in (("type", "temp"), ("subfolder", "comfy-batch"), ("overwrite", "true")):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{val}\r\n'.encode())
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\n'
        f"Content-Type: application/octet-stream\r\n\r\n".encode() + content + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    res = json.loads(api(base, "/upload/image", b"".join(parts),
                         {"Content-Type": f"multipart/form-data; boundary={boundary}"}))
    sub = res.get("subfolder", "")
    return (f"{sub}/" if sub else "") + res["name"] + " [temp]"


def prepare(workflow, image_ref, prompt):
    wf = json.loads(json.dumps(workflow))
    loads = [n for n in wf.values() if n.get("class_type") == "LoadImage"]
    pos = [n for n in wf.values() if "positive" in n.get("_meta", {}).get("title", "").lower()]
    saves = [k for k, n in wf.items() if n.get("class_type") == "SaveImage"]
    if len(loads) != 1 or len(pos) != 1 or len(saves) != 1:
        sys.exit("comfy-batch: workflow needs exactly one LoadImage, one 'positive' prompt node and one SaveImage")
    loads[0]["inputs"]["image"] = image_ref
    key = "prompt" if "prompt" in pos[0]["inputs"] else "text"
    pos[0]["inputs"][key] = prompt
    for k in saves:
        wf[k] = {"class_type": "PreviewImage", "inputs": {"images": wf[k]["inputs"]["images"]}}
    return wf


def run_one(base, workflow, src, prompt):
    wf = prepare(workflow, upload(base, src), prompt)
    body = json.dumps({"prompt": wf, "client_id": "comfy-batch"}).encode()
    try:
        pid = json.loads(api(base, "/prompt", body, {"Content-Type": "application/json"}))["prompt_id"]
    except urllib.error.HTTPError as e:
        raise RuntimeError(e.read().decode(errors="replace")[:400])
    while True:
        time.sleep(2)
        hist = json.loads(api(base, f"/history/{pid}")).get(pid)
        if not hist:
            continue
        status = hist.get("status", {})
        if status.get("status_str") == "error":
            msgs = [m[1].get("exception_message", "") for m in status.get("messages", []) if m[0] == "execution_error"]
            raise RuntimeError("; ".join(msgs) or "execution error")
        if status.get("completed"):
            break
    for out in hist["outputs"].values():
        for img in out.get("images", []):
            q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""),
                                        "type": img.get("type", "temp")})
            return api(base, f"/view?{q}")
    raise RuntimeError("no image in the result")


def main():
    p = argparse.ArgumentParser(description="Run one image-edit prompt over every image under DIR (recursively); "
                                            "each result is saved beside its source as <name>SUFFIX.png.")
    p.add_argument("dir", nargs="?", help="starting directory")
    p.add_argument("prompt", nargs="?", help="the edit to make, e.g. \"make it night\"")
    p.add_argument("--workflow", default="batch-edit",
                   help="saved ComfyUI workflow (API format) to use (default: batch-edit)")
    p.add_argument("--suffix", default="_edited", help="added to each output name (default: _edited)")
    p.add_argument("--list", action="store_true", help="list the saved workflows and exit")
    p.add_argument("--url", default=os.environ.get("COMFY_URL", "http://127.0.0.1:8188"))
    a = p.parse_args()
    base = a.url.rstrip("/")

    try:
        names = json.loads(api(base, "/api/userdata?dir=workflows"))
    except (urllib.error.URLError, OSError):
        sys.exit(f"comfy-batch: ComfyUI isn't reachable at {base}. Start it with: comfy-start")
    if a.list:
        print("\n".join(sorted(n[:-5] for n in names if n.endswith(".json"))))
        return
    if not a.dir or not a.prompt:
        p.error("DIR and PROMPT are required")
    if not os.path.isdir(a.dir):
        sys.exit(f"comfy-batch: not a directory: {a.dir}")
    wname = a.workflow if a.workflow.endswith(".json") else a.workflow + ".json"
    try:
        workflow = json.loads(api(base, "/api/userdata/" + urllib.parse.quote("workflows/" + wname, safe="")))
    except urllib.error.HTTPError:
        sys.exit(f"comfy-batch: no saved workflow '{a.workflow}'. See: comfy-batch --list")
    prepare(workflow, "x", "x")  # validate the workflow before starting

    # Only names are looked at here (no file is opened), so this stays quick on a network
    # share. Whether a PNG is itself a ComfyUI result is checked when its turn comes.
    print(f"Scanning {a.dir} ...", flush=True)
    todo = []
    for root, dirs, files in os.walk(a.dir):
        dirs.sort()
        names = set(files)
        for f in sorted(files):
            stem, ext = os.path.splitext(f)
            if ext.lower() not in EXTS or stem.endswith(a.suffix):
                continue
            if stem + a.suffix + ".png" not in names:
                todo.append((os.path.join(root, f), os.path.join(root, stem + a.suffix + ".png")))
    if not todo:
        print("Nothing to do: no images without a result.")
        return

    print(f"{len(todo)} image(s), workflow '{a.workflow}'. Ctrl+C to stop; rerun to resume.")
    ok = failed = skipped = 0
    for i, (src, dst) in enumerate(todo, 1):
        print(f"[{i}/{len(todo)}] {src}", end=" ... ", flush=True)
        if made_by_comfyui(src):
            skipped += 1
            print("skipped (a ComfyUI result)")
            continue
        t = time.time()
        try:
            data = run_one(base, workflow, src, a.prompt)
            with open(dst + ".part", "wb") as f:
                f.write(data)
            os.replace(dst + ".part", dst)
            ok += 1
            print(f"done ({time.time() - t:.0f}s)")
        except Exception as e:  # keep going with the rest
            failed += 1
            print(f"FAILED: {e}")
    print(f"Finished: {ok} saved, {failed} failed" + (f", {skipped} skipped (ComfyUI results)." if skipped else "."))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("\nStopped. Rerun the same command to continue where it left off.")
