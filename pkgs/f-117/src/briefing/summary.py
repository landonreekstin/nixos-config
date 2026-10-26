"""TL;DR builder.

Works offline with no AI service: it finds the words that keep coming up across
a panel's headlines in the chosen time window (the "threads"), then picks the
stories that best represent those threads, skipping near-duplicates.
"""

import re
import time
from collections import Counter

WINDOWS = {"day": 1, "week": 7, "month": 30}
PICKS = {"day": 3, "week": 5, "month": 7}

WORD_RE = re.compile(r"[A-Za-z][A-Za-z'\-]{2,}")
SENTENCE_RE = re.compile(r"(?<=[.!?])\s+")

STOPWORDS = set(
    """
    a about above after again against all also am an and any are aren't as at be because been
    before being below between both but by can can't cannot could couldn't did didn't do does
    doesn't doing don't down during each few for from further had hadn't has hasn't have haven't
    having he he'd he'll he's her here here's hers herself him himself his how how's i i'd i'll
    i'm i've if in into is isn't it it's its itself let's me more most mustn't my myself no nor
    not of off on once only or other ought our ours ourselves out over own same shan't she she'd
    she'll she's should shouldn't so some such than that that's the their theirs them themselves
    then there there's these they they'd they'll they're they've this those through to too under
    until up very was wasn't we we'd we'll we're we've were weren't what what's when when's where
    where's which while who who's whom why why's with won't would wouldn't you you'd you'll you're
    you've your yours yourself yourselves
    says said say new news will just now get gets got make makes made one two three first last
    year years day days week weeks month months today tonight yesterday tomorrow time back still
    may might many much amid via per like amp nbsp says told tells take takes help helps set sets
    announces announced announcement update updates report reports live watch read photos video
    here's what know need want people way ways us u.s get could would should across win wins
    big top key early late long full part next back plus around within without
    monday tuesday wednesday thursday friday saturday sunday
    january february march april june july august september october november december
    """.split()
)


def _terms(text):
    return [w.strip("'-") for w in WORD_RE.findall(text) if w.lower().strip("'-") not in STOPWORDS]


def _first_sentence(text, limit=170):
    if not text:
        return ""
    sentence = SENTENCE_RE.split(text, 1)[0]
    if len(sentence) > limit:
        sentence = sentence[:limit].rsplit(" ", 1)[0] + "…"
    return sentence


def _score(articles, period, now):
    """Score every article by how well it covers the window's recurring words.

    Returns (scored list of (score, article, title words), threads)."""
    casing = {}
    doc_terms = []
    df = Counter()
    for a in articles:
        title_terms = _terms(a["title"])
        body_terms = _terms(a["summary"])
        for w in title_terms + body_terms:
            casing.setdefault(w.lower(), Counter())[w] += 1
        lowered = {w.lower() for w in title_terms} | {w.lower() for w in body_terms}
        doc_terms.append(({w.lower() for w in title_terms}, lowered))
        df.update(lowered)

    n = len(articles)
    # Words in nearly every item (e.g. "Maryland" in a Maryland panel) say nothing.
    too_common = {w for w, c in df.items() if n >= 6 and c / n > 0.5}
    weight = {w: c - 1 for w, c in df.items() if c >= 2 and w not in too_common}

    threads = [w for w, _ in sorted(weight.items(), key=lambda kv: (-kv[1], kv[0]))[:6]]
    threads = [casing[w].most_common(1)[0][0] for w in threads]
    threads = [w if not w.islower() else w.capitalize() for w in threads]

    span = WINDOWS[period] * 86400
    scored = []
    for a, (title_set, all_set) in zip(articles, doc_terms):
        score = sum(weight.get(w, 0) * 2 for w in title_set)
        score += sum(weight.get(w, 0) for w in all_set - title_set)
        score /= max(len(title_set), 3) ** 0.5
        recency = max(0.0, 1 - (now - a["published"]) / span)
        scored.append((score + recency * 1.5, a, title_set))
    scored.sort(key=lambda t: -t[0])
    return scored, threads


# Headlines that are usually filler rather than news.
JUNK_RE = re.compile(
    r"^(watch|live|listen|photos?|quiz|podcast|opinion|letters?|crossword|puzzle|sunday puzzle|"
    r"the take|newsletter|ICYMI|sponsored)\b|live updates|live blog|\bpodcast\b|weekly roundup|"
    r"^(lever weekly|monopoly round-?up)|#shorts",
    re.I,
)


def coverage(articles):
    """How many different outlets mention each word, across everything recent.
    A story many outlets are covering is probably one that matters."""
    sources_by_term = {}
    for a in articles:
        for w in {w.lower() for w in _terms(a["title"])}:
            sources_by_term.setdefault(w, set()).add(a["source"])
    return {w: len(s) for w, s in sources_by_term.items() if len(s) > 1}


def quality_order(articles, cover, now=None, per_source=2, limit=None):
    """Best stories first: widely covered, recent, not filler, and no outlet
    taking more than `per_source` of the top spots."""
    now = now or time.time()
    scored = []
    for a in articles:
        words = {w.lower() for w in _terms(a["title"])}
        big = sorted((min(cover.get(w, 1), 10) - 1 for w in words), reverse=True)[:4]
        significance = sum(big) / 4
        hours = max(0.0, (now - a["published"]) / 3600)
        freshness = 0.5 ** (hours / 24)  # halves every day
        score = (1 + significance) * (0.25 + freshness)
        if JUNK_RE.search(a["title"]) or len(a["title"].split()) < 4:
            score *= 0.2
        if a.get("summary"):
            score *= 1.3  # readable without clicking

        scored.append((score, a))
    scored.sort(key=lambda t: -t[0])
    picked, rest, per = [], [], {}
    for _, a in scored:
        if per.get(a["source"], 0) < per_source:
            picked.append(a)
            per[a["source"]] = per.get(a["source"], 0) + 1
        else:
            rest.append(a)
    ordered = picked + rest
    return ordered[:limit] if limit else ordered


def rank(articles, period, now=None):
    """Articles ordered from most to least representative of the window."""
    if not articles:
        return []
    scored, _ = _score(articles, period, now or time.time())
    return [a for _, a, _ in scored]


def summarize(articles, period, now=None):
    """Build the offline TL;DR for one panel.

    `articles` are the panel's stored articles already limited to the window.
    Returns a dict: count, sources, threads (list of words), picks (articles,
    each with an added 'gist' sentence).
    """
    now = now or time.time()
    if not articles:
        return {"count": 0, "sources": [], "threads": [], "picks": []}
    scored, threads = _score(articles, period, now)

    picks, chosen_sets = [], []
    for _, a, title_set in scored:
        if any(len(title_set & s) / max(len(title_set | s), 1) > 0.35 for s in chosen_sets):
            continue
        picks.append(dict(a, gist=_first_sentence(a["summary"])))
        chosen_sets.append(title_set)
        if len(picks) >= PICKS[period]:
            break

    sources = [s for s, _ in Counter(a["source"] for a in articles).most_common()]
    return {"count": len(articles), "sources": sources, "threads": threads, "picks": picks}
