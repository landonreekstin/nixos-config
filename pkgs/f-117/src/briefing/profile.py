"""His preferences ("My Focus"), kept apart from the code so they can be edited
in the app — and so someone else using the app starts with their own.

Stored as JSON in the data folder (~/.local/share/briefing-room/profile.json).
The AI briefings read `about` and `focus`; the story filters read `mute`;
dates and events read the two horizon numbers.
"""

import json

from .store import data_dir

DEFAULTS = {
    "name": "",
    # shown when the app starts; {time_of_day} becomes morning / afternoon / evening
    "greeting": "Good {time_of_day}{comma_name}.",
    "refresh_pages": None,  # pages ticked in the start-up refresh list (None = all)
    "about": "",
    "focus": [],
    "mute": [],
    "horizon_days": 90,
    "important_days": 365,
    # the control panel's weather: {"name", "lat", "lon"} (None = guessed from the connection)
    "weather_place": None,
}


def path():
    return data_dir() / "profile.json"


def load():
    try:
        data = json.loads(path().read_text())
    except (OSError, ValueError):
        data = {}
    return {**DEFAULTS, **data}


def save(profile):
    tmp = path().with_suffix(".tmp")
    tmp.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path())
