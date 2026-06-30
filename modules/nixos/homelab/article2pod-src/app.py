# ~/nixos-config/modules/nixos/homelab/article2pod-src/app.py
import os
import json
import logging
import urllib.request
import urllib.error
from datetime import datetime, timezone
from email.utils import format_datetime

from fastapi import FastAPI, HTTPException, Depends, Request
from fastapi.responses import Response
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, HttpUrl

import db
from feedgen.feed import FeedGenerator

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("app")

TOKEN = os.environ["ARTICLE2POD_TOKEN"]
AUDIO_DIR = os.environ.get("ARTICLE2POD_AUDIO", "/mnt/storage/podcasts/audio")
HOSTNAME = os.environ.get("ARTICLE2POD_HOSTNAME", "reader.lan")
TITLE = os.environ.get("ARTICLE2POD_TITLE", "Article Podcast")
AUTHOR = os.environ.get("ARTICLE2POD_AUTHOR", "lando")
DESCRIPTION = os.environ.get("ARTICLE2POD_DESCRIPTION", "Articles converted to audio")
KOKORO_URL = os.environ.get("KOKORO_URL", "http://localhost:8880")
KOKORO_VOICE = os.environ.get("KOKORO_VOICE", "af_heart")

BASE_URL = f"http://{HOSTNAME}"

app = FastAPI(title="article2pod", docs_url=None, redoc_url=None)
security = HTTPBearer(auto_error=False)

db.init_db()


def _verify(credentials: HTTPAuthorizationCredentials | None = Depends(security)):
    if credentials is None or credentials.credentials != TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return credentials.credentials


class AddRequest(BaseModel):
    url: HttpUrl


class SettingsRequest(BaseModel):
    voice: str


