"""What the world map knows: countries, the wars going on, who is fighting, where the
front line runs, and which cities the news names. Everything here is fetched fresh (at
start-up and after each refresh) and kept in memory; only the borders and city
locations are bundled (Natural Earth, public domain, in assets/).

Sources, all public and current:
- Wikipedia's "List of ongoing armed conflicts": every ongoing war with its level (by
  deaths in the current or past year), the countries it happens in, when it started and
  this year's deaths. Editors keep it up to date; the map says so where it shows it.
- Each war's own Wikipedia article: the "Belligerents" row of its infobox, i.e. the
  factions on each side.
- DeepStateMap (deepstatemap.live), updated daily: occupied and contested territory in
  Ukraine. It is the only war with a free, daily territory map, so the others show
  their factions and cities but no drawn front.
- His own stories (the store): cities named together with conflict words in the past
  week become "conflict cities", with how many stories and the latest headline.
"""

import html
import json
import re
import time
from datetime import datetime

import requests

from . import theme as T
from .feeds import WIKI_UA
from .store import data_dir

LIST_PAGE = "List_of_ongoing_armed_conflicts"
# the page's four tables, from most to least deadly (deaths in the current or past year)
LEVELS = [
    ("conflicts10000", "Major war", "10,000+ deaths a year"),
    ("conflicts1000", "War", "1,000–9,999 deaths a year"),
    ("conflicts100", "Conflict", "100–999 deaths a year"),
    ("conflicts1", "Skirmishes", "under 100 deaths a year"),
]
CITY_DAYS = 7

# Wikipedia's country names that Natural Earth spells another way
ALIASES = {
    "palestine": "Palestine", "state of palestine": "Palestine", "democratic republic of the congo": "Dem. Rep. Congo",
    "republic of the congo": "Congo", "ivory coast": "Côte d'Ivoire", "united states": "United States of America",
    "turkey": "Turkey", "türkiye": "Turkey", "czech republic": "Czechia", "east timor": "Timor-Leste",
    "the gambia": "Gambia", "eswatini": "eSwatini", "north macedonia": "North Macedonia",
    "central african republic": "Central African Rep.", "south sudan": "S. Sudan", "western sahara": "W. Sahara",
    "bosnia and herzegovina": "Bosnia and Herz.", "dominican republic": "Dominican Rep.",
    "equatorial guinea": "Eq. Guinea", "somaliland": "Somaliland", "northern cyprus": "N. Cyprus",
}


# --- borders and cities ---------------------------------------------------------------------

def load_countries():
    data = json.loads((T.ASSETS / "countries.json").read_text())["countries"]
    for c in data:
        xs = [p[0] for r in c["rings"] for p in r]
        ys = [p[1] for r in c["rings"] for p in r]
        c["bbox"] = (min(xs), min(ys), max(xs), max(ys))
        c["conflicts"] = []
    return data


def load_cities():
    return json.loads((T.ASSETS / "cities.json").read_text())["cities"]


def country_index(countries):
    """Every spelling of every country -> the country."""
    idx = {}
    for c in countries:
        for n in c["names"] + [c["name"]]:
            idx.setdefault(n.lower(), c)
    for k, v in ALIASES.items():
        target = next((c for c in countries if c["name"] == v), None)
        if target:
            idx[k] = target
    return idx


# --- the wars ----------------------------------------------------------------------------------

_wait_until = 0.0  # Wikipedia said "too many requests": don't ask again before this


def wiki_wait():
    """Seconds until Wikipedia may be asked again (0 = now)."""
    return max(0.0, _wait_until - time.time())


def wiki(params, timeout=25):
    """One Wikipedia API call. If it says "too many requests", wait as asked (up to 10 s)
    and try once more: it asks clients to slow down, and we only ever ask on Refresh."""
    global _wait_until
    if wiki_wait():
        raise RuntimeError("Wikipedia asked us to wait")
    for attempt in (0, 1):
        r = requests.get("https://en.wikipedia.org/w/api.php", headers=WIKI_UA, timeout=timeout,
                         params={**params, "format": "json", "formatversion": 2})
        try:
            wait = float(r.headers.get("Retry-After", 60))
        except ValueError:
            wait = 60.0
        if r.status_code == 429 and attempt:
            _wait_until = time.time() + max(60.0, wait)  # the Refresh button waits this out
        if r.status_code != 429 or attempt:
            r.raise_for_status()
            return r.json()
        time.sleep(min(10.0, wait))


