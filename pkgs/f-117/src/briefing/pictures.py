"""Small pictures beside the headlines, found when the feeds are refreshed.

- A headline that names a person gets that person's photo from Wikipedia: the person
  named first. "Wes Moore signs ..." is looked up as "Wes Moore", "Netanyahu orders ..."
  as "Netanyahu" (Wikipedia takes it to Benjamin Netanyahu; a name shared by many, like
  "Moore", is a disambiguation page and is skipped). Once a full name has been seen in
  this refresh, a headline with just that surname ("Moore vetoes ...") gets the same face.
- Any other story gets the picture its feed sent along (or a video's thumbnail).

Nothing is kept on disk: the pictures live in memory until the next refresh replaces
them (his choice, 2026-10-25: "no need to build a library"). Only the newest stories of
each panel get one, which are the ones on screen.
"""

import re
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import requests
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QImage

from .feeds import USER_AGENT, WIKI_UA, is_person

SIZE = 128  # pixels kept per picture (shown at about half that, sharp on any screen)
PER_PANEL = 15  # newest stories per panel that get a picture
MAX_AGE = 4 * 86400

# Two to four capitalised words in a row: "Wes Moore", "Kim Jong Un", "J.D. Vance".
NAME_RE = re.compile(r"\b(?:[A-Z][a-z]+|[A-Z]\.(?:[A-Z]\.)?)(?:\s+(?:[A-Z][a-z'’-]+|[A-Z]\.)){1,3}\b")
# Wikipedia's first sentence about a person: "(born 1946)", "(1931–2024)", or "is an
# Israeli politician" / "was the 16th president".
LIFE_RE = re.compile(r"\((?:[^()]*\b)?(?:born|b\.)\s[^()]*\d{4}|\(\d{4}\s*[–-]\s*\d{4}\)")
ROLE_RE = re.compile(
    r"\b(?:is|was) (?:an?|the) [^.]{0,80}?\b(?:politician|president|prime minister|governor|senator|congressman|"
    r"congresswoman|representative|minister|secretary|chancellor|king|queen|prince|princess|pope|monarch|dictator|"
    r"general|judge|justice|lawyer|diplomat|businessman|businesswoman|billionaire|investor|economist|journalist|"
    r"commentator|host|presenter|broadcaster|actor|actress|singer|rapper|musician|athlete|player|fighter|coach|"
    r"author|writer|activist|leader|official|executive|entrepreneur|youtuber|streamer|comedian|director)\b",
    re.I,
)
WORD_RE = re.compile(r"\b[A-Z][a-z]{3,}(?:[’']s)?\b")
NOT_A_NAME = {"The", "A", "An", "New", "How", "Why", "What", "When", "Who", "Watch", "Live", "Breaking", "Update",
              "This", "That", "These", "With", "After", "Before", "From", "Over", "Into", "Says", "Will", "More",
              "Most", "Just", "Here", "There", "Today", "Week", "Year", "News", "Daily", "Report", "Episode"}

_people = {}  # name -> picture url or None, kept for the app's run so 15-minute refreshes stay quick


def key(title):
    return (title or "").lower().strip()


def _bare(name):
    return re.sub(r"[’']s$", "", name).strip()


def candidates(title):
    """Possible names in a headline, in the order they appear. Headlines in Title Case
    run names into their neighbours ("Todd Blanche Cuts Off Dana Bash"), so every two-
    and three-word stretch of a capitalised run is a guess, and so is every single
    capitalised word ("Netanyahu"); at the same spot the longer guess comes first."""
    out = []
    for m in NAME_RE.finditer(title):
        words, pos, at = m.group(0).split(), [], m.start()
        for w in words:
            pos.append(title.index(w, at))
            at = pos[-1] + len(w)
        for i in range(len(words)):
            if words[i] in NOT_A_NAME:
                continue
            for n in (3, 2):
                if i + n <= len(words):
                    out.append((pos[i], -n, _bare(" ".join(words[i:i + n]))))
    for m in WORD_RE.finditer(title):
        word = _bare(m.group(0))
        if word not in NOT_A_NAME:
            out.append((m.start(), -1, word))
    seen, names = set(), []
    for _, _, name in sorted(out):
        if name not in seen:
            seen.add(name)
            names.append(name)
    return names


