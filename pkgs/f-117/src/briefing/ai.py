"""AI-written briefings, made by the `claude` command-line program.

Nothing here runs on its own: he presses BRIEF ME on one category (one panel) or
BRIEF ALL for a whole tab. The app hands Claude that panel's headlines for the
chosen window and gets back a TL;DR and key points (plus an overview for a whole
tab). Tools are switched off and results are kept in the database.
"""

import json
import os
import shutil
import subprocess
import time
from datetime import datetime

from . import profile as profile_store
from .store import data_dir
from .summary import WINDOWS, rank

MODEL = "claude-opus-5-5"
EFFORT = "low"
MAX_ITEMS_PER_PANEL = {"day": 25, "week": 35, "month": 40}
POINTS = {"day": "2-3", "week": "3-4", "month": "4-5"}

SYSTEM = """You write the TL;DR section of a personal news dashboard called F-117.
The reader wants to know quickly what actually happened and what each set of sources is
focused on, without having to click through to the stories.

You are given one tab of the dashboard: several panels, each with numbered headlines (and
sometimes a snippet) from the chosen time window. Work only from those items. Do not add
facts that are not in them, and do not take sides. When a panel is a particular outlet or
audience (for example MAGA media, Fox News, the establishment press), say what that
audience is focused on and how it frames things, attributing claims to the outlets rather
than stating them as fact. Video titles from YouTube creators are often exaggerated;
describe their topic plainly. For deal panels, name the knife, the price and the store when
given, and flag the best-value deals. For calendar panels (items with an event date), say
what is coming up and when, soonest first; skip routine classes.

Prefer substance over noise: lead with what is most significant and most widely
reported, and skip filler (live blogs, quizzes, podcast plugs, celebrity gossip unless it
is genuinely what everyone is talking about).

Write in plain, direct English, calm and proportionate. No hype, no filler, no "In
summary". When someone or something may be unfamiliar, say in a few words who or what it
is. Each point should be one sentence that stands on its own. Cite the numbers of the
items each point is based on."""


def system_prompt(profile):
    """The fixed instructions plus what he has written on his My Focus page."""
    parts = [SYSTEM]
    if profile.get("about", "").strip():
        parts.append("About the reader: " + profile["about"].strip())
    if profile.get("focus"):
        parts.append("What the reader has asked for (follow these):\n" + "\n".join(f"- {f}" for f in profile["focus"]))
    parts.append(
        f"Time horizon: mention things coming up only within the next {profile.get('horizon_days', 90)} days, "
        f"except genuinely major things up to {profile.get('important_days', 365)} days out."
    )
    return "\n\n".join(parts)

PANELS_SCHEMA = {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "tldr": {"type": "string", "description": "1-2 sentence gist of the panel"},
                    "points": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "text": {"type": "string"},
                                "refs": {"type": "array", "items": {"type": "integer"}},
                            },
                            "required": ["text", "refs"],
                        },
                    },
                },
                "required": ["id", "tldr", "points"],
            },
}


def schema(with_overview):
    props = {"panels": PANELS_SCHEMA}
    if with_overview:
        props["overview"] = {"type": "string", "description": "2-3 sentences on the biggest things across the whole tab"}
    return {"type": "object", "properties": props, "required": list(props)}


class BriefingError(Exception):
    """Something stopped the AI briefing; the message is shown to him."""


def claude_path():
    return shutil.which("claude") or "/etc/profiles/per-user/{}/bin/claude".format(os.environ.get("USER", ""))


def _ago(ts, now):
    hours = max(0, (now - ts) / 3600)
    return f"{hours:.0f}h ago" if hours < 48 else f"{hours / 24:.0f}d ago"


def build_prompt(tab, panel_articles, period, with_overview=True, now=None):
    """Returns (prompt text, {item number: article})."""
    now = now or time.time()
    numbered, lines = {}, []
    lines.append(f"Tab: {tab['title']} — {tab.get('about', '')}")
    lines.append(
        f"Window: the past {period} for news; the next {period} for calendar events "
        f"(now is {datetime.fromtimestamp(now):%A %d %B %Y, %H:%M})."
    )
    lines.append(f"Give {POINTS[period]} points per panel (fewer if a panel has little news).")
    if not with_overview:
        lines.append("Only one panel is included this time; no overview is needed.")
    for cfg, articles in panel_articles:
        lines.append("")
        lines.append(f"## Panel id={cfg['id']} — {cfg['title']} ({cfg.get('subtitle', '')})")
        if not articles:
            lines.append("(no items in this window — return an empty points list and say so in tldr)")
            continue
        if any(a.get("event_at") for a in articles):
            chosen = articles[: MAX_ITEMS_PER_PANEL[period]]  # already soonest first
        else:
            chosen = rank(articles, period)[: MAX_ITEMS_PER_PANEL[period]]
            chosen.sort(key=lambda a: -a["published"])
        for a in chosen:
            n = len(numbered) + 1
            numbered[n] = a
            snippet = f" — {a['summary'][:180]}" if a["summary"] else ""
            if a.get("event_at"):
                when = f"event on {datetime.fromtimestamp(a['event_at']):%a %d %b, %I:%M %p}"
            else:
                when = _ago(a["published"], now)
            kind = ", video" if a["link"].startswith("https://www.youtube.com/") else ""
            lines.append(f"[{n}] ({a['source']}, {when}{kind}) {a['title']}{snippet}")
    return "\n".join(lines), numbered


