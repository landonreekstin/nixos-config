"""The control panel: F-117's second screen.

The news fills the main screen; this window fills another one (when there is one) with
things to glance at: the weather, a map of where the news is reporting tension, and the
"Refresh your feeds?" tick-list, which used to pop up over the news and now waits here
quietly instead.

The map is worked out from the stories already on file (no AI, no extra fetching): a
place gets a dot when stories from the past two days name it together with words like
"troops", "missile" or "sanctions". The dot's size is how many stories, not how
dangerous anything is, and the colours stay calm on purpose.
"""

import json
import os
import re
import shutil
import socket
import subprocess
import threading
import time
from datetime import datetime

import requests
from PyQt6.QtCore import Qt, QThread, QTimer, pyqtSignal
from PyQt6.QtGui import QPainter
from PyQt6.QtWidgets import QCheckBox, QFrame, QHBoxLayout, QStackedWidget, QVBoxLayout, QWidget

from . import theme as T
from . import refreshmenu, world
from .feeds import USER_AGENT
from .worldmap import WorldMap

WEATHER_EVERY = 30 * 60 * 1000  # ms between weather checks
TENSION_HOURS = 48

# --- weather ---------------------------------------------------------------------------

CODES = {
    0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast", 45: "Fog", 48: "Freezing fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle", 56: "Freezing drizzle", 57: "Freezing drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Freezing rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains", 80: "Showers", 81: "Showers",
    82: "Heavy showers", 85: "Snow showers", 86: "Snow showers", 95: "Thunderstorms", 96: "Thunderstorms",
    99: "Thunderstorms",
}


def find_place(profile):
    """Where the weather is for: his profile's `weather_place`, or a guess from the
    internet connection when he has not set one."""
    place = profile.get("weather_place")
    if place and "lat" in place and "lon" in place:
        return place
    r = requests.get("http://ip-api.com/json/?fields=city,region,lat,lon", timeout=10)
    d = r.json()
    return {"name": f"{d['city']}, {d['region']}", "lat": d["lat"], "lon": d["lon"]}


def fetch_weather(profile):
    place = find_place(profile)
    r = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params=dict(
            latitude=place["lat"], longitude=place["lon"], timezone="auto", forecast_days=4,
            current="temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m",
            daily="weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max",
            temperature_unit="fahrenheit", wind_speed_unit="mph",
        ),
        headers={"User-Agent": USER_AGENT}, timeout=15,
    )
    r.raise_for_status()
    return {"place": place["name"], **r.json()}


class WeatherThread(QThread):
    done = pyqtSignal(object)  # the forecast dict, or an error message

    def __init__(self, profile):
        super().__init__()
        self.profile = profile

    def run(self):
        try:
            self.done.emit(fetch_weather(self.profile))
        except Exception as e:  # offline, or the service is down: the card says so
            self.done.emit(str(e) or "no answer")


# --- tabs that hold another app: Breaking Points (Spotify) and YouTube -------------------------
# F-117 cannot play Spotify or YouTube itself (his subscription and his YouTube account
# live in those apps), so these tabs borrow the real app's window: it is opened (or
# found, if already open) and fitted exactly over the tab, on this screen. Choosing
# another tab tucks it away (minimised, like the – button); coming back brings it back.

# "Breaking Points with Krystal and Saagar (Premium)": the red one, his subscription.
# (The blue 4Kbsy61zJSzPxNZZ3PKbXl is the free show; he asked for the red one.)
SHOW = "033kFeszOZEgO3Wy6ziXKR"
SPOTIFY_CLASS = re.compile(r"^spotify$", re.I)
YOUTUBE = "https://www.youtube.com/"
# Chromium's app window for a site is named after it (app id "chrome-www.youtube.com__-Default")
YOUTUBE_CLASS = re.compile(r"^chrom(e|ium)-www\.youtube\.com", re.I)


def fetch_episode():
    """The show's newest episode, from Spotify's public embed page (no login needed)."""
    r = requests.get(f"https://open.spotify.com/embed/show/{SHOW}", headers={"User-Agent": USER_AGENT}, timeout=15)
    r.raise_for_status()
    m = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', r.text, re.S)
    e = json.loads(m.group(1))["props"]["pageProps"]["state"]["data"]["entity"]
    when = datetime.fromisoformat(e["releaseDate"]["isoString"].replace("Z", "+00:00")).astimezone()
    return {"uri": e["uri"], "title": e.get("title") or e.get("name", ""), "when": when,
            "minutes": round((e.get("duration") or 0) / 60000)}


class EpisodeThread(QThread):
    done = pyqtSignal(object)  # the episode dict, or an error message

    def run(self):
        try:
            self.done.emit(fetch_episode())
        except Exception as e:
            self.done.emit(str(e) or "no answer")


def hypr(*commands):
    if shutil.which("hyprctl"):
        subprocess.run(["hyprctl", "--batch", " ; ".join(f"dispatch {c}" for c in commands)],
                       capture_output=True, timeout=5)


APP_TITLES = ("F-117", "F-117 · Control Panel")


