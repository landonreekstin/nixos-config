"""Download and read RSS / Atom news feeds."""

import html
import html.entities
import re
import string
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

import requests

from .youtube import BROWSER_UA, fetch_channel

# Some sites (KnifeNews) refuse anything that doesn't look like a browser.
USER_AGENT = BROWSER_UA
# Reddit is the opposite: it wants an honest app name, and very few requests
# ("429 Too Many Requests" otherwise), so all subreddits go in one combined request.
REDDIT_UA = "linux:briefing-room:v1.0 (personal news reader)"
SUBREDDIT_RE = re.compile(r"reddit\.com/r/([^/]+)/", re.I)
REDDIT_REST = 3600  # after Reddit refuses, leave it alone this long
_reddit_rest_until = [0.0]
REDDIT_FOOTER_RE = re.compile(r"\s*submitted by /u/.*$")
EVENT_DATE_RE = re.compile(r"([A-Z][a-z]+ \d{1,2}, \d{4})")
EVENT_TIME_RE = re.compile(r"(\d{1,2}:\d{2} [AP]M)")
TAG_RE = re.compile(r"<[^>]+>")
ENTITY_RE = re.compile(rb"&([A-Za-z][A-Za-z0-9]*);")
XML_ENTITIES = {b"amp", b"lt", b"gt", b"quot", b"apos"}


def clean(text):
    """Turn feed HTML into plain, single-spaced text."""
    if not text:
        return ""
    text = html.unescape(text)
    text = TAG_RE.sub(" ", text)
    text = html.unescape(text)
    return " ".join(text.split())


def parse_date(value):
    if not value:
        return None
    value = value.strip()
    try:
        dt = parsedate_to_datetime(value)
    except (TypeError, ValueError):
        try:
            dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp())


def parse_event_time(dates, times):
    """CivicPlus calendars give 'October 25, 2026' and '11:00 AM - 11:59 PM'.
    Returns the start as a local-time epoch, or None."""
    m = EVENT_DATE_RE.search(dates or "")
    if not m:
        return None
    t = EVENT_TIME_RE.search(times or "")
    try:
        if t:
            dt = datetime.strptime(f"{m.group(1)} {t.group(1)}", "%B %d, %Y %I:%M %p")
        else:
            dt = datetime.strptime(m.group(1), "%B %d, %Y")
    except ValueError:
        return None
    return int(dt.timestamp())


def _matches(title, words):
    title = f" {title.lower()} "
    return any(w.lower() in title for w in words)


def _local(tag):
    return tag.rsplit("}", 1)[-1]


def _children(el):
    """First child element of each name, namespaces dropped."""
    found = {}
    for child in el:
        found.setdefault(_local(child.tag), child)
    return found


def _fix_entity(match):
    name = match.group(1)
    if name in XML_ENTITIES:
        return match.group(0)
    code = html.entities.name2codepoint.get(name.decode())
    return f"&#{code};".encode() if code else b""


def parse_xml(content):
    """Parse a feed, forgiving the usual faults (stray leading blank lines,
    HTML entities such as &nbsp; that XML does not know)."""
    content = content.lstrip()
    try:
        return ET.fromstring(content)
    except ET.ParseError:
        return ET.fromstring(ENTITY_RE.sub(_fix_entity, content))


IMG_RE = re.compile(r"""<img[^>]+src=["']([^"']+)["']""", re.I)


def feed_image(el, raw):
    """The picture a feed item sends along (media:thumbnail / media:content /
    an image enclosure / the first <img> in its text), or None."""
    for child in el.iter():
        tag, url = _local(child.tag), child.get("url") or child.get("href")
        if not url or not url.startswith("http"):
            continue
        kind = (child.get("type") or "") + (child.get("medium") or "")
        if tag == "thumbnail" or (tag in ("content", "enclosure", "link") and "image" in kind):
            return url
    m = IMG_RE.search(raw or "")
    return html.unescape(m.group(1)) if m and m.group(1).startswith("http") else None