_UI_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>article2pod</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         background: #0d1117; color: #c9d1d9; margin: 0; padding: 1.5em; }
  h1 { color: #58a6ff; margin: 0 0 0.2em; font-size: 1.5em; }
  .subtitle { color: #8b949e; font-size: 0.9em; margin-bottom: 1.8em; }
  h2 { font-size: 0.8em; color: #8b949e; text-transform: uppercase; letter-spacing: 0.1em;
       margin: 1.8em 0 0.75em; border-bottom: 1px solid #21262d; padding-bottom: 0.4em; }
  table { width: 100%; border-collapse: collapse; font-size: 0.88em; }
  th { text-align: left; color: #8b949e; font-weight: 500; padding: 0.5em 0.75em;
       border-bottom: 1px solid #21262d; }
  td { padding: 0.65em 0.75em; border-bottom: 1px solid #161b22; vertical-align: top; }
  tr:last-child td { border-bottom: none; }
  .badge { display: inline-block; padding: 0.15em 0.55em; border-radius: 1em;
           font-size: 0.78em; font-weight: 600; }
  .badge-done       { background: #0d4429; color: #3fb950; }
  .badge-processing { background: #3d2b00; color: #e3b341; }
  .badge-queued     { background: #0c2d6b; color: #58a6ff; }
  .badge-failed     { background: #3d0000; color: #f85149; }
  .title-link { color: #c9d1d9; text-decoration: none; font-weight: 500; }
  .title-link:hover { color: #58a6ff; }
  .url-text { color: #8b949e; font-size: 0.82em; white-space: nowrap; overflow: hidden;
              text-overflow: ellipsis; max-width: 420px; display: block; }
  .info-cell { color: #8b949e; font-size: 0.85em; white-space: nowrap; }
  .spin { display: inline-block; animation: spin 1.2s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .voice-row { display: flex; gap: 0.75em; align-items: center; flex-wrap: wrap;
               margin-bottom: 0.5em; }
  select { background: #161b22; color: #c9d1d9; border: 1px solid #30363d;
           padding: 0.4em 0.6em; border-radius: 6px; font-size: 0.9em; min-width: 220px; }
  button { background: #238636; color: #fff; border: none; padding: 0.4em 1.1em;
           border-radius: 6px; cursor: pointer; font-size: 0.88em; }
  button:hover { background: #2ea043; }
  .note { color: #6e7681; font-size: 0.82em; }
  .toast { position: fixed; bottom: 1.5em; right: 1.5em; background: #1f6feb; color: #fff;
           padding: 0.6em 1.2em; border-radius: 8px; font-size: 0.88em;
           opacity: 0; transition: opacity 0.3s; pointer-events: none; }
  .toast.show { opacity: 1; }
  .error-text { color: #f85149; font-size: 0.82em; }
</style>
</head>
<body>
<h1>article2pod</h1>
<div class="subtitle" id="counts">Loading…</div>

<h2>Queue</h2>
<table>
  <thead><tr><th>Status</th><th>Article</th><th>Info</th></tr></thead>
  <tbody id="queue-body"><tr><td colspan="3" style="color:#8b949e">Loading…</td></tr></tbody>
</table>

<h2>Voice</h2>
<div class="voice-row">
  <select id="voice-select"><option>Loading…</option></select>
  <button onclick="saveVoice()">Save</button>
</div>
<p class="note">Takes effect on the next article. Does not affect articles currently processing.</p>

<div class="toast" id="toast"></div>

<script>
const TOKEN = "__TOKEN__";
const hdrs = {"Authorization": "Bearer " + TOKEN};

function fmtDuration(s) {
  if (!s) return "";
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return h > 0 ? h + "h " + m + "m" : m + "m";
}
function fmtDate(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  return d.toLocaleDateString(undefined, {month:"short", day:"numeric"}) + " " +
         d.toLocaleTimeString(undefined, {hour:"2-digit", minute:"2-digit"});
}
function badge(status) {
  return '<span class="badge badge-' + status + '">' + status + '</span>';
}

async function load() {
  const rows = await fetch("/status", {headers: hdrs}).then(r => r.json());
  const counts = {};
  rows.forEach(r => counts[r.status] = (counts[r.status] || 0) + 1);
  document.getElementById("counts").textContent =
    Object.entries(counts).map(([k,v]) => v + " " + k).join(" · ") || "No articles yet";

  const tbody = document.getElementById("queue-body");
  if (!rows.length) {
    tbody.innerHTML = '<tr><td colspan="3" style="color:#8b949e">No articles yet.</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(r => {
    const title = r.title && r.title !== "Untitled" ? r.title : "Untitled";
    let info = fmtDate(r.added_at);
    if (r.status === "done") {
      info = fmtDuration(r.duration) +
             (r.size_bytes ? " · " + (r.size_bytes/1048576).toFixed(1) + " MB" : "");
    } else if (r.status === "processing") {
      info = '<span class="spin">↻</span> since ' + fmtDate(r.added_at);
    } else if (r.status === "failed") {
      info = '<span class="error-text" title="' + (r.error || "") + '">Error (hover)</span>';
    }
    return '<tr>' +
      '<td>' + badge(r.status) + '</td>' +
      '<td><a class="title-link" href="' + r.url + '" target="_blank">' + title + '</a>' +
          '<span class="url-text">' + r.url + '</span></td>' +
      '<td class="info-cell">' + info + '</td>' +
      '</tr>';
  }).join("");
}

async function loadVoices() {
  const [vr, sr] = await Promise.all([
    fetch("/voices", {headers: hdrs}).then(r => r.json()),
    fetch("/settings", {headers: hdrs}).then(r => r.json()),
  ]);
  const current = sr.voice;
  const groups = {};
  const labels = {
    af:"American Female", am:"American Male",
    bf:"British Female",  bm:"British Male",
    ef:"Spanish Female",  em:"Spanish Male",
    ff:"French Female",
    hf:"Hindi Female",    hm:"Hindi Male",
    "if":"Italian Female",im:"Italian Male",
    jf:"Japanese Female", jm:"Japanese Male",
    pf:"Portuguese Female",pm:"Portuguese Male",
    zf:"Chinese Female",  zm:"Chinese Male",
  };
  vr.voices.forEach(v => {
    const p = v.id.slice(0, 2);
    if (!groups[p]) groups[p] = [];
    groups[p].push(v);
  });
  const sel = document.getElementById("voice-select");
  sel.innerHTML = Object.entries(groups).map(([p, vs]) => {
    const opts = vs.map(v =>
      '<option value="' + v.id + '"' + (v.id === current ? ' selected' : '') + '>' + v.id + '</option>'
    ).join("");
    return '<optgroup label="' + (labels[p] || p) + '">' + opts + '</optgroup>';
  }).join("");
}

async function saveVoice() {
  const voice = document.getElementById("voice-select").value;
  await fetch("/settings", {
    method: "POST", headers: {...hdrs, "Content-Type": "application/json"},
    body: JSON.stringify({voice}),
  });
  showToast("Voice set to " + voice);
}

function showToast(msg) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  setTimeout(() => t.classList.remove("show"), 3000);
}

load();
loadVoices();
setInterval(load, 10000);
</script>
</body>
</html>"""


@app.get("/ui/{token}")
def ui(token: str):
    if token != TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")
    return Response(content=_UI_TEMPLATE.replace("__TOKEN__", TOKEN), media_type="text/html")


@app.get("/voices")
def list_voices(_token: str = Depends(_verify)):
    try:
        req = urllib.request.Request(f"{KOKORO_URL}/v1/audio/voices")
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Could not reach TTS backend: {e}")


@app.get("/settings")
def get_settings(_token: str = Depends(_verify)):
    return {"voice": db.get_setting("voice", KOKORO_VOICE)}


@app.post("/settings")
def update_settings(req: SettingsRequest, _token: str = Depends(_verify)):
    db.set_setting("voice", req.voice)
    log.info("Voice changed to %s", req.voice)
    return {"voice": req.voice}


@app.post("/add")
def add_url(req: AddRequest, _token: str = Depends(_verify)):
    url = str(req.url)
    result = db.enqueue(url)
    if result is None:
        return {"status": "duplicate", "message": "URL already in queue"}
    log.info("Enqueued: %s", url)
    return {"status": "queued", "guid": result["guid"]}


@app.get("/status")
def status(_token: str = Depends(_verify)):
    rows = db.get_all()
    return [dict(r) for r in rows]


@app.get("/rss/{token}")
def get_feed(token: str):
    if token != TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")

    episodes = db.get_done()

    fg = FeedGenerator()
    fg.load_extension("podcast")
    fg.id(f"{BASE_URL}/rss/{token}")
    fg.title(TITLE)
    fg.author({"name": AUTHOR})
    fg.link(href=f"{BASE_URL}/rss/{token}", rel="self")
    fg.description(DESCRIPTION)
    fg.language("en")
    fg.podcast.itunes_author(AUTHOR)
    fg.podcast.itunes_summary(DESCRIPTION)
    fg.podcast.itunes_explicit("no")

    for ep in episodes:
        audio_url = f"{BASE_URL}/audio/{ep['guid']}.mp3"
        fe = fg.add_entry(order="append")
        fe.id(ep["guid"])
        fe.title(ep["title"] or "Untitled")
        fe.description(f"<p>{ep['title']}</p><p>Source: {ep['url']}</p>")
        fe.enclosure(audio_url, str(ep["size_bytes"] or 0), "audio/mpeg")
        fe.podcast.itunes_author(ep["author"] or AUTHOR)
        if ep["duration"]:
            fe.podcast.itunes_duration(ep["duration"])
        pub = ep["processed_at"] or ep["added_at"] or ""
        if pub:
            try:
                dt = datetime.fromisoformat(pub.replace("Z", "+00:00"))
                fe.pubDate(dt)
            except ValueError:
                pass

    rss_bytes = fg.rss_str(pretty=True)
    return Response(content=rss_bytes, media_type="application/rss+xml")


@app.get("/")
def root():
    rows = db.get_all()
    counts = {}
    for r in rows:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    return {
        "service": "article2pod",
        "endpoints": {
            "ui":     f"GET  /ui/<token>",
            "add":    "POST /add  {\"url\":\"...\"}  (Authorization: Bearer <token>)",
            "feed":   f"GET  /rss/<token>",
            "status": "GET  /status  (Authorization: Bearer <token>)",
            "health": "GET  /health",
        },
        "queue": counts,
    }


@app.get("/submit")
def submit_url(url: str, token: str):
    if token != TOKEN:
        raise HTTPException(status_code=403, detail="Forbidden")
    result = db.enqueue(url)
    if result is None:
        msg, color = "Already queued or processed.", "#e6a817"
    else:
        log.info("Enqueued via /submit: %s", url)
        msg, color = "Queued! Check AntennaPod in ~20-30 min.", "#4caf50"
    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>article2pod</title>
<style>
  body {{ font-family: sans-serif; text-align: center; padding: 3em;
         background: #111; color: #eee; }}
  h2 {{ color: {color}; }}
  p {{ color: #aaa; word-break: break-all; font-size: 0.9em; }}
  small {{ color: #555; }}
</style></head><body>
<h2>{msg}</h2>
<p>{url}</p>
<small>This tab will close in 3 seconds.</small>
<script>setTimeout(() => window.close(), 3000);</script>
</body></html>"""
    return Response(content=html, media_type="text/html")


@app.get("/health")
def health():
    try:
        db.init_db()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))