def opacity_commands(addresses, alpha):
    a = f"{max(0.0, min(1.0, alpha)):.2f}"
    cmds = []
    for address in addresses:
        w = f"address:{address}"
        cmds += [f"setprop {w} opacity_override 1", f"setprop {w} opacity {a}",
                 f"setprop {w} opacity_inactive_override 1", f"setprop {w} opacity_inactive {a}"]
    return cmds


def app_addresses(titles=APP_TITLES):
    return [c["address"] for c in hypr_clients() if c.get("title") in titles]


def see_through(alpha, titles=APP_TITLES):
    """How opaque the app's windows are (Hyprland's per-window opacity, 0..1). The app
    starts at 0 behind the start-up animation and fades in as the animation fades out."""
    cmds = opacity_commands(app_addresses(titles), alpha)
    if cmds:
        hypr(*cmds)


def hypr_socket(request):
    """Send one request straight to Hyprland's control socket: far quicker than starting
    hyprctl (~20 ms each), quick enough to fade a window smoothly. False if it can't."""
    sig, run = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"), os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not run:
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(1)
            s.connect(f"{run}/hypr/{sig}/.socket.sock")
            s.sendall(request.encode())
            while s.recv(4096):
                pass
        return True
    except OSError:
        return False


class Fader(threading.Thread):
    """Fades the app's windows in while the start-up animation plays, off the main
    thread, so the animation never waits for Hyprland (2026-10-26: "luxury and seamless").
    `level()` says how far in (0..1); it ends once fully in."""

    def __init__(self, addresses, level):
        super().__init__(daemon=True)
        self.addresses, self.level = addresses, level

    def run(self):
        shown = None
        while True:
            k = round(max(0.0, min(1.0, self.level())), 2)
            if k != shown:
                shown = k
                batch = " ; ".join(f"dispatch {c}" for c in opacity_commands(self.addresses, k))
                if not hypr_socket("[[BATCH]]" + batch):
                    hypr(*opacity_commands(self.addresses, k))
            if k >= 1:
                return
            time.sleep(1 / 120)


def raise_windows(title):
    """Put every window with this title in front (Hyprland), e.g. the start-up screens
    over the app windows being placed behind them."""
    hypr(*[f"alterzorder top,address:{c['address']}" for c in hypr_clients() if c.get("title") == title])