def parse_feed(content, source_name, min_words=1, include=(), exclude=()):
    root = parse_xml(content)
    now = int(time.time())
    articles = []
    for el in root.iter():
        if _local(el.tag) not in ("item", "entry"):
            continue
        kids = _children(el)

        def text(*names):
            for name in names:
                if name in kids and (kids[name].text or "").strip():
                    return kids[name].text
            return ""

        title = clean(text("title"))
        if not title:
            continue

        link = text("link").strip()
        if not link:
            for child in el:
                if _local(child.tag) == "link" and child.get("rel", "alternate") == "alternate":
                    link = child.get("href", "")
                    break

        source = source_name
        if "source" in kids and (kids["source"].text or "").strip():
            # Aggregated feeds (Google News) name the real publisher per item.
            source = clean(kids["source"].text)
            suffix = f" - {source}"
            if title.endswith(suffix):
                title = title[: -len(suffix)].strip()
            source = source.removesuffix(" (.gov)")
        title = title.removeprefix("Pages - ")
        if len(title.split()) < min_words:
            continue  # index pages like "Press Releases" rather than real announcements
        if include and not _matches(title, include):
            continue
        if exclude and _matches(title, exclude):
            continue

        raw = text("description", "summary", "encoded", "content")
        desc = clean(raw)
        desc = REDDIT_FOOTER_RE.sub("", desc)
        if desc.startswith("Article URL:"):
            desc = ""  # Hacker News: just links, no description
        if desc.startswith(title[:40]) and len(desc) < len(title) + 80:
            desc = ""  # feed just repeats the headline
        if len(desc) > 500:
            desc = desc[:500].rsplit(" ", 1)[0] + "…"

        published = parse_date(text("pubDate", "published", "updated", "date"))
        if not published or published > now + 3600:
            published = now

        event_at = parse_event_time(text("EventDates"), text("EventTimes"))
        if event_at:
            where = clean(text("Location"))
            desc = f"{clean(text('EventTimes'))} · {where}".strip(" ·") if where else clean(text("EventTimes"))

        articles.append(
            {
                "image": feed_image(el, raw),
                "key": text("guid", "id").strip() or link or title,
                "title": title,
                "summary": desc,
                "link": link,
                "source": source,
                "published": published,
                "event_at": event_at,
            }
        )
    return articles


def _get(url):
    agent = REDDIT_UA if "reddit.com" in url else USER_AGENT
    return requests.get(url, headers={"User-Agent": agent}, timeout=20)


def fetch_reddit(subs):
    """One request for several subreddits; returns {subreddit (lowercase): articles}."""
    if time.time() < _reddit_rest_until[0]:
        raise RuntimeError("Reddit asked us to slow down; trying again later")
    url = f"https://www.reddit.com/r/{'+'.join(subs)}/new/.rss?limit=100"
    resp = _get(url)
    if resp.status_code in (429, 500, 503):
        _reddit_rest_until[0] = time.time() + REDDIT_REST
    resp.raise_for_status()
    by_sub = {s.lower(): [] for s in subs}
    for a in parse_feed(resp.content, "reddit"):
        m = SUBREDDIT_RE.search(a["link"])
        if m and m.group(1).lower() in by_sub:
            a["source"] = f"r/{m.group(1)}"
            by_sub[m.group(1).lower()].append(a)
    return by_sub


WIKI_UA = {"User-Agent": "BriefingRoom/1.0 (personal news reader)"}
WIKI_SKIP = ("surname", "given name", "disambiguation", "topics referred to", "list of", "index of")
_context_cache = {}


def who_is(term):
    """A short 'who/what is this' from Wikipedia for a trending search, e.g.
    ('Tristan da Silva', 'German basketball player (born 2001)', 'Tristan da Silva is a ...').
    Returns None when Wikipedia has nothing that clearly matches."""
    key = term.lower()
    if key in _context_cache:
        return _context_cache[key]
    found = None
    try:
        r = requests.get(
            "https://en.wikipedia.org/w/rest.php/v1/search/page",
            params={"q": term, "limit": 3}, headers=WIKI_UA, timeout=10,
        )
        words = {w for w in re.findall(r"[a-z0-9]+", key) if len(w) > 2}
        for page in r.json().get("pages", []):
            desc = page.get("description") or ""
            title = page.get("title", "")
            if any(skip in desc.lower() for skip in WIKI_SKIP):
                continue
            if not words & set(re.findall(r"[a-z0-9]+", title.lower())):
                continue
            s = requests.get(
                "https://en.wikipedia.org/api/rest_v1/page/summary/" + requests.utils.quote(page["key"]),
                headers=WIKI_UA, timeout=10,
            ).json()
            first = re.split(r"(?<=[.!?])\s+", s.get("extract", ""), maxsplit=1)[0]
            found = (title, desc, first[:260])
            break
    except (requests.RequestException, ValueError):
        return None  # try again next sync
    _context_cache[key] = found
    return found


PERSON_RE = re.compile(
    r"\(born \d{4}\)|\b(actor|actress|singer|rapper|musician|player|footballer|athlete|politician|"
    r"businessman|businesswoman|entrepreneur|influencer|streamer|youtuber|comedian|director|"
    r"journalist|author|model|coach|wrestler|fighter|boxer|personality|activist|executive)\b",
    re.I,
)


def is_person(description):
    return bool(PERSON_RE.search(description or ""))