def write_briefing(tab, panel_articles, period, with_overview=True):
    """Ask Claude for a briefing of the given panels. Returns the parsed briefing
    with each point's refs turned into article dicts, plus usage numbers."""
    prompt, numbered = build_prompt(tab, panel_articles, period, with_overview)
    exe = claude_path()
    if not os.path.exists(exe):
        raise BriefingError("The claude program is not installed on this computer.")
    cmd = [
        exe, "-p",
        "--model", MODEL,
        "--effort", EFFORT,
        "--output-format", "json",
        "--json-schema", json.dumps(schema(with_overview)),
        "--system-prompt", system_prompt(profile_store.load()),
        "--tools", "",
        "--strict-mcp-config",
        "--no-session-persistence",
    ]
    try:
        # Run from the app's data folder so no project notes get sent along.
        proc = subprocess.run(
            cmd, input=prompt, capture_output=True, text=True, timeout=300, cwd=data_dir()
        )
    except subprocess.TimeoutExpired:
        raise BriefingError("Claude took too long to answer. Try REGENERATE in a minute.") from None

    out = proc.stdout.strip()
    if "Not logged in" in out or "Please run /login" in out:
        raise BriefingError("NOT_LOGGED_IN")
    try:
        reply = json.loads(out)
    except json.JSONDecodeError:
        raise BriefingError((out or proc.stderr.strip() or "No answer from Claude.")[:300]) from None
    if reply.get("is_error"):
        raise BriefingError(str(reply.get("result", "Claude reported an error."))[:300])

    data = reply.get("structured_output")
    if data is None:
        text = reply.get("result", "").strip().removeprefix("```json").removesuffix("```")
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            raise BriefingError("Claude's answer was not in the expected format.") from None

    for panel in data.get("panels", []):
        for point in panel.get("points", []):
            point["articles"] = [numbered[r] for r in point.get("refs", []) if r in numbered]
    u = reply.get("usage", {})
    total = sum(u.get(k) or 0 for k in ("input_tokens", "cache_creation_input_tokens",
                                         "cache_read_input_tokens", "output_tokens"))
    data["usage"] = {
        "cost_usd": reply.get("total_cost_usd"),
        "input_tokens": u.get("input_tokens"),
        "output_tokens": u.get("output_tokens"),
        "total_tokens": total,  # everything it counted, cached setup text included
        "items": len(numbered),
    }
    learn(total, len(numbered), len(data.get("panels", [])))
    return data


# --- knowing the cost before asking ------------------------------------------------------------
# He asked (2026-10-26) that no action may use Claude tokens without his knowing: every
# briefing first shows this estimate and waits for a yes. The estimate starts from a
# cautious guess and then learns from what real briefings counted (stats in the data folder).

def _stats_path():
    return data_dir() / "token-stats.json"


def _stats():
    try:
        return json.loads(_stats_path().read_text())
    except (OSError, ValueError):
        return {}


def learn(total, items, panels):
    s = _stats()
    runs = s.get("runs", [])[-19:] + [{"total": total, "items": items, "panels": panels}]
    try:
        _stats_path().write_text(json.dumps({"runs": runs}))
    except OSError:
        pass


def estimate_tokens(panel_articles, with_overview):
    """About how many tokens a briefing of these panels will count, all in."""
    items = sum(len(arts) for _, arts in panel_articles)
    panels = len(panel_articles)
    runs = _stats().get("runs", [])
    if runs:
        # cost per story and per panel from past runs (simple average of the ratios)
        per = sum(r["total"] / max(r["items"] * 90 + r["panels"] * 900 + 6000, 1) for r in runs) / len(runs)
    else:
        per = 1.0
    guess = items * 90 + panels * 900 + 6000 + (600 if with_overview else 0)
    return int(round(guess * per, -2))


def window_start(period, now=None):
    return (now or time.time()) - WINDOWS[period] * 86400


def window_end(period, now=None):
    """For calendar panels the window looks ahead instead."""
    return (now or time.time()) + WINDOWS[period] * 86400