def _text(fragment):
    t = re.sub(r"<style.*?</style>", " ", fragment, flags=re.S)
    t = re.sub(r"<sup.*?</sup>", " ", t, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", t))).strip()


def _links(fragment):
    return [html.unescape(t) for t in re.findall(r'<a href="/wiki/(?!File:)[^"#]+"[^>]*title="([^"]+)"', fragment)]


def _number(text):
    m = re.search(r"\d[\d,]*", text or "")
    return int(m.group(0).replace(",", "")) if m else None


def fetch_conflicts():
    """[{name, article, parts, level, level_note, rank, since, countries, deaths_year}]"""
    page = wiki(dict(action="parse", page=LIST_PAGE, prop="text"))["parse"]["text"]
    out = []
    for rank, (table_id, level, note) in enumerate(LEVELS):
        i = page.find(f'id="{table_id}"')
        if i < 0:
            continue
        table = page[i:page.find("</table>", i)]
        head = re.findall(r"<th[^>]*>(.*?)</th>", table, re.S)
        years = [m for m in (re.search(r"(20\d\d) fatalities", _text(h)) for h in head) if m]
        for row in table.split("<tr")[2:]:
            cells = [c[c.find(">") + 1:] for c in re.split(r"<td", row)[1:]]  # drop each cell's own attributes
            if len(cells) < 4:
                continue
            links = [n for n in _links(cells[1]) if "(disambiguation)" not in n]
            if not links:
                continue
            out.append({
                "name": links[0], "article": links[0], "parts": links[1:12], "level": level, "level_note": note,
                "rank": rank, "since": _text(cells[0])[:12], "countries": _links(cells[3]),
                "deaths_year": _number(_text(cells[-1])) if len(cells) >= 5 else None,
                "year": years[-1].group(1) if years else str(datetime.now().year),
            })
    return out


_factions = {}  # article -> [[side 1 names], [side 2 names], ...]


def _current_first(titles, name=""):
    """Today's phase of a war before its history: "Sudanese civil war (2023–present)" and
    "Gaza war" before "Arab–Israeli conflict", whose infobox lists the armies of 1948.
    Among equals, the one most like the war's own name ("Sudanese civil war (2023–present)"
    before "Abyei border conflict (2022–present)")."""
    own = set(re.findall(r"[a-z]+", name.lower())) - {"the", "of", "in", "war", "conflict"}

    def score(t):
        years = [int(y) for y in re.findall(r"\b(19\d\d|20\d\d)\b", t)]
        if "present" in t:
            return 0
        if years and max(years) >= 2020:
            return 1
        if re.search(r"\b(war|invasion|offensive|civil war)\b", t, re.I) and not years:
            return 2
        return 3
    def like(t):
        return -len(own & set(re.findall(r"[a-z]+", t.lower())))

    return sorted(dict.fromkeys(titles), key=lambda t: (score(t), like(t)))


def factions_for(conflict):
    """The factions of a war, from the infobox of its current phase (see _current_first)."""
    for article in _current_first([conflict["article"]] + conflict["parts"], conflict["name"])[:5]:
        sides = fetch_factions(article)
        if sides:
            return article, sides
    return None, []


def fetch_factions(article):
    """The factions on each side, from the article's infobox ("Belligerents")."""
    if article in _factions:
        return _factions[article]
    sides = []
    try:
        page = wiki(dict(action="parse", page=article, prop="text", section=0, redirects=1), timeout=20)["parse"]["text"]
        m = re.search(r">\s*(Belligerents|Combatants|Parties)\s*<", page)
        i = m.start() if m else -1
        if i >= 0:
            row = page[i:]
            row = row[row.find("<tr"):]
            row = row[:row.find("</tr>")]
            for cell in re.split(r"<td", row)[1:]:
                names = []
                for n in _links(cell):
                    if n not in names and not re.match(r"(Flag of|List of|Template:|Help:)", n):
                        names.append(n)
                if names:
                    sides.append(names[:8])
    except (requests.RequestException, ValueError, KeyError):
        return None  # try again later
    _factions[article] = sides
    return sides


# --- remembering the last read (so the map opens filled in, saying how old it is) ---------------------

def cache_path():
    return data_dir() / "world-cache.json"


def save_cache(conflicts, front, factions, read_at):
    data = {"read_at": read_at.isoformat() if read_at else None, "conflicts": conflicts,
            "front": {**front, "when": front["when"].isoformat()} if front else None,
            "factions": {k: list(v) for k, v in factions.items() if v and v[1]}}
    try:
        tmp = cache_path().with_suffix(".tmp")
        tmp.write_text(json.dumps(data))
        tmp.replace(cache_path())
    except OSError:
        pass


def load_cache():
    """(conflicts, front, factions, read_at), or Nones when there is nothing yet."""
    try:
        d = json.loads(cache_path().read_text())
    except (OSError, ValueError):
        return [], None, {}, None
    front = d.get("front")
    if front:
        front["when"] = datetime.fromisoformat(front["when"])
        for k in ("occupied", "contested"):
            front[k] = [[tuple(p) for p in ring] for ring in front[k]]
    read = datetime.fromisoformat(d["read_at"]) if d.get("read_at") else None
    return d.get("conflicts") or [], front, {k: tuple(v) for k, v in (d.get("factions") or {}).items()}, read


# --- the front line in Ukraine --------------------------------------------------------------------

def fetch_front():
    """{"when": datetime, "occupied": [rings], "contested": [rings]} from DeepStateMap."""
    r = requests.get("https://deepstatemap.live/api/history/last", headers={"User-Agent": "Mozilla/5.0 BriefingRoom/1.0"},
                     timeout=25)
    r.raise_for_status()
    d = r.json()
    out = {"when": datetime.fromtimestamp(d["id"]), "occupied": [], "contested": []}
    for f in d["map"]["features"]:
        name, g = f["properties"].get("name", ""), f["geometry"]
        kind = "occupied" if ("Occupied" in name or "occupied" in name) else "contested" if "Unknown" in name else None
        if kind is None or g["type"] not in ("Polygon", "MultiPolygon"):
            continue
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        for poly in polys:
            ring, last = [], None
            for pt in poly[0]:
                p = (round(pt[0], 3), round(pt[1], 3))
                if last is None or abs(p[0] - last[0]) + abs(p[1] - last[1]) > 0.01:
                    ring.append(p)
                    last = p
            if len(ring) > 3:
                out[kind].append(ring)
    return out


# --- cities in the news ------------------------------------------------------------------------------

def conflict_cities(store, cities, tense, countries_by_iso, days=CITY_DAYS):
    """{iso: [(city, lat, lon, stories, latest headline)]}: cities of 20,000+ people named
    in stories about conflict over the past week. Capitals named only as a stand-in for
    a government ("Moscow says") still count; the list says "named in", not "attacked"."""
    big = [c for c in cities if c[4] >= 20000 and len(c[0]) >= 4]
    by_name = {}
    for c in big:
        by_name.setdefault(c[0].lower(), c)
    if not by_name:
        return {}
    rx = re.compile(r"\b(" + "|".join(re.escape(n) for n in sorted(by_name, key=len, reverse=True)) + r")\b", re.I)
    hits, seen = {}, set()
    for a in store.news_since(int(time.time()) - days * 86400):
        key = a["title"].lower().strip()
        if key in seen:
            continue
        seen.add(key)
        text = f"{a['title']} {a.get('summary', '')[:300]}"
        if not tense.search(text):
            continue
        for m in {m.group(1).lower() for m in rx.finditer(text)}:
            c = by_name[m]
            h = hits.setdefault(c[0], [c[0], c[1], c[2], 0, a["title"], a["published"], c[3]])
            h[3] += 1
            if a["published"] > h[5]:
                h[4], h[5] = a["title"], a["published"]
    out = {}
    for h in sorted(hits.values(), key=lambda h: -h[3]):
        out.setdefault(h[6], []).append(tuple(h[:5]))
    return out