def hypr_clients():
    try:
        out = subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True, timeout=3)
        return json.loads(out.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return []


def find_window(pattern):
    return next((c for c in hypr_clients() if pattern.match(c.get("class") or "")), None)


def spotify_window():
    return find_window(SPOTIFY_CLASS)


def expand_now_playing():
    """Click Spotify's "Expand Now Playing view" button (top right of its Now Playing
    sidebar) so the video fills the window: he wants the show to start that way. Spotify
    has no shortcut for it, so a virtual pointer clicks it and the mouse is put back.
    Esc first, because once expanded the same button minimises the view again."""
    win = spotify_window()  # where it really is now (it may not shrink as far as asked)
    if win is None:
        return
    wlrctl = shutil.which("wlrctl")
    cmd = [wlrctl] if wlrctl else ["nix", "run", "nixpkgs#wlrctl", "--"]
    x, y = win["at"][0] + win["size"][0] - 41, win["at"][1] + 96
    try:
        old = subprocess.run(["hyprctl", "cursorpos"], capture_output=True, text=True, timeout=3).stdout.strip()
        a = f"address:{win['address']}"
        hypr(f"focuswindow {a}", f"sendshortcut , Escape, {a}")
        time.sleep(0.4)
        hypr(f"movecursor {x} {y}")
        time.sleep(0.15)
        subprocess.run(cmd + ["pointer", "click", "left"], capture_output=True, timeout=60)
        if "," in old:
            ox, oy = (int(float(v)) for v in old.split(","))
            hypr(f"movecursor {ox} {oy}")
    except (OSError, ValueError, subprocess.SubprocessError):
        pass  # it just stays in the normal view


def open_youtube():
    """His YouTube home screen in its own Chromium window (his browser, signed in)."""
    flatpak = shutil.which("flatpak")
    if flatpak and subprocess.run([flatpak, "info", "org.chromium.Chromium"], capture_output=True).returncode == 0:
        cmd = [flatpak, "run", "org.chromium.Chromium", f"--app={YOUTUBE}"]
    elif shutil.which("chromium"):
        cmd = ["chromium", f"--app={YOUTUBE}"]
    else:
        cmd = ["xdg-open", YOUTUBE]
    subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def open_in_spotify(uri):
    """Play `uri` in the Spotify app: handed over if it is running, else it is started."""
    if spotify_window() and shutil.which("dbus-send"):
        done = subprocess.run(["dbus-send", "--print-reply", "--dest=org.mpris.MediaPlayer2.spotify",
                               "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.OpenUri",
                               f"string:{uri}"], capture_output=True, timeout=5)
        if done.returncode == 0:
            return
    flatpak = shutil.which("flatpak")
    if flatpak and subprocess.run([flatpak, "info", "com.spotify.Client"], capture_output=True).returncode == 0:
        cmd = [flatpak, "run", "com.spotify.Client", f"--uri={uri}"]
    elif shutil.which("spotify"):
        cmd = ["spotify", f"--uri={uri}"]
    else:
        cmd = ["xdg-open", uri]
    subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# --- where the news reports tension -------------------------------------------------------

# (shown name, lat, lon, the words that point at it). Matched as whole words, any case.
PLACES = [
    ("Ukraine", 49.0, 31.4, "ukraine, ukrainian, kyiv, kharkiv, odesa, donbas, zelensky"),
    ("Russia", 56.0, 40.0, "russia, russian, kremlin, moscow, putin"),
    ("Israel & Palestine", 31.6, 34.9, "israel, israeli, netanyahu, idf, gaza, hamas, west bank, palestinian, palestinians"),
    ("Lebanon", 33.9, 35.8, "lebanon, lebanese, hezbollah, beirut"),
    ("Syria", 35.0, 38.5, "syria, syrian, damascus"),
    ("Iran", 32.4, 53.7, "iran, iranian, tehran"),
    ("Iraq", 33.2, 43.7, "iraq, iraqi, baghdad"),
    ("Yemen", 15.6, 48.0, "yemen, houthi, houthis"),
    ("Red Sea", 19.0, 39.5, "red sea"),
    ("Turkey", 39.0, 35.2, "turkey, turkish, erdogan, ankara"),
    ("China", 35.0, 104.0, "china, chinese, beijing, xi jinping"),
    ("Taiwan", 23.7, 121.0, "taiwan, taiwanese, taipei"),
    ("South China Sea", 12.0, 114.0, "south china sea, philippines, philippine"),
    ("North Korea", 40.3, 127.5, "north korea, pyongyang, kim jong un"),
    ("South Korea", 36.5, 128.0, "south korea, seoul"),
    ("Japan", 36.2, 138.3, "japan, japanese, tokyo"),
    ("India", 22.0, 79.0, "india, indian, modi, delhi"),
    ("Pakistan", 30.4, 69.3, "pakistan, pakistani, islamabad"),
    ("Kashmir", 34.1, 74.8, "kashmir"),
    ("Afghanistan", 33.9, 67.7, "afghanistan, afghan, taliban, kabul"),
    ("Sudan", 15.5, 30.2, "sudan, sudanese, khartoum, darfur"),
    ("Congo", -2.9, 23.6, "congo, congolese, kinshasa, goma"),
    ("Sahel", 15.0, 0.0, "sahel, mali, niger, burkina"),
    ("Somalia", 5.2, 46.2, "somalia, somali, al-shabab"),
    ("Ethiopia", 9.1, 40.5, "ethiopia, ethiopian, tigray"),
    ("Libya", 26.3, 17.2, "libya, libyan, tripoli"),
    ("Venezuela", 7.0, -66.0, "venezuela, venezuelan, maduro, caracas"),
    ("Mexico", 23.6, -102.5, "mexico, mexican, cartel, cartels"),
    ("Colombia", 4.6, -74.1, "colombia, colombian"),
    ("Haiti", 19.0, -72.3, "haiti, haitian"),
    ("Cuba", 21.5, -79.0, "cuba, cuban, havana"),
    ("Panama", 8.5, -80.0, "panama"),
    ("Canada", 56.0, -106.0, "canada, canadian, ottawa"),
    ("Greenland", 72.0, -40.0, "greenland"),
    ("Serbia & Kosovo", 43.5, 20.9, "serbia, serbian, kosovo"),
    ("Armenia & Azerbaijan", 40.2, 46.0, "armenia, azerbaijan, nagorno"),
    ("Georgia", 42.3, 43.4, "tbilisi"),
    ("Belarus", 53.7, 28.0, "belarus, lukashenko, minsk"),
    ("Poland & Baltics", 54.5, 22.5, "poland, polish, baltic, lithuania, latvia, estonia"),
    ("Europe / NATO", 50.8, 4.4, "nato, brussels, european union"),
]

TENSE = re.compile(
    r"\b(war|wars|strikes?|airstrikes?|missiles?|drones?|troops|invasion|invade[sd]?|ceasefire|truce|"
    r"sanctions?|tariffs?|clash(es|ed)?|attacks?|attacked|military|nuclear|border|conflict|coup|"
    r"protests?|blockade|tensions?|escalat\w*|shelling|bomb\w*|killed|hostages?|offensive|navy|warships?|"
    r"rebels?|militants?|insurgents?|uprising|crackdown|standoff|retaliat\w*)\b",
    re.I,
)
_PLACE_RES = [(name, lat, lon, re.compile(r"\b(" + "|".join(re.escape(w.strip()) for w in words.split(",")) + r")\b", re.I))
              for name, lat, lon, words in PLACES]
# "south china sea" alone should not count for China itself
_SEA = re.compile(r"south china sea", re.I)


def tensions(store, hours=TENSION_HOURS):
    """[(name, lat, lon, stories, a headline)], most covered first."""
    seen, out = set(), {}
    for a in store.news_since(int(time.time()) - hours * 3600):
        key = a["title"].lower().strip()
        if key in seen:  # the same story in two panels counts once
            continue
        seen.add(key)
        text = f"{a['title']} {a.get('summary', '')[:300]}"
        if not TENSE.search(text):
            continue
        for name, lat, lon, rx in _PLACE_RES:
            if rx.search(_SEA.sub("", text) if name == "China" else text):
                hit = out.setdefault(name, [name, lat, lon, 0, a["title"], a["published"]])
                hit[3] += 1
                if a["published"] > hit[5]:
                    hit[4], hit[5] = a["title"], a["published"]
    return sorted((tuple(h[:5]) for h in out.values()), key=lambda h: -h[3])


class WorldThread(QThread):
    """The wars (Wikipedia), Ukraine's front line (DeepStateMap) and the sides of the wars
    in `wanted` (names), one request at a time. Only ever run when he presses Refresh."""
    done = pyqtSignal(object, object, object)  # conflicts or None, front or None, {name: (article, sides)}

    def __init__(self, wanted=(), known=(), kinds=("wars", "sides", "front")):
        super().__init__()
        self.wanted, self.known, self.kinds = list(wanted), list(known), set(kinds)

    def run(self):
        conflicts = front = None
        if "wars" in self.kinds:
            t0 = time.monotonic()
            try:
                conflicts = world.fetch_conflicts()
                refreshmenu.took("wars", time.monotonic() - t0)
            except Exception:  # offline or Wikipedia busy: keep what the map has
                conflicts = None
        if "front" in self.kinds:
            t0 = time.monotonic()
            try:
                front = world.fetch_front()
                refreshmenu.took("front", time.monotonic() - t0)
            except Exception:
                front = None
        sides = {}
        wanted = [cf for cf in conflicts or self.known if cf["name"] in self.wanted] if "sides" in self.kinds else []
        t0 = time.monotonic()
        for cf in wanted:  # from the list it already had, if Wikipedia didn't answer
            article, found = world.factions_for(cf)
            if article or found:
                sides[cf["name"]] = (article, found)
        if wanted:
            refreshmenu.took("sides", (time.monotonic() - t0) / len(wanted))
        self.done.emit(conflicts, front, sides)


# --- the window --------------------------------------------------------------------------

class RefreshCard(QWidget):
    """'Refresh your feeds?': the pages to check, ticked as last time. It used to be a
    pop-up over the news; here it just waits until he wants it."""

    chosen = pyqtSignal(list)  # page ids to refresh

    def __init__(self, ui, pages, ticked):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(6)
        self.status = ui.label("", ui.body(11.5), T.SOFT, wrap=True)
        lay.addWidget(self.status)
        lay.addSpacing(4)
        self.boxes = []
        grid = QHBoxLayout()
        cols = [QVBoxLayout(), QVBoxLayout()]
        for i, page in enumerate(pages):
            box = QCheckBox(page["title"])
            box.setChecked(page["id"] in ticked)
            box.setCursor(Qt.CursorShape.PointingHandCursor)
            box.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            self.boxes.append((page["id"], box))
            cols[i % 2].addWidget(box)
        for c in cols:
            c.addStretch()
            grid.addLayout(c)
        lay.addLayout(grid)
        lay.addWidget(ui.label("Right Now uses the stories from the other pages.", ui.body(10.5), T.META))
        lay.addSpacing(8)
        buttons = QHBoxLayout()
        all_btn = ui.Button("Tick all", "ghost", small=True)
        all_btn.clicked.connect(lambda: [b.setChecked(True) for _, b in self.boxes])
        buttons.addWidget(all_btn)
        buttons.addStretch()
        buttons.addWidget(ui.label("Refresh is at the top right, by the clock.", ui.body(10.5), T.META))
        lay.addLayout(buttons)

    def ticked(self):
        return [pid for pid, b in self.boxes if b.isChecked()]


class ControlPanel(QWidget):
    def __init__(self, window, ui):
        super().__init__(None)
        self.window, self.ui = window, ui
        self.setWindowTitle("F-117 · Control Panel")
        self.setWindowIcon(window.windowIcon())
        self.setStyleSheet(ui.APP_STYLE)
        self.resize(1500, 820)
        outer = QVBoxLayout(self)
        outer.setContentsMargins(32, 14, 32, 20)
        outer.setSpacing(14)

        top = QHBoxLayout()  # one slim line, so the tabs below have room for Spotify / YouTube
        top.addWidget(ui.label("F-117", ui.caps(10, 1.8), T.ACCENT.name()), 0, Qt.AlignmentFlag.AlignBottom)
        top.addSpacing(10)
        top.addWidget(ui.label("CONTROL PANEL", ui.heading(22, 3), T.TEXT_BRIGHT))
        top.addSpacing(40)
        # the big card's tabs live up here, clear of a borrowed app's window edge (which
        # would catch clicks meant for them) and leaving the app the whole card
        self.tab = ui.Segmented([("world", "World"), ("show", "Breaking Points"), ("youtube", "YouTube")], "world")
        self.tab.changed.connect(self.switch)
        top.addWidget(self.tab)
        top.addStretch()
        self.clock = ui.label("", ui.heading(26, 2), T.TEXT_BRIGHT)
        top.addWidget(self.clock)
        top.addSpacing(14)
        # the one Refresh: nothing much refreshes by itself; it says when fresh data would help
        self.refresh_btn = ui.Button("⟳  Refresh", "ghost")
        self.refresh_btn.clicked.connect(lambda: window.refresh_everything(self.refresh_btn))
        top.addWidget(self.refresh_btn)
        outer.addLayout(top)

        row = QHBoxLayout()
        row.setSpacing(22)
        left = QVBoxLayout()
        left.setSpacing(22)

        weather = ui.Card()
        wl = QVBoxLayout(weather)
        wl.setContentsMargins(26, 22, 26, 22)
        wl.setSpacing(6)
        wl.addWidget(ui.TagChip("Weather"))
        self.w_place = ui.label("", ui.caps(10.5, 1.6), T.META)
        wl.addWidget(self.w_place)
        now = QHBoxLayout()
        self.w_temp = ui.label("—", ui.heading(54, 1), T.TEXT_BRIGHT)
        now.addWidget(self.w_temp)
        now.addSpacing(10)
        nowtext = QVBoxLayout()
        self.w_sky = ui.label("Checking the sky…", ui.heading(20, 1.5), T.TEXT)
        self.w_more = ui.label("", ui.body(11.5), T.SOFT, wrap=True)
        nowtext.addStretch()
        nowtext.addWidget(self.w_sky)
        nowtext.addWidget(self.w_more)
        nowtext.addStretch()
        now.addLayout(nowtext, 1)
        wl.addLayout(now)
        self.w_days = QHBoxLayout()
        self.w_days.setSpacing(10)
        wl.addLayout(self.w_days)
        weather.setFixedWidth(470)
        left.addWidget(weather)

        refresh = ui.Card()
        rl = QVBoxLayout(refresh)
        rl.setContentsMargins(26, 22, 26, 22)
        rl.setSpacing(6)
        rl.addWidget(ui.TagChip("Feeds"))
        rl.addWidget(ui.label("What Refresh checks", ui.heading(22, 1.5), T.TEXT_BRIGHT))
        ticked = ui.PROFILE.get("refresh_pages")
        pages = window.tabs_with_feeds
        self.feeds = RefreshCard(ui, pages, [t["id"] for t in pages] if ticked is None else ticked)
        self.feeds.chosen.connect(window.refresh_pages)
        rl.addWidget(self.feeds)
        self.loading = ui.LoadBar()
        rl.addWidget(self.loading)
        refresh.setFixedWidth(470)
        left.addWidget(refresh)
        left.addStretch()
        row.addLayout(left)

        tension = ui.Card()
        tl = QVBoxLayout(tension)
        tl.setContentsMargins(26, 22, 26, 18)
        tl.setSpacing(6)
        self.stack = QStackedWidget()
        tl.addWidget(self.stack, 1)

        world_tab = QWidget()
        wl2 = QVBoxLayout(world_tab)
        wl2.setContentsMargins(0, 4, 0, 0)
        wl2.setSpacing(6)
        wl2.addWidget(ui.label("The world · click a country", ui.heading(22, 1.5), T.TEXT_BRIGHT))
        self.t_note = ui.label("", ui.body(11), T.META, wrap=True)
        wl2.addWidget(self.t_note)
        self.map = WorldMap()
        wl2.addWidget(self.map, 1)
        self.t_list = ui.label("", ui.body(11.5), T.SOFT, wrap=True)
        wl2.addWidget(self.t_list)
        self.stack.addWidget(world_tab)

        show = QWidget()
        sl = QVBoxLayout(show)
        sl.setContentsMargins(0, 4, 0, 0)
        sl.setSpacing(6)
        top_row = QHBoxLayout()
        info = QVBoxLayout()
        info.setSpacing(4)
        self.ep_when = ui.label("Looking for the latest episode…", ui.caps(10.5, 1.6), T.META)
        info.addWidget(self.ep_when)
        self.ep_title = ui.label("", ui.heading(20, 1.2), T.TEXT_BRIGHT, wrap=True)
        self.ep_title.setMinimumHeight(self.ep_title.fontMetrics().lineSpacing() * 2 + 4)  # wrapped labels get squeezed
        info.addWidget(self.ep_title)
        top_row.addLayout(info, 1)
        buttons = QVBoxLayout()
        self.watch_btn = ui.Button("Watch latest", "primary")
        self.watch_btn.clicked.connect(lambda: self.borrow("show", self.episode["uri"] if self.episode else f"spotify:show:{SHOW}"))
        buttons.addWidget(self.watch_btn)
        all_btn = ui.Button("All episodes", "ghost", small=True)
        all_btn.clicked.connect(lambda: self.borrow("show", f"spotify:show:{SHOW}"))
        buttons.addWidget(all_btn)
        top_row.addLayout(buttons)
        self.headers = {"show": QWidget()}
        self.headers["show"].setLayout(top_row)
        top_row.setContentsMargins(0, 0, 0, 0)
        sl.addWidget(self.headers["show"])
        self.frames = {"show": self.app_frame("Spotify plays here. Press Watch latest: it opens in your Spotify app\n"
                                              "and fits into this space. Choose World and it tucks itself away.")}
        sl.addWidget(self.frames["show"], 1)
        self.stack.addWidget(show)

        yt = QWidget()
        yl = QVBoxLayout(yt)
        yl.setContentsMargins(0, 4, 0, 0)
        yl.setSpacing(6)
        yrow = QHBoxLayout()
        ytext = QVBoxLayout()
        ytext.setSpacing(4)
        ytext.addWidget(ui.label("YOUR YOUTUBE", ui.caps(10.5, 1.6), T.META))
        ytext.addWidget(ui.label("Your home screen and subscriptions, in Chromium", ui.heading(20, 1.2), T.TEXT_BRIGHT))
        yrow.addLayout(ytext, 1)
        yt_btn = ui.Button("Open YouTube", "primary")
        yt_btn.clicked.connect(lambda: self.borrow("youtube"))
        yrow.addWidget(yt_btn, 0, Qt.AlignmentFlag.AlignTop)
        self.headers["youtube"] = QWidget()
        self.headers["youtube"].setLayout(yrow)
        yrow.setContentsMargins(0, 0, 0, 0)
        yl.addWidget(self.headers["youtube"])
        self.frames["youtube"] = self.app_frame("YouTube opens here, signed in as you. Choose World and it tucks itself away.")
        yl.addWidget(self.frames["youtube"], 1)
        self.stack.addWidget(yt)
        row.addWidget(tension, 1)
        self.episode, self.ep_thread = None, None
        self.world_thread, self.world_at = None, 0.0
        self.guests = {"show": SPOTIFY_CLASS, "youtube": YOUTUBE_CLASS}  # tab -> its app's window
        self.borrowed = set()  # tabs whose app he has opened
        self.current = "world"
        self.expand_after_fit = False
        self.fit_tries = 0
        self.fitter = QTimer(self, interval=500, timeout=self.fit_guest)
        outer.addLayout(row, 1)

        self.tick = QTimer(self, interval=10000, timeout=self.show_time)
        self.tick.start()
        self.show_time()
        self.weather_timer = QTimer(self, interval=WEATHER_EVERY, timeout=self.check_weather)
        self.weather_timer.start()
        self.weather_thread = None
        self.check_weather()
        self.map.chosen_changed = window.update_refresh_buttons
        conflicts, front, factions, read = world.load_cache()
        self.map.set_world(conflicts, front, read, factions)
        self.update_map()
        self.set_feed_status(None)

    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), T.BG)
        p.setOpacity(0.5)
        p.drawTiledPixmap(self.rect(), T.grain())

    def show_time(self):
        self.clock.setText(datetime.now().strftime("%I:%M %p").lstrip("0"))

    # weather
    def check_weather(self):
        if self.weather_thread and self.weather_thread.isRunning():
            return
        self.weather_thread = WeatherThread(self.ui.PROFILE)
        self.weather_thread.done.connect(self.show_weather)
        self.weather_thread.start()

    def show_weather(self, w):
        if isinstance(w, str):
            if self.w_temp.text() == "—":
                self.w_sky.setText("Weather unavailable")
                self.w_more.setText("No answer from the weather service. It tries again in 30 minutes.")
            return
        cur, daily = w["current"], w["daily"]
        self.w_place.setText(w["place"].upper())
        self.w_temp.setText(f"{round(cur['temperature_2m'])}°")
        self.w_sky.setText(CODES.get(cur["weather_code"], "—"))
        self.w_more.setText(f"Feels like {round(cur['apparent_temperature'])}° · wind {round(cur['wind_speed_10m'])} mph"
                            f" · humidity {cur['relative_humidity_2m']}%")
        while self.w_days.count():
            item = self.w_days.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        for i, day in enumerate(daily["time"][:4]):
            name = "Today" if i == 0 else datetime.fromisoformat(day).strftime("%a")
            box = QVBoxLayout()
            cell = QWidget()
            cell.setLayout(box)
            box.setContentsMargins(0, 8, 0, 0)
            box.setSpacing(2)
            box.addWidget(self.ui.label(name.upper(), self.ui.caps(10, 1.4), T.META))
            box.addWidget(self.ui.label(f"{round(daily['temperature_2m_max'][i])}° / {round(daily['temperature_2m_min'][i])}°",
                                        self.ui.heading(16, 1), T.TEXT))
            rain = daily["precipitation_probability_max"][i]
            sky = CODES.get(daily["weather_code"][i], "")
            box.addWidget(self.ui.label(sky + (f" · {rain}%" if rain else ""), self.ui.body(10), T.SOFT, wrap=True))
            self.w_days.addWidget(cell, 1)

    # Breaking Points
    def check_episode(self):
        if self.ep_thread and self.ep_thread.isRunning():
            return
        self.ep_thread = EpisodeThread()
        self.ep_thread.done.connect(self.show_episode)
        self.ep_thread.start()

    def show_episode(self, ep):
        if isinstance(ep, str):
            if self.episode is None:
                self.ep_when.setText("COULDN'T REACH SPOTIFY")
                self.ep_title.setText("Watch latest opens the show instead.")
            return
        self.episode = ep
        day = ep["when"].strftime("%A, %B %d").replace(" 0", " ").upper()
        self.ep_when.setText(f"LATEST EPISODE · {day} · {ep['minutes']} MIN")
        self.ep_title.setText(ep["title"])

    def app_frame(self, hint):
        """The space a borrowed app's window is fitted over."""
        frame = QFrame()
        frame.setStyleSheet(f"background: #07090c; border: 1px solid {T.EDGE.name()};")
        hold = QVBoxLayout(frame)
        hold.addWidget(self.ui.label(hint, self.ui.body(11.5), T.META), 0, Qt.AlignmentFlag.AlignCenter)
        return frame

    def switch(self, which):
        self.tab.set_current(which)
        self.current = which
        self.stack.setCurrentIndex(["world", "show", "youtube"].index(which))
        self.fitter.stop()
        for tab, pattern in self.guests.items():  # tuck away the apps of the other tabs
            win = find_window(pattern) if tab != which and tab in self.borrowed else None
            if win and win["workspace"]["name"] != "special:minimized":
                hypr(f"movetoworkspacesilent special:minimized,address:{win['address']}")
        if which == "show":
            self.check_episode()
        if which == "youtube" and "youtube" not in self.borrowed:
            self.borrow("youtube")  # YouTube is what this tab is for: open it straight away
        elif which in self.borrowed:
            self.fit_tries = 0
            self.fitter.start()  # bring it back into its spot
        if which in self.headers and which not in self.borrowed:
            self.headers[which].show()

    def borrow(self, tab, uri=None):
        """Open this tab's app (or find it if it is open already) and fit it in."""
        if tab == "show":
            open_in_spotify(uri)
            self.expand_after_fit = uri.startswith("spotify:episode:")  # a show page has nothing playing
        elif find_window(YOUTUBE_CLASS) is None:
            open_youtube()
        self.borrowed.add(tab)
        self.headers[tab].hide()  # the app gets all the room under the tabs (Spotify won't go below ~600px)
        self.fit_tries = 0
        self.fitter.start()  # an app can take a few seconds to open

    def fit_guest(self):
        """Put the current tab's app window exactly over its frame."""
        self.fit_tries += 1
        pattern, frame = self.guests.get(self.current), self.frames.get(self.current)
        win = find_window(pattern) if pattern else None
        me = next((c for c in hypr_clients() if c.get("title") == self.windowTitle()), None)
        if win is None or me is None:
            if self.fit_tries > 40 or pattern is None:
                self.fitter.stop()
                if pattern is not None and win is None:  # he closed it: back to the tab's own header
                    self.borrowed.discard(self.current)
                    self.headers[self.current].show()
            return
        self.fitter.stop()
        expand, self.expand_after_fit = self.current == "show" and self.expand_after_fit, False
        bar = title_bar()
        top_left = frame.mapTo(self, frame.rect().topLeft())
        x, y = me["at"][0] + top_left.x(), me["at"][1] + top_left.y() + bar
        w, h = frame.width(), frame.height() - bar
        a = f"address:{win['address']}"
        hypr(f"movetoworkspacesilent {me['workspace']['id']},{a}", f"setfloating {a}",
             f"resizewindowpixel exact {w} {h},{a}", f"movewindowpixel exact {x} {y},{a}", f"focuswindow {a}",
             f"alterzorder top,{a}")  # in front of the panel
        if expand:  # once Spotify has settled into its new size and loaded the episode
            QTimer.singleShot(1800, lambda: threading.Thread(target=expand_now_playing, daemon=True).start())

    # the map
    def update_map(self):
        spots = tensions(self.window.store)
        self.map.set_spots(spots)
        when = datetime.now().strftime("%I:%M %p").lstrip("0")
        self.t_note.setText(f"Blue countries have an ongoing war (darker = deadlier, from Wikipedia; minor skirmishes untinted). Dots are places "
                            f"named in conflict stories over the past {TENSION_HOURS // 24} days: bigger means more stories, "
                            f"not more danger. Worked out {when}, after each refresh.")
        self.map.set_cities(world.conflict_cities(self.window.store, self.map.cities, TENSE, None))
        if spots:
            self.t_list.setText("   ·   ".join(f"{s[0]} {s[3]}" for s in spots[:10]))
        else:
            self.t_list.setText("No tension in the stories on file. Refresh the feeds to look again.")

    def refresh_world(self, kinds=("wars", "sides", "front")):
        """The wars, the front line, and the sides of the chosen country's wars (if any)."""
        if self.world_thread and self.world_thread.isRunning():
            return
        wanted = [cf["name"] for cf in self.map.missing()]
        if self.map.chosen is not None:  # a fresh look at the country he is looking at
            wanted += [cf["name"] for cf in sorted(self.map.chosen["conflicts"], key=lambda cf: cf["rank"])[:4]]
        self.world_at = time.time()
        self.world_thread = WorldThread(dict.fromkeys(wanted), self.map.conflicts, kinds)
        self.world_thread.done.connect(self.got_world)
        self.world_thread.start()

    def got_world(self, conflicts, front, sides):
        self.map.set_world(conflicts if conflicts is not None else self.map.conflicts,
                           front if front is not None else self.map.front,
                           datetime.now() if conflicts is not None else self.map.read_at, sides)
        world.save_cache(self.map.conflicts, self.map.front, self.map.factions, self.map.read_at)
        self.window.update_refresh_buttons()

    # feeds
    def set_feed_status(self, text):
        if text is None:
            last = self.window.store.last_fetched()
            when = f"Last refreshed {self.ui.ago(last)}." if last else "Nothing has been fetched yet."
            text = f"{when} Tick the pages the Refresh button (top right) should check."
        self.feeds.status.setText(text)

    def closeEvent(self, e):
        super().closeEvent(e)
        self.window.close()  # one app: closing either screen closes both