def person_picture(name):
    """Wikipedia's picture of `name`, if that name is a person with a picture."""
    if name in _people:
        return _people[name]
    url = None
    try:
        r = requests.get(
            "https://en.wikipedia.org/api/rest_v1/page/summary/" + requests.utils.quote(name.replace(" ", "_")),
            headers=WIKI_UA, timeout=8,
        )
        if r.ok:
            s = r.json()
            first = (s.get("extract") or "")[:300]
            if s.get("type") == "standard" and s.get("thumbnail") and (
                LIFE_RE.search(first) or ROLE_RE.search(first) or is_person(s.get("description"))
            ):
                url = s["thumbnail"]["source"]
    except (requests.RequestException, ValueError):
        return None  # try again next refresh
    _people[name] = url
    return url


def video_thumb(link):
    m = re.search(r"(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)([\w-]{11})", link or "")
    return f"https://i.ytimg.com/vi/{m.group(1)}/mqdefault.jpg" if m else None


def download(url):
    """The picture at `url`, cropped square and made small, or None."""
    try:
        r = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=10)
        if not r.ok or len(r.content) > 8_000_000:
            return None
        img = QImage.fromData(r.content)
    except requests.RequestException:
        return None
    if img.isNull() or img.width() < 40 or img.height() < 40:
        return None  # tracking pixels and tiny logos
    side = min(img.width(), img.height())
    # faces are near the top of portraits, so crop from the top rather than the middle
    top = 0 if img.height() > img.width() else (img.height() - side) // 2
    img = img.copy((img.width() - side) // 2, top, side, side)
    return img.scaled(SIZE, SIZE, Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)


def gather(articles, on_progress=None):
    """{headline key: QImage} for the newest stories of each panel.
    `on_progress(done, total)` follows the lookups and downloads (for the loading bar)."""
    now = time.time()
    by_panel = {}
    for a in articles:
        if a.get("event_at") or now - a["published"] > MAX_AGE:
            continue
        by_panel.setdefault(a["panel"], []).append(a)
    chosen, seen = [], set()
    for items in by_panel.values():
        for a in sorted(items, key=lambda a: -a["published"])[:PER_PANEL]:
            if key(a["title"]) not in seen:
                seen.add(key(a["title"]))
                chosen.append(a)

    names = sorted({n for a in chosen for n in candidates(a["title"])})
    count = {"done": 0, "total": len(names) + len(chosen)}  # downloads are about one per story
    lock = threading.Lock()

    def step(fn):
        def run(x):
            try:
                return fn(x)
            finally:
                with lock:
                    count["done"] += 1
                    if on_progress:
                        on_progress(min(count["done"], count["total"]), count["total"])
        return run

    with ThreadPoolExecutor(max_workers=8) as pool:
        found = dict(zip(names, pool.map(step(person_picture), names)))
        people = {n: u for n, u in found.items() if u}
        # surname alone -> that person, when only one person seen has it
        surnames = {}
        for n in people:
            if " " in n:
                surnames.setdefault(n.split()[-1], set()).add(people[n])
        alone = {s: next(iter(us)) for s, us in surnames.items() if len(us) == 1}

        def picture_for(a):
            for n in candidates(a["title"]):  # whoever is named first
                if n in people:
                    return people[n]
                if n in alone:
                    return alone[n]
            return a.get("image") or video_thumb(a.get("link"))

        wanted = {key(a["title"]): picture_for(a) for a in chosen}
        urls = sorted({u for u in wanted.values() if u})
        count["total"] = len(names) + len(urls)
        images = dict(zip(urls, pool.map(step(download), urls)))
    return {k: images[u] for k, u in wanted.items() if u and images.get(u) is not None}
