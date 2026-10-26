"""What Refresh fetches, as a checklist (his request, 2026-10-26).

Pressing Refresh opens this little list under the button: each kind of information with
about how long it takes to fetch, ticked as he left it last time. None of it uses Claude
tokens (only the Brief buttons do, and they ask first), so the list is about time.

The times start as guesses and then follow how long each kind really took (a running
average kept in the data folder).
"""

import json

from PyQt6.QtCore import QPoint, Qt
from PyQt6.QtWidgets import QCheckBox, QFrame, QHBoxLayout, QLabel, QVBoxLayout

from . import theme as T
from .store import data_dir

# kind -> (what it is, first guess in seconds)
KINDS = {
    "news": ("News from the ticked pages", 8.0),
    "pictures": ("Pictures beside the headlines", 6.0),
    "wars": ("World map: the list of wars", 3.0),
    "sides": ("Who is fighting, for the zoomed-in country", 2.5),
    "front": ("Ukraine's front line", 2.0),
    "weather": ("Weather", 1.0),
}


def _path():
    return data_dir() / "refresh-times.json"


def times():
    try:
        return json.loads(_path().read_text())
    except (OSError, ValueError):
        return {}


def took(kind, seconds):
    """Remember how long a kind took (a running average, so one slow day doesn't stick)."""
    t = times()
    old = t.get(kind)
    t[kind] = round(seconds if old is None else old * 0.6 + seconds * 0.4, 1)
    try:
        _path().write_text(json.dumps(t))
    except OSError:
        pass


def guess(kind, count=1):
    base = times().get(kind, KINDS[kind][1])
    return base * (count if kind == "sides" else 1)


def say(seconds):
    return "under 1 s" if seconds < 1 else f"~{round(seconds)} s" if seconds < 60 else f"~{round(seconds / 60)} min"


class RefreshMenu(QFrame):
    """The checklist, shown under the Refresh button that was pressed."""

    def __init__(self, window, ui):
        super().__init__(None, Qt.WindowType.Popup)
        self.window, self.ui = window, ui
        self.setStyleSheet(ui.APP_STYLE + f"RefreshMenu {{ background: {T.CARD_TOP.name()}; border: 1px solid {T.EDGE_HI.name()}; }}")
        lay = QVBoxLayout(self)
        lay.setContentsMargins(18, 14, 18, 14)
        lay.setSpacing(8)
        lay.addWidget(ui.label("WHAT TO FETCH", ui.caps(10, 1.6), T.ACCENT.name()))
        self.boxes, self.rows = {}, {}
        for kind, (text, _) in KINDS.items():
            row = QHBoxLayout()
            box = QCheckBox(text)
            box.setCursor(Qt.CursorShape.PointingHandCursor)
            box.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            box.toggled.connect(self.update_total)
            row.addWidget(box, 1)
            when = QLabel()
            when.setFont(T.font(T.MONO, 10))
            when.setStyleSheet(f"color: {T.META}; background: transparent;")
            row.addWidget(when)
            lay.addLayout(row)
            self.boxes[kind], self.rows[kind] = box, when
        self.note = ui.label("", ui.body(10.5), T.META, wrap=True)
        lay.addWidget(self.note)
        lay.addWidget(ui.label("None of this uses Claude tokens. Only the Brief buttons do, and they ask first.",
                               ui.body(10), T.SOFT, wrap=True))
        buttons = QHBoxLayout()
        cancel = ui.Button("Cancel", "ghost", small=True)
        cancel.clicked.connect(self.close)
        buttons.addWidget(cancel)
        buttons.addStretch()
        self.go = ui.Button("Fetch", "primary")
        self.go.clicked.connect(self.fetch)
        buttons.addWidget(self.go)
        lay.addLayout(buttons)
        self.setFixedWidth(470)

    def open_under(self, button):
        w, ui = self.window, self.ui
        ticked = (ui.PROFILE.get("refresh_kinds") or list(KINDS))
        pages = w.panel.feeds.ticked() if w.panel is not None else (ui.PROFILE.get("refresh_pages") or [])
        wars = w.panel.map.missing() if w.panel is not None else []
        chosen = w.panel.map.chosen if w.panel is not None else None
        n_sources = sum(len(c["sources"]) for t in w.tabs if t["id"] in pages for c in t["panels"])
        for kind, box in self.boxes.items():
            box.setChecked(kind in ticked)
            count = 1
            label = KINDS[kind][0]
            if kind == "news":
                label = f"News from {len(pages)} ticked page{'s' * (len(pages) != 1)} ({n_sources} sources)"
                box.setEnabled(bool(pages))
            elif kind == "pictures":
                box.setEnabled(bool(pages))
            elif kind == "sides":
                if chosen is not None:
                    n = len(sorted(chosen["conflicts"], key=lambda cf: cf["rank"])[:4])
                    count = max(n, 1)
                    label = f"Who is fighting in {chosen['name']} ({n} war{'s' * (n != 1)})"
                    box.setChecked(box.isChecked() or bool(wars))  # what he zoomed in for
                box.setEnabled(chosen is not None and bool(chosen["conflicts"]))
            box.setText(label)
            self.rows[kind].setText(say(guess(kind, count)))
            self.rows[kind].count = count
        why = w.refresh_reason()
        self.note.setText(f"Suggested now: {why}." if why else "Everything is fairly fresh.")
        self.update_total()
        self.adjustSize()
        pos = button.mapToGlobal(QPoint(button.width() - self.width(), button.height() + 6))
        self.move(pos)
        self.show()

    def picked(self):
        return [k for k, b in self.boxes.items() if b.isChecked() and b.isEnabled()]

    def update_total(self):
        # the news and the world data are fetched side by side, so the wait is the longest
        # strand, not the sum
        news = sum(guess(k) for k in ("news", "pictures") if k in self.picked())
        world = sum(guess(k, getattr(self.rows[k], "count", 1)) for k in ("wars", "sides", "front") if k in self.picked())
        total = max(news, world, guess("weather") if "weather" in self.picked() else 0)
        self.go.setText(f"Fetch · {say(total)}" if self.picked() else "Fetch")
        self.go.setEnabled(bool(self.picked()))

    def fetch(self):
        kinds = self.picked()
        self.window.update_profile(refresh_kinds=[k for k, b in self.boxes.items() if b.isChecked()])
        self.close()
        self.window.run_refresh(kinds)