# --- filling the screens ---------------------------------------------------------------------

def hyprland_monitors():
    if not shutil.which("hyprctl"):
        return None
    try:
        out = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=3)
        mons = json.loads(out.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
    return mons or None


def title_bar():
    """How tall Hyprland draws window title bars (the hyprbars plugin), 0 without them.
    The bar sits above the window, so the window must start that much lower."""
    try:
        out = subprocess.run(["hyprctl", "-j", "getoption", "plugin:hyprbars:bar_height"],
                             capture_output=True, text=True, timeout=3)
        return int(json.loads(out.stdout).get("int", 0))
    except (OSError, ValueError, AttributeError, subprocess.SubprocessError):
        return 0


def usable(mon):
    """A Hyprland monitor's area without its bars (in layout pixels)."""
    scale = mon.get("scale", 1) or 1
    left, top, right, bottom = mon.get("reserved", [0, 0, 0, 0])
    w, h = round(mon["width"] / scale), round(mon["height"] / scale)
    return mon["x"] + left, mon["y"] + top, w - left - right, h - top - bottom


def layout(main_name=None):
    """[(title, workspace id, x, y, w, h)] for the two windows under Hyprland, or None:
    the news on the biggest screen, the control panel on the biggest other one, both
    leaving the bars visible and room above for the window's own title bar."""
    mons = hyprland_monitors()
    if not mons:
        return None
    main = max(mons, key=lambda m: (m["width"] * m["height"], m["name"] == main_name))
    others = sorted((m for m in mons if m is not main), key=lambda m: -m["width"] * m["height"])
    jobs = [("F-117", main)] + ([("F-117 · Control Panel", others[0])] if others else [])
    bar = title_bar()
    out = []
    for title, mon in jobs:
        x, y, w, h = usable(mon)
        out.append((title, (mon.get("activeWorkspace") or {}).get("id"), x, y + bar, w, h - bar))
    return out


def rules_before_opening():
    """Tell Hyprland, before either window exists, where each one goes, how big it is and
    that it starts invisible. Without this a new window shows up for a moment wherever
    Hyprland puts it, then jumps (his complaint, 2026-10-26). The start-up then fades
    them in (see_through). Rules last for this Hyprland session; adding them again on
    the next start is harmless."""
    spots = layout()
    if not spots:
        return
    cmds = []
    for title, ws, x, y, w, h in spots:
        effects = ["float true", f"move {x} {y}", f"size {w} {h}", "opacity 0.0 override"]
        if ws is not None:
            effects.append(f"workspace {ws} silent")
        cmds.append(f"keyword windowrule {', '.join(effects)}, match:title ^({re.escape(title)})$")
    subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)], capture_output=True, timeout=5)