def fetch_trends(source):
    """Google Trends' daily trending searches: each search term, roughly how many
    people searched it, and the news story that explains why."""
    resp = _get(source["url"])
    resp.raise_for_status()
    root = parse_xml(resp.content)
    out = []
    for item in root.iter("item"):
        kids = _children(item)
        term = clean(kids["title"].text if "title" in kids else "")
        if not term:
            continue
        traffic = clean(kids["approx_traffic"].text) if "approx_traffic" in kids else ""
        # Google sometimes pairs a search with an unrelated story, so only use a
        # story that mentions one of the search words.
        words = {w for w in re.findall(r"[a-z0-9]+", term.lower()) if len(w) > 2}
        story, link, outlet = "", "", ""
        for news in (c for c in item if _local(c.tag) == "news_item"):
            n = _children(news)
            title = clean(n["news_item_title"].text) if "news_item_title" in n else ""
            if words & set(re.findall(r"[a-z0-9]+", title.lower())):
                story = title
                link = (n["news_item_url"].text or "").strip() if "news_item_url" in n else ""
                outlet = clean(n["news_item_source"].text) if "news_item_source" in n else ""
                break
        published = parse_date(kids["pubDate"].text if "pubDate" in kids else "") or int(time.time())
        why = f"Why now: {story} ({outlet})" if outlet and story else (f"Why now: {story}" if story else "")
        who = who_is(term)
        if who:
            name, desc, first = who
            preface = f"{desc[:1].upper() + desc[1:]}." if desc else first
            if first and desc and len(first) < 200:
                preface = first
            summary = f"{preface} {why}".strip()
            title = name if len(name) <= len(term) + 12 else string.capwords(term)
        else:
            summary, title, desc = why, string.capwords(term), ""
        out.append(
            {
                "key": f"trend:{term.lower()}:{time.strftime('%Y%m%d', time.localtime(published))}",
                "title": title,
                "summary": summary,
                "person": is_person(desc),
                "link": link or f"https://www.google.com/search?q={requests.utils.quote(term)}",
                "source": f"{traffic} searches" if traffic else "Google Trends",
                "published": published,
                "event_at": None,
            }
        )
    return out


def fetch_wikipedia(source, count=15):
    """English Wikipedia's most-read articles for the latest full day."""
    day = time.localtime(time.time() - 86400)
    url = f"https://api.wikimedia.org/feed/v1/wikipedia/en/featured/{time.strftime('%Y/%m/%d', day)}"
    resp = requests.get(url, headers={"User-Agent": REDDIT_UA}, timeout=20)
    resp.raise_for_status()
    most = resp.json().get("mostread", {})
    noon = int(time.mktime(time.strptime(time.strftime("%Y-%m-%d 12:00", day), "%Y-%m-%d %H:%M")))
    out = []
    skip = ("Main Page", "Special:", "Wikipedia:", "Deaths in ")
    for rank, a in enumerate(most.get("articles", [])):
        title = a.get("normalizedtitle", "")
        if not title or title.startswith(skip):
            continue
        what = a.get("description", "")
        extract = a.get("extract", "")
        summary = f"{what} — {extract}" if what and extract else what or extract
        out.append(
            {
                "person": is_person(what),
                "key": f"wiki:{time.strftime('%Y%m%d', day)}:{title}",
                "title": title,
                "summary": clean(summary)[:400],
                "link": a.get("content_urls", {}).get("desktop", {}).get("page", ""),
                "source": f"{a.get('views', 0):,} views",
                # keep the most-read first when sorted newest-first
                "published": noon - rank,
                "event_at": None,
            }
        )
        if len(out) >= count:
            break
    return out


def fetch_source(source, limit=40):
    if "youtube" in source:
        return fetch_channel(source["youtube"], source["name"])
    if source.get("type") == "trends":
        return fetch_trends(source)
    if source.get("type") == "wikipedia":
        return fetch_wikipedia(source)
    resp = _get(source["url"])
    resp.raise_for_status()
    articles = parse_feed(
        resp.content,
        source["name"],
        source.get("min_words", 1),
        source.get("include", ()),
        source.get("exclude", ()),
    )
    if any(a["event_at"] for a in articles):
        # calendars: keep the soonest upcoming events, not the newest postings
        today = datetime.now().replace(hour=0, minute=0, second=0).timestamp()
        upcoming = [a for a in articles if a["event_at"] and a["event_at"] >= today]
        return sorted(upcoming, key=lambda a: a["event_at"])[:limit]
    return sorted(articles, key=lambda a: -a["published"])[:limit]


def fetch_all(panels, on_progress=None):
    """Fetch every source of every panel at once.

    Returns (articles, errors). Each article carries its panel id; each error is
    (panel title, source name, message). `on_progress(done, total)` is called as
    sources answer (for the loading bar).
    """
    jobs = [(panel, source) for panel in panels for source in panel["sources"]]
    subs = [source["reddit"] for _, source in jobs if "reddit" in source]
    articles, errors = [], []
    with ThreadPoolExecutor(max_workers=8) as pool:
        reddit = pool.submit(fetch_reddit, subs) if subs else None

        def run(source):
            if "reddit" in source:
                return reddit.result()[source["reddit"].lower()]
            return fetch_source(source)

        futures = [(panel, source, pool.submit(run, source)) for panel, source in jobs]
        if on_progress:
            for _, _, f in futures:
                f.add_done_callback(lambda _: on_progress(sum(g.done() for _, _, g in futures), len(futures)))
        for panel, source, future in futures:
            try:
                for article in future.result():
                    article["panel"] = panel["id"]
                    articles.append(article)
            except Exception as exc:  # one dead feed must not stop the rest
                errors.append((panel["title"], source["name"], str(exc)[:200]))
    return articles, errors
