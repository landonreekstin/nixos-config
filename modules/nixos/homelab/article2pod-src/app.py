# ~/nixos-config/modules/nixos/homelab/article2pod-src/app.py
import os
import logging
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


@app.get("/health")
def health():
    try:
        db.init_db()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))