def place(window, panel):
    """The news fills the main screen and the control panel the biggest other one, both
    leaving the bars visible. Under Hyprland (where Qt cannot place windows, and the
    Glade floats every window at its own size) it is asked to; elsewhere they are maximised."""
    main_name = window.screen().name() if window.screen() else None
    mons = hyprland_monitors()
    if mons:
        # the news goes on the biggest screen (not wherever the mouse happened to be);
        # between equal screens, the one it opened on
        main = max(mons, key=lambda m: (m["width"] * m["height"], m["name"] == main_name))
        others = sorted((m for m in mons if m is not main), key=lambda m: -m["width"] * m["height"])
        jobs = [("F-117", main)] + ([("F-117 · Control Panel", others[0])] if others else [])
        bar = title_bar()
        batch = []
        for title, mon in jobs:
            x, y, w, h = usable(mon)
            y, h = y + bar, h - bar  # room above for the window's own bar (minimise, close)
            sel = f"title:^({re.escape(title)})$"
            ws = (mon.get("activeWorkspace") or {}).get("id")
            if ws is not None:  # its own screen's workspace, or it only shows there by overhanging
                batch.append(f"dispatch movetoworkspacesilent {ws},{sel}")
            batch += [f"dispatch setfloating {sel}", f"dispatch resizewindowpixel exact {w} {h},{sel}",
                      f"dispatch movewindowpixel exact {x} {y},{sel}"]
        subprocess.run(["hyprctl", "--batch", " ; ".join(batch)], capture_output=True, timeout=5)
        return
    from PyQt6.QtGui import QGuiApplication

    screens = QGuiApplication.screens()
    window.showMaximized()
    others = [s for s in screens if s is not window.screen()]
    if others:
        big = max(others, key=lambda s: s.size().width() * s.size().height())
        if panel.windowHandle() is not None:
            panel.windowHandle().setScreen(big)
        panel.setGeometry(big.availableGeometry())
        panel.showMaximized()
