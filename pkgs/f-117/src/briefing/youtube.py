"""Recent uploads from a YouTube channel.

YouTube's own RSS feeds no longer answer, so this reads the channel's public
"Videos" page and pulls titles and rough upload times out of the data embedded
in it. If YouTube changes that page, this is the file to fix.
"""

import json
import re
import time

import requests

BROWSER_UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/130.0 Safari/537.36"
)
DATA_RE = re.compile(r"var ytInitialData = (\{.*?\});</script>", re.S)
# "7h ago", "3 days ago", "Streamed 2 weeks ago" — but not view counts like "1.4M"
AGO_RE = re.compile(
    r"(?<![\d.])(\d+)\s*(second|sec|s|minute|min|m|hour|hr|h|day|d|week|wk|w|month|mo|year|yr|y)s?\s+ago",
    re.I,
)
UNIT_SECONDS = {
    "second": 1, "sec": 1, "s": 1,
    "minute": 60, "min": 60, "m": 60,
    "hour": 3600, "hr": 3600, "h": 3600,
    "day": 86400, "d": 86400,
    "week": 604800, "wk": 604800, "w": 604800,
    "month": 2592000, "mo": 2592000,
    "year": 31536000, "yr": 31536000, "y": 31536000,
}


def _ago_to_epoch(text, now):
    m = AGO_RE.search(text or "")
    if not m:
        return None
    return int(now - int(m.group(1)) * UNIT_SECONDS[m.group(2).lower()])


def _walk(node, found):
    if isinstance(node, dict):
        if "lockupViewModel" in node:
            found.append(node["lockupViewModel"])
        elif "videoRenderer" in node:
            found.append(node["videoRenderer"])
        for value in node.values():
            _walk(value, found)
    elif isinstance(node, list):
        for value in node:
            _walk(value, found)


def _read(item, now):
    if "videoId" in item:  # older page layout
        title = "".join(r.get("text", "") for r in item.get("title", {}).get("runs", []))
        ago = item.get("publishedTimeText", {}).get("simpleText", "")
        return item["videoId"], title, _ago_to_epoch(ago, now)
    meta = item.get("metadata", {}).get("lockupMetadataViewModel", {})
    title = meta.get("title", {}).get("content", "")
    rows = meta.get("metadata", {}).get("contentMetadataViewModel", {}).get("metadataRows", [])
    parts = [p.get("text", {}).get("content", "") for r in rows for p in r.get("metadataParts", [])]
    published = next((t for t in map(lambda s: _ago_to_epoch(s, now), parts) if t), None)
    return item.get("contentId"), title, published


def fetch_channel(handle, name, limit=15):
    resp = requests.get(
        f"https://www.youtube.com/@{handle}/videos",
        headers={"User-Agent": BROWSER_UA, "Accept-Language": "en-US,en"},
        cookies={"SOCS": "CAI"},  # skip the EU cookie-consent page
        timeout=20,
    )
    resp.raise_for_status()
    match = DATA_RE.search(resp.text)
    if not match:
        raise ValueError("could not find video list on channel page")
    found = []
    _walk(json.loads(match.group(1)), found)

    now = time.time()
    articles, seen = [], set()
    for item in found:
        video_id, title, published = _read(item, now)
        if not video_id or not title or video_id in seen:
            continue
        seen.add(video_id)
        articles.append(
            {
                "key": f"yt:{video_id}",
                "title": title,
                "summary": "",
                "link": f"https://www.youtube.com/watch?v={video_id}",
                "source": name,
                "published": published or int(now),
                "event_at": None,
            }
        )
        if len(articles) >= limit:
            break
    return articles
