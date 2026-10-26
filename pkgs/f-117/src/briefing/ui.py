"""The F-117 window (the app's name; "Briefing Room" is its tagline).

Layout: a sidebar on the left lists the pages (and, under the open page, its
categories); the main area shows one page at a time as a grid of raised cards,
or one category on its own as a full list. HEADLINES / BRIEFING switches between
the stories and the AI briefings.
"""

import html
import json
import socket
import sys
import threading
import time
from datetime import date, datetime
from pathlib import Path

from PyQt6.QtCore import (
    QDate,
    QEasingCurve,
    QObject,
    QPointF,
    QPropertyAnimation,
    QRectF,
    QSize,
    Qt,
    QThread,
    QTimer,
    QUrl,
    pyqtSignal,
)
from PyQt6.QtGui import (
    QGuiApplication,
    QColor,
    QDesktopServices,
    QFont,
    QIcon,
    QLinearGradient,
    QPainter,
    QPen,
    QPixmap,
    QPolygonF,
)
from PyQt6.QtWidgets import (
    QMessageBox,
    QDateEdit,
    QFrame,
    QGraphicsDropShadowEffect,
    QGraphicsOpacityEffect,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QPlainTextEdit,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)

from . import ai
from . import profile as profile_store
from .boot import BootDirector
from . import pictures
from . import refreshmenu
from . import world
from .panel import ControlPanel
from .worldmap import WorldMap
from .panel import place as place_windows
from .panel import Fader, app_addresses, raise_windows, see_through
from .gamepad import Gamepad
from . import theme as T
from .feeds import fetch_all
from .store import Store, data_dir, today_start
from .summary import WINDOWS, coverage, quality_order, summarize
from .summary import _terms as terms

# Your own pages and feeds: a sources.json in the data folder (~/.local/share/briefing-room)
# replaces the blank-slate one shipped with the app. Copy that one there to start.
SOURCES_FILE = data_dir() / "sources.json"
if not SOURCES_FILE.exists():
    SOURCES_FILE = Path(__file__).resolve().parent.parent / "sources.json"
CARD_ROWS = 4  # stories per card: fewer, each with a summary you can read in place
# His preferences (My Focus page). Reloaded whenever he changes them.
PROFILE = profile_store.load()
PERIODS = [("day", "Past day"), ("week", "Past week"), ("month", "Past month")]
AHEAD = {"day": "next day", "week": "next 7 days", "month": "next 30 days"}
SIDEBAR_W = 320
CARD_MIN_W = 520

APP_STYLE = f"""
QScrollArea, QScrollArea > QWidget > QWidget {{ background: transparent; border: none; }}
QScrollBar:vertical {{ background: transparent; width: 10px; margin: 4px 2px; }}
QScrollBar::handle:vertical {{ background: {T.EDGE_HI.name()}; min-height: 40px; border-radius: 3px; }}
QScrollBar::handle:vertical:hover {{ background: {T.AMBER_DIM.name()}; }}
QScrollBar:horizontal {{ background: transparent; height: 10px; margin: 2px 4px; border: none; }}
QScrollBar::handle:horizontal {{ background: {T.EDGE_HI.name()}; min-width: 60px; border-radius: 3px; }}
QScrollBar::handle:horizontal:hover {{ background: {T.AMBER_DIM.name()}; }}
QScrollBar::add-line, QScrollBar::sub-line, QScrollBar::add-page, QScrollBar::sub-page
    {{ background: none; height: 0; width: 0; border: none; }}
QToolTip {{ background: #1d2026; color: {T.TEXT}; border: 1px solid {T.EDGE_HI.name()};
    padding: 8px; font-family: "{T.BODY}"; font-size: 10.5pt; }}
QLineEdit, QDateEdit {{ background: #0e1013; color: {T.TEXT}; border: 1px solid {T.EDGE_HI.name()};
    padding: 8px 10px; font-family: "{T.BODY}"; font-size: 11pt;
    selection-background-color: {T.AMBER_DIM.name()}; }}
QLineEdit:focus, QDateEdit:focus {{ border-color: {T.AMBER.name()}; }}
QPlainTextEdit, QSpinBox {{ background: #0e1013; color: {T.TEXT}; border: 1px solid {T.EDGE_HI.name()};
    padding: 8px 10px; font-family: "{T.BODY}"; font-size: 11.5pt;
    selection-background-color: {T.AMBER_DIM.name()}; }}
QPlainTextEdit:focus, QSpinBox:focus {{ border-color: {T.AMBER.name()}; }}
QCheckBox {{ color: {T.TEXT}; font-family: "{T.BODY}"; font-size: 12.5pt; spacing: 12px; padding: 6px 0; }}
QCheckBox::indicator {{ width: 20px; height: 20px; border: 1.5px solid {T.AMBER.name()}; background: #0e1013; }}
QCheckBox::indicator:checked {{ background: {T.AMBER.name()}; image: none; }}
QCheckBox:hover {{ color: {T.TEXT_BRIGHT}; }}
QDateEdit::drop-down {{ border: none; width: 20px; }}
QCalendarWidget QWidget {{ background: #15181c; color: {T.TEXT}; font-size: 10.5pt; }}
QCalendarWidget QAbstractItemView {{ selection-background-color: {T.AMBER.name()};
    selection-color: #0b1622; }}
"""


# ---------------------------------------------------------------- small helpers


def ago(ts, now=None):
    secs = max(0, int((now or time.time()) - ts))
    if secs < 120:
        return "just now"
    if secs < 3600:
        return f"{secs // 60}m ago"
    if secs < 86400:
        return f"{secs // 3600}h ago"
    if secs < 86400 * 14:
        return f"{secs // 86400}d ago"
    return datetime.fromtimestamp(ts).strftime("%b %d")


def day_word(d):
    days = (d - date.today()).days
    if days == 0:
        return "Today"
    if days == 1:
        return "Tomorrow"
    if 1 < days < 7:
        return d.strftime("%A")
    return d.strftime("%a %b %d")


def event_when(ts):
    dt = datetime.fromtimestamp(ts)
    when = day_word(dt.date())
    if dt.hour or dt.minute:
        when += ", " + dt.strftime("%I:%M %p").lstrip("0")
    return when


def is_video(article):
    return article["link"].startswith("https://www.youtube.com/")


def open_link(url):
    if url:
        QDesktopServices.openUrl(QUrl(url))


def label(text, fnt, color, wrap=False):
    lab = QLabel(text)
    lab.setFont(fnt)
    lab.setStyleSheet(f"color: {color}; background: transparent;")
    lab.setWordWrap(wrap)
    return lab


def rich_label(text, fnt, color=T.TEXT):
    lab = label(text, fnt, color, wrap=True)
    lab.setTextFormat(Qt.TextFormat.RichText)
    lab.setOpenExternalLinks(False)
    lab.linkActivated.connect(open_link)
    return lab


def body(size, weight=QFont.Weight.Normal):
    return T.font(T.BODY, size, weight)


def heading(size, spacing=1.5):
    return T.font(T.DISPLAY, size, QFont.Weight.Bold, spacing)


def caps(size=9.5, spacing=1.4):
    """Small uppercase label font (tags, section names)."""
    return T.font(T.MONO, size, spacing=spacing)


def clear_layout(layout):
    while layout.count():
        item = layout.takeAt(0)
        if item.widget():
            item.widget().deleteLater()
        elif item.layout():
            clear_layout(item.layout())


def scroll_area():
    scroll = QScrollArea()
    scroll.setWidgetResizable(True)
    scroll.setFrameShape(QFrame.Shape.NoFrame)
    scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
    return scroll


def jet_pixmap(size, color=QColor("#aab1bb")):
    pix = QPixmap(size, size)
    pix.fill(Qt.GlobalColor.transparent)
    p = QPainter(pix)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    rect = QRectF(0, size * 0.08, size, size * 0.84)
    pts = [QPointF(rect.left() + x * rect.width(), rect.top() + y * rect.height()) for x, y in T.JET_OUTLINE]
    p.setPen(Qt.PenStyle.NoPen)
    # two halves in different greys, like light catching the facets
    p.setBrush(color.lighter(115))
    p.drawPolygon(QPolygonF([pts[0], pts[5], pts[6], pts[7], pts[8], pts[9]]))
    p.setBrush(color.darker(135))
    p.drawPolygon(QPolygonF([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5]]))
    p.end()
    return pix


# ---------------------------------------------------------------- building blocks


class Backdrop(QWidget):
    """Window background: big faint facets, like the jet's flat panels."""

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        w, h = self.width(), self.height()
        p.fillRect(self.rect(), T.BG)
        p.setPen(QPen(QColor("#15181c"), 1))
        for i, facet in enumerate(T.BACKDROP_FACETS):
            p.setBrush(QColor(T.FACET_SHADES[i % len(T.FACET_SHADES)]))
            p.drawPolygon(QPolygonF([QPointF(x * w, y * h) for x, y in facet]))
        p.drawTiledPixmap(self.rect(), T.grain())


class Button(QPushButton):
    """Angular button. 'primary' = solid amber, 'outline' = amber outline,
    'ghost' = grey outline."""

    def __init__(self, text, kind="ghost", small=False):
        super().__init__(text)
        self.kind = kind
        self.h = 32 if small else 40
        self.setFont(T.font(T.DISPLAY, 11 if small else 12.5, QFont.Weight.Bold, 1.6))
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedHeight(self.h)
        self.setFlat(True)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)

    def sizeHint(self):
        return QSize(self.fontMetrics().horizontalAdvance(self.text()) + (30 if self.h < 36 else 44), self.h)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        path = T.chamfer(QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5), 8)
        hover, down = self.underMouse(), self.isDown() or self.isChecked()
        if not self.isEnabled():
            fill, edge, fg = QColor(0, 0, 0, 0), T.EDGE_HI, QColor(T.META)
        elif self.kind == "primary":
            fill = T.AMBER.lighter(110) if hover else T.AMBER
            edge, fg = T.AMBER, T.DARK_ON_AMBER
        elif self.kind == "outline":
            fill = T.AMBER if (hover or down) else T.AMBER_BG
            edge, fg = T.AMBER, T.DARK_ON_AMBER if (hover or down) else T.AMBER
        else:
            fill = T.ROW_HOVER if hover else QColor(255, 255, 255, 10)
            edge = QColor("#6a7380") if hover else T.EDGE_HI
            fg = QColor(T.TEXT_BRIGHT if hover else T.TEXT)
        p.fillPath(path, fill)
        p.setPen(QPen(edge, 1))
        p.drawPath(path)
        p.setPen(fg)
        p.setFont(self.font())
        p.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, self.text())


class Segmented(QWidget):
    """A row of joined choices, one lit up in amber."""

    changed = pyqtSignal(str)

    def __init__(self, options, current):
        super().__init__()
        self.options, self.current = options, current
        self.setFont(T.font(T.DISPLAY, 12, QFont.Weight.Bold, 1.4))
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setMouseTracking(True)
        self.hover = None
        fm = self.fontMetrics()
        self.widths = [fm.horizontalAdvance(text) + 40 for _, text in options]
        self.setFixedSize(sum(self.widths), 40)

    def set_current(self, key):
        self.current = key
        self.update()

    def _index_at(self, x):
        acc = 0
        for i, w in enumerate(self.widths):
            acc += w
            if x < acc:
                return i
        return len(self.widths) - 1

    def mouseMoveEvent(self, e):
        self.hover = self._index_at(e.position().x())
        self.update()

    def leaveEvent(self, e):
        self.hover = None
        self.update()

    def mouseReleaseEvent(self, e):
        key = self.options[self._index_at(e.position().x())][0]
        if key != self.current:
            self.current = key
            self.update()
            self.changed.emit(key)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        outer = T.chamfer(QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5), 9)
        p.fillPath(outer, QColor(255, 255, 255, 8))
        x = 0
        p.setFont(self.font())
        for i, ((key, text), w) in enumerate(zip(self.options, self.widths)):
            r = QRectF(x, 0, w, self.height())
            p.save()
            p.setClipPath(outer)
            if key == self.current:
                p.fillRect(r, T.AMBER)
            elif i == self.hover:
                p.fillRect(r, T.ROW_HOVER)
            p.restore()
            p.setPen(T.DARK_ON_AMBER if key == self.current else QColor(T.TEXT))
            p.drawText(r, Qt.AlignmentFlag.AlignCenter, text)
            if i and key != self.current and self.options[i - 1][0] != self.current:
                p.setPen(QPen(T.EDGE_HI, 1))
                p.drawLine(QPointF(x, 8), QPointF(x, self.height() - 8))
            x += w
        p.setPen(QPen(T.EDGE_HI, 1))
        p.drawPath(outer)


class TagChip(QLabel):
    """Small amber label on a tinted plate, e.g. 'SUBSCRIBED'."""

    def __init__(self, text):
        super().__init__(text.upper())
        self.setFont(caps(9.5, 1.6))
        self.setStyleSheet(f"color: {T.AMBER.name()}; background: transparent; padding: 3px 9px;")
        self.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.fillPath(T.chamfer(QRectF(self.rect()), 5, "tl br"), T.AMBER_BG)
        p.end()
        super().paintEvent(e)


class Card(QFrame):
    """A raised, faceted card: lit along its top edge, darker toward the
    bottom, sliced corners and a soft shadow underneath."""

    CUT = 16

    def __init__(self):
        super().__init__()
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(28)
        shadow.setOffset(0, 8)
        shadow.setColor(QColor(0, 0, 0, 170))
        self.setGraphicsEffect(shadow)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5)
        path = T.chamfer(r, self.CUT)
        grad = QLinearGradient(0, r.top(), 0, r.bottom())
        grad.setColorAt(0, T.CARD_TOP)
        grad.setColorAt(min(1.0, 220 / max(r.height(), 1)), T.CARD_BOTTOM)
        grad.setColorAt(1, T.CARD_BOTTOM)
        p.fillPath(path, grad)
        p.save()
        p.setClipPath(path)
        p.setOpacity(0.7)
        p.drawTiledPixmap(self.rect(), T.grain())
        p.restore()
        p.setPen(QPen(T.EDGE, 1))
        p.drawPath(path)
        # lit top edge, like light on a facet
        p.setPen(QPen(T.BEVEL, 1))
        p.drawLine(QPointF(r.left() + self.CUT, r.top() + 0.5), QPointF(r.right() - 1, r.top() + 0.5))
        p.setPen(QPen(T.AMBER, 3))
        p.drawLine(QPointF(r.left() + self.CUT + 2, r.top() + 1.5), QPointF(r.left() + self.CUT + 56, r.top() + 1.5))


class CardHeader(QWidget):
    """Tag chip, big title, one-line description, and room on the right."""

    title_clicked = pyqtSignal()

    def __init__(self, cfg, right_text="", clickable=False):
        super().__init__()
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(12)
        left = QVBoxLayout()
        left.setSpacing(4)
        chip_row = QHBoxLayout()
        chip_row.setSpacing(10)
        chip_row.addWidget(TagChip(cfg["tag"]))
        if right_text:
            chip_row.addWidget(label(right_text, body(10), T.META))
        chip_row.addStretch()
        left.addLayout(chip_row)
        self.title = label(cfg["title"], heading(19, 1.2), T.TEXT_BRIGHT)
        if clickable:
            self.title.setCursor(Qt.CursorShape.PointingHandCursor)
            self.title.setToolTip("Open this category on its own")
            self.title.mousePressEvent = lambda e: self.title_clicked.emit()
        left.addWidget(self.title)
        if cfg.get("subtitle"):
            left.addWidget(label(cfg["subtitle"], body(10.5), T.SOFT, wrap=True))
        lay.addLayout(left, 1)
        self.right = QVBoxLayout()
        self.right.setSpacing(6)
        lay.addLayout(self.right)


class Thumb(QWidget):
    """A small square picture with the app's cut corner and a thin edge."""

    def __init__(self, image, size):
        super().__init__()
        self.pix = QPixmap.fromImage(image)
        self.setFixedSize(size, size)

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        r = QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5)
        path = T.chamfer(r, 7)
        p.setClipPath(path)
        p.drawPixmap(self.rect(), self.pix)
        p.setClipping(False)
        p.setPen(QPen(T.EDGE_HI, 1))
        p.drawPath(path)


class ArticleRow(QWidget):
    """One story. The lead story of a card is bigger and shows a snippet."""

    clicked = pyqtSignal(dict)

    def __init__(self, article, lead=False, new_face=False):
        super().__init__()
        self.article, self.lead = article, lead
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setAttribute(Qt.WidgetAttribute.WA_Hover)
        outer = QHBoxLayout(self)
        outer.setContentsMargins(22, 12 if lead else 9, 12, 12 if lead else 9)
        outer.setSpacing(14)
        lay = QVBoxLayout()
        lay.setSpacing(5 if lead else 3)
        outer.addLayout(lay, 1)
        img = PICTURES.get(pictures.key(article["title"]))
        if img is not None:  # the person in the headline, or the story's own picture
            outer.addWidget(Thumb(img, 64 if lead else 48), 0, Qt.AlignmentFlag.AlignTop)
        if lead:
            self.title = label(article["title"], body(14.5, QFont.Weight.DemiBold), T.TEXT_BRIGHT, wrap=True)
        else:
            self.title = label(article["title"], body(12), T.TEXT, wrap=True)
        self.title.setTextInteractionFlags(Qt.TextInteractionFlag.NoTextInteraction)
        lay.addWidget(self.title)
        if article["summary"] and not article.get("event_at") and not article["summary"].startswith("Article URL:"):
            # he reads in place rather than clicking, so every story gets its gist
            limit = 300 if lead else 190
            snippet = article["summary"]
            if len(snippet) > limit:
                snippet = snippet[:limit].rsplit(" ", 1)[0] + "…"
            lay.addWidget(label(snippet, body(11 if lead else 10.5), T.SOFT, wrap=True))

        if article.get("event_at"):
            soon = article["event_at"] < today_start() + 2 * 86400
            when = event_when(article["event_at"])
            meta = f"<b style='color:{T.AMBER.name() if soon else T.SOFT}'>{when}</b>&nbsp;&nbsp;·&nbsp;&nbsp;{html.escape(article['source'])}"
        else:
            video = f"<span style='color:{T.AMBER.name()}'>▶ Video</span>&nbsp;&nbsp;·&nbsp;&nbsp;" if is_video(article) else ""
            meta = f"{video}{html.escape(article['source'])}&nbsp;&nbsp;·&nbsp;&nbsp;{ago(article['published'])}"
            if new_face:
                meta = f"<b style='color:{T.AMBER.name()}'>★ New face</b>&nbsp;&nbsp;·&nbsp;&nbsp;" + meta
        self.meta = label(meta, body(10), T.META)
        self.meta.setTextFormat(Qt.TextFormat.RichText)
        lay.addWidget(self.meta)
        self.setToolTip("")
        self.refresh_look()

    def refresh_look(self, hover=False):
        if hover:
            color = T.TEXT_BRIGHT
        elif self.article["seen"]:
            color = T.META
        else:
            color = T.TEXT_BRIGHT if self.lead else T.TEXT
        self.title.setStyleSheet(f"color: {color}; background: transparent;")

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self.rect().contains(event.position().toPoint()):
            self.article["seen"] = 1
            self.refresh_look()
            self.update()
            self.clicked.emit(self.article)

    def enterEvent(self, e):
        self.refresh_look(hover=True)
        self.update()

    def leaveEvent(self, e):
        self.refresh_look()
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.underMouse():
            p.fillRect(self.rect(), T.ROW_HOVER)
            p.fillRect(0, 0, 3, self.height(), T.AMBER)
        if not self.article["seen"]:
            # unread: amber diamond beside the headline
            cy = 22.0 if self.lead else 18.0
            cx, s = 10.0, 4.2
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(T.AMBER)
            p.drawPolygon(QPolygonF([QPointF(cx, cy - s), QPointF(cx + s, cy), QPointF(cx, cy + s), QPointF(cx - s, cy)]))
        p.setPen(QPen(QColor("#262b32"), 1))
        p.drawLine(14, self.height() - 1, self.width() - 10, self.height() - 1)


def empty_note(text):
    note = label(text, body(11), T.META, wrap=True)
    note.setContentsMargins(4, 10, 4, 10)
    return note


# ---------------------------------------------------------------- headline cards


class HeadlineCard(Card):
    """A category on a page: its top story large, a few more, and 'See all'."""

    def __init__(self, window, cfg, articles, full=False, status=""):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 18)
        lay.setSpacing(10)
        events = cfg.get("kind") == "events"
        if events:
            soon = sum(1 for a in articles if a.get("event_at") and a["event_at"] < today_start() + 7 * 86400)
            right = f"{soon} this week" if articles else ""
        else:
            fresh = sum(1 for a in articles if time.time() - a["published"] < 86400)
            right = f"{fresh} new today" if articles else ""
        header = CardHeader(cfg, right, clickable=not full)
        header.title_clicked.connect(lambda: window.open_category(cfg["id"]))
        lay.addWidget(header)
        if articles and not events and cfg.get("order") != "newest":
            note = label("Top stories — ranked by how widely they're covered", body(10), T.META)
            lay.addWidget(note)

        rows = QVBoxLayout()
        rows.setSpacing(0)
        shown = articles if full else articles[:CARD_ROWS]
        if not shown:
            rows.addWidget(empty_note(status or cfg.get("empty") or "Nothing here yet — it fills in on the next sync."))
        known = window.store.seen_before(cfg["id"], today_start()) if cfg["id"] in ("trending", "most-read") else None
        for i, a in enumerate(shown):
            new_face = known is not None and a.get("person") and a["title"].lower() not in known
            row = ArticleRow(a, lead=(i == 0), new_face=new_face)
            row.clicked.connect(window.open_article)
            rows.addWidget(row)
        lay.addLayout(rows)
        lay.addStretch()
        if not full and len(articles) > CARD_ROWS:
            more = Button(f"See all {len(articles)}  →", "ghost", small=True)
            more.clicked.connect(lambda: window.open_category(cfg["id"]))
            lay.addWidget(more, 0, Qt.AlignmentFlag.AlignLeft)


def in_horizon(todo):
    """Undated reminders always show; dated ones only within the next 3 months,
    or a year if marked important."""
    if not todo["due"]:
        return True
    days = (date.fromisoformat(todo["due"]) - date.today()).days
    return days <= (PROFILE["important_days"] if todo.get("important") else PROFILE["horizon_days"])


class StoryColumn(Card):
    """A further column of stories when a category is opened on its own."""

    def __init__(self, window, heading_text, articles):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 18)
        lay.setSpacing(4)
        lay.addWidget(label(heading_text.upper(), caps(9.5, 1.8), T.ACCENT.name()))
        for a in articles:
            row = ArticleRow(a)
            row.clicked.connect(window.open_article)
            lay.addWidget(row)
        lay.addStretch()


class TodoRow(QWidget):
    toggled = pyqtSignal(int, bool)
    deleted = pyqtSignal(int)
    starred = pyqtSignal(int, bool)

    BOX = 20

    def __init__(self, todo):
        super().__init__()
        self.todo = todo
        self.setAttribute(Qt.WidgetAttribute.WA_Hover)
        lay = QHBoxLayout(self)
        lay.setContentsMargins(44, 10, 10, 10)
        lay.setSpacing(12)
        done = bool(todo["done"])
        text = html.escape(todo["text"])
        if done:
            text = f"<s>{text}</s>"
        col = QVBoxLayout()
        col.setSpacing(3)
        col.addWidget(rich_label(text, body(12), T.META if done else T.TEXT))
        if todo["due"]:
            due = date.fromisoformat(todo["due"])
            days = (due - date.today()).days
            soon = days <= 3 and not done
            when = day_word(due) if days < 7 else due.strftime("%A %b %d")
            col.addWidget(label(f"Due {when}", body(10, QFont.Weight.DemiBold), T.AMBER.name() if soon else T.META))
        lay.addLayout(col, 1)
        star = Button("★" if todo.get("important") else "☆", "outline" if todo.get("important") else "ghost", small=True)
        star.setToolTip("Important: shows up to a year ahead instead of 3 months")
        star.clicked.connect(lambda: self.starred.emit(todo["id"], not todo.get("important")))
        lay.addWidget(star, 0, Qt.AlignmentFlag.AlignTop)
        if todo["link"]:
            go = Button("Open ↗", "ghost", small=True)
            go.setToolTip(todo["link"])
            go.clicked.connect(lambda: open_link(todo["link"]))
            lay.addWidget(go, 0, Qt.AlignmentFlag.AlignTop)
        if not todo["key"]:
            rm = Button("✕", "ghost", small=True)
            rm.setToolTip("Remove this reminder")
            rm.clicked.connect(lambda: self.deleted.emit(todo["id"]))
            lay.addWidget(rm, 0, Qt.AlignmentFlag.AlignTop)
        self.setToolTip("Click the box to tick this off")

    def box_rect(self):
        return QRectF(12, 12, self.BOX, self.BOX)

    def mouseReleaseEvent(self, event):
        if event.position().x() < 40:
            self.toggled.emit(self.todo["id"], not self.todo["done"])

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.underMouse():
            p.fillRect(self.rect(), T.ROW_HOVER)
        r = self.box_rect()
        path = T.chamfer(r, 5, "tl br")
        if self.todo["done"]:
            p.fillPath(path, T.AMBER)
            p.setPen(QPen(T.DARK_ON_AMBER, 2.4))
            p.drawPolyline(QPolygonF([QPointF(r.left() + 4.5, r.center().y()), QPointF(r.center().x() - 1, r.bottom() - 5), QPointF(r.right() - 4, r.top() + 4.5)]))
        else:
            p.fillPath(path, QColor(255, 255, 255, 12))
            p.setPen(QPen(T.AMBER, 1.6))
            p.drawPath(path)
        p.setPen(QPen(QColor("#262b32"), 1))
        p.drawLine(14, self.height() - 1, self.width() - 10, self.height() - 1)


class ChecklistCard(Card):
    def __init__(self, window, cfg, full=False):
        super().__init__()
        self.window, self.cfg, self.store = window, cfg, window.store
        everything = self.store.todos()
        todos = [t for t in everything if in_horizon(t)]
        later = len(everything) - len(todos)
        open_items = [t for t in todos if not t["done"]]
        soon = sum(1 for t in open_items if t["due"] and (date.fromisoformat(t["due"]) - date.today()).days <= 3)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 18)
        lay.setSpacing(10)
        header = CardHeader(cfg, f"{len(open_items)} open · {soon} due soon", clickable=not full)
        header.title_clicked.connect(lambda: window.open_category(cfg["id"]))
        lay.addWidget(header)

        add = QHBoxLayout()
        add.setSpacing(8)
        self.entry = QLineEdit()
        self.entry.setPlaceholderText("Add a reminder…")
        self.entry.returnPressed.connect(self.add)
        self.due = QDateEdit()
        self.due.setCalendarPopup(True)
        self.due.setDisplayFormat("ddd MMM d")
        none = QDate.currentDate().addDays(-1)
        self.due.setMinimumDate(none)
        self.due.setSpecialValueText("No date")  # shown while the date sits at the minimum
        self.due.setDate(none)
        self.due.setFixedWidth(130)
        self.due.setToolTip("Optional due date")
        btn = Button("Add", "primary", small=True)
        btn.clicked.connect(self.add)
        add.addWidget(self.entry, 1)
        add.addWidget(self.due)
        add.addWidget(btn)
        lay.addLayout(add)

        rows = QVBoxLayout()
        rows.setSpacing(0)
        shown = todos if full else open_items[:CARD_ROWS]
        if not shown:
            rows.addWidget(empty_note("All done. Nice."))
        for todo in shown:
            row = TodoRow(todo)
            row.toggled.connect(self.toggle)
            row.deleted.connect(self.delete)
            row.starred.connect(self.star)
            rows.addWidget(row)
        lay.addLayout(rows)
        if later:
            lay.addWidget(label(f"{later} more reminder{'s' if later > 1 else ''} further out — hidden until they're within {PROFILE['horizon_days']} days", body(10), T.META, wrap=True))
        lay.addStretch()
        hidden = len(todos) - len(shown)
        if not full and hidden:
            more = Button(f"See all {len(todos)} (incl. done)  →", "ghost", small=True)
            more.clicked.connect(lambda: window.open_category(cfg["id"]))
            lay.addWidget(more, 0, Qt.AlignmentFlag.AlignLeft)

    def add(self):
        text = self.entry.text().strip()
        if not text:
            return
        due = None if self.due.date() == self.due.minimumDate() else self.due.date().toString("yyyy-MM-dd")
        self.store.add_todo(text, due)
        QTimer.singleShot(0, lambda: self.window.render(keep_scroll=True))

    def toggle(self, todo_id, done):
        self.store.set_todo_done(todo_id, done)
        QTimer.singleShot(0, lambda: self.window.render(keep_scroll=True))

    def delete(self, todo_id):
        self.store.delete_todo(todo_id)
        QTimer.singleShot(0, lambda: self.window.render(keep_scroll=True))

    def star(self, todo_id, important):
        self.store.set_todo_important(todo_id, important)
        QTimer.singleShot(0, lambda: self.window.render(keep_scroll=True))


class HorizonCard(Card):
    """Right Now's 'Coming Up': dated reminders in the next 3 months (a year for
    important ones), soonest first."""

    def __init__(self, window, cfg):
        super().__init__()
        todos = [t for t in window.store.todos() if not t["done"] and t["due"] and in_horizon(t)]
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 18)
        lay.setSpacing(8)
        header = CardHeader(cfg, f"{len(todos)} date{'s' if len(todos) != 1 else ''}")
        lay.addWidget(header)
        if not todos:
            lay.addWidget(empty_note(f"Nothing dated in the next {PROFILE['horizon_days']} days."))
        for t in todos[:6]:
            d = date.fromisoformat(t["due"])
            days = (d - date.today()).days
            soon = days <= 3
            star = "★ " if t.get("important") else ""
            when = day_word(d) if days < 7 else d.strftime("%a %b %d")
            text = (
                f"<b style='color:{T.AMBER.name() if soon else T.SOFT}; font-size:10.5pt'>{star}{when}"
                f"{'' if days < 2 else f' · in {days} days'}</b><br>{html.escape(t['text'])}"
            )
            item = rich_label(text, body(12))
            item.setContentsMargins(0, 4, 0, 8)
            lay.addWidget(item)
        go = Button("Open checklist  →", "ghost", small=True)
        checklist = next((c["id"] for c in window.panels if c.get("kind") == "checklist"), None)
        if checklist:
            go.clicked.connect(lambda: window.open_category(checklist))
        lay.addStretch()
        lay.addWidget(go, 0, Qt.AlignmentFlag.AlignLeft)


# ---------------------------------------------------------------- AI briefings


class BriefingThread(QThread):
    done = pyqtSignal(object, object, str)  # job, briefing or None, error

    def __init__(self, job):
        super().__init__()
        self.job = job

    def run(self):
        job = self.job
        try:
            data = ai.write_briefing(job["tab"], job["panel_articles"], job["period"], job["overview"])
            self.done.emit(job, data, "")
        except ai.BriefingError as exc:
            self.done.emit(job, None, str(exc))
        except Exception as exc:  # never let a briefing crash the window
            self.done.emit(job, None, f"Unexpected problem: {exc}"[:300])


class Briefer(QObject):
    """Runs AI briefings one at a time, only when he asks for one.

    Results are stored per category ("panel:<id>") and per page ("tab:<id>",
    which holds the overview)."""

    changed = pyqtSignal()

    def __init__(self, store):
        super().__init__()
        self.store = store
        self.queue, self.thread = [], None
        self.errors = {}  # (scope, period) -> message

    def request(self, tab, panels, period, panel_articles):
        overview = len(panels) > 1
        scopes = [f"panel:{p['id']}" for p in panels] + ([f"tab:{tab['id']}"] if overview else [])
        if any(self.busy(s, period) for s in scopes):
            return
        for s in scopes:
            self.errors.pop((s, period), None)
        self.queue.append(
            {"tab": tab, "panels": panels, "period": period, "panel_articles": panel_articles,
             "overview": overview, "scopes": scopes}
        )
        self.next()
        self.changed.emit()

    def next(self):
        if self.thread and self.thread.isRunning() or not self.queue:
            return
        self.thread = BriefingThread(self.queue.pop(0))
        self.thread.done.connect(self.finished)
        self.thread.start()

    def finished(self, job, data, error):
        period = job["period"]
        if data:
            by_id = {p.get("id"): p for p in data.get("panels", [])}
            for cfg in job["panels"]:
                if cfg["id"] in by_id:
                    self.store.save_briefing(f"panel:{cfg['id']}", period, by_id[cfg["id"]])
            if job["overview"]:
                self.store.save_briefing(f"tab:{job['tab']['id']}", period, {"overview": data.get("overview", "")})
        else:
            for s in job["scopes"]:
                self.errors[(s, period)] = error
        self.thread = None
        self.next()
        self.changed.emit()

    def busy(self, scope, period):
        jobs = self.queue + ([self.thread.job] if self.thread else [])
        return any(scope in j["scopes"] and j["period"] == period for j in jobs)

    def error(self, scope, period):
        return self.errors.get((scope, period))


def explain(error):
    if error == "NOT_LOGGED_IN":
        return (
            "AI briefings need the Claude program on this computer to be signed in. "
            "Until then you see the built-in summary below."
        )
    return f"Claude couldn't write this one ({error}). Press the button to try again."


def link_line(articles):
    """'Source ↗' links to the stories a point is based on."""
    seen, parts = set(), []
    for a in articles:
        if a["link"] in seen:
            continue
        seen.add(a["link"])
        parts.append(
            f"<a href='{html.escape(a['link'], quote=True)}' style='color:{T.META}; text-decoration:none'>"
            f"{html.escape(a['source'])} ↗</a>"
        )
    return f"<span style='font-size:10pt'>{'&nbsp;&nbsp;·&nbsp;&nbsp;'.join(parts[:4])}</span>"


def section_label(text):
    lab = label(text.upper(), caps(9.5, 1.8), T.AMBER.name())
    lab.setContentsMargins(0, 8, 0, 2)
    return lab


class BriefCard(Card):
    """A category in briefing mode: the AI brief if there is one, otherwise the
    built-in summary, with a BRIEF ME button."""

    def __init__(self, window, cfg, articles, period, full=False):
        super().__init__()
        briefer, store = window.briefer, window.store
        scope = f"panel:{cfg['id']}"
        brief = store.briefing(scope, period)
        busy, error = briefer.busy(scope, period), briefer.error(scope, period)
        events = cfg.get("kind") == "events"

        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 20)
        lay.setSpacing(8)
        sources = {a["source"] for a in articles}
        what = "events" if events else "stories"
        right = f"{len(articles)} {what} · {len(sources)} source{'s' if len(sources) != 1 else ''}" if articles else ""
        header = CardHeader(cfg, right, clickable=not full)
        header.title_clicked.connect(lambda: window.open_category(cfg["id"]))
        lay.addWidget(header)

        if not articles:
            lay.addWidget(empty_note("Nothing in this window."))
            lay.addStretch()
            return

        if busy:
            btn = Button("Writing…", "ghost", small=True)
            btn.setEnabled(False)
        else:
            btn = Button("Rewrite" if brief else "Brief me", "ghost" if brief else "outline", small=True)
            btn.setToolTip("Have Claude read this category and write a short briefing")
            btn.clicked.connect(lambda: window.request_brief([cfg]))
        header.right.addWidget(btn, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)
        header.right.addStretch()

        if busy:
            lay.addWidget(empty_note("Claude is reading these stories and writing a briefing. Usually 10–30 seconds."))
        elif error:
            lay.addWidget(empty_note(explain(error)))

        if brief:
            written = datetime.fromtimestamp(brief["created"]).strftime("%a %I:%M %p").replace(" 0", " ")
            lay.addWidget(label(f"AI briefing · written {written}", body(10), T.META))
            tldr = label(brief.get("tldr", ""), body(13.5, QFont.Weight.DemiBold), T.TEXT_BRIGHT, wrap=True)
            tldr.setContentsMargins(0, 2, 0, 4)
            lay.addWidget(tldr)
            points = brief.get("points", [])
            if points:
                lay.addWidget(section_label("Key points"))
            for point in points:
                text = f"<span style='color:{T.AMBER.name()}'>▸</span>&nbsp; {html.escape(point['text'])}"
                if point.get("articles"):
                    text += f"<br>{link_line(point['articles'])}"
                item = rich_label(text, body(12))
                item.setContentsMargins(0, 3, 0, 6)
                lay.addWidget(item)
        elif events:
            lay.addWidget(section_label("Coming up"))
            for a in [a for a in articles if a.get("event_at")][: 20 if full else 6]:
                row = ArticleRow(a)
                row.clicked.connect(window.open_article)
                lay.addWidget(row)
        else:
            self._offline(window, lay, summarize(articles, period), full)

        if full and not events:
            lay.addWidget(section_label(f"All {len(articles)} stories in this window"))
            for a in articles:
                row = ArticleRow(a)
                row.clicked.connect(window.open_article)
                lay.addWidget(row)
        lay.addStretch()

    def _offline(self, window, lay, result, full):
        lay.addWidget(label("Built-in summary · press Brief me for an AI-written one", body(10), T.META))
        if result["threads"]:
            lay.addWidget(section_label("Talked about most"))
            lay.addWidget(label("   ·   ".join(result["threads"]), heading(14, 1.0), T.TEXT, wrap=True))
        lay.addWidget(section_label("Top stories"))
        for i, a in enumerate(result["picks"][: 7 if full else 4]):
            row = ArticleRow(a, lead=(i == 0))
            row.clicked.connect(window.open_article)
            lay.addWidget(row)


class DueSoonCard(Card):
    """The checklist in briefing mode: what is due in the window."""

    def __init__(self, window, cfg, period):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 20)
        lay.setSpacing(8)
        header = CardHeader(cfg, clickable=True)
        header.title_clicked.connect(lambda: window.open_category(cfg["id"]))
        lay.addWidget(header)
        horizon = date.fromordinal(date.today().toordinal() + WINDOWS[period])
        todos = [t for t in window.store.todos() if not t["done"] and in_horizon(t)]
        due = [t for t in todos if t["due"] and date.fromisoformat(t["due"]) <= horizon]
        undated = len([t for t in todos if not t["due"]])
        lay.addWidget(section_label(f"Due in the {AHEAD[period]}"))
        if not due:
            lay.addWidget(empty_note("Nothing due."))
        for t in due:
            d = date.fromisoformat(t["due"])
            soon = (d - date.today()).days <= 3
            text = (
                f"<span style='color:{T.AMBER.name()}'>▸</span>&nbsp; {html.escape(t['text'])}<br>"
                f"<span style='color:{T.AMBER.name() if soon else T.META}; font-size:10pt'><b>Due {day_word(d)}</b></span>"
            )
            item = rich_label(text, body(12))
            item.setContentsMargins(0, 3, 0, 6)
            lay.addWidget(item)
        if undated:
            lay.addWidget(label(f"+ {undated} reminder{'s' if undated > 1 else ''} with no date", body(10.5), T.META))
        lay.addStretch()


class OverviewCard(Card):
    CUT = 14

    def __init__(self, heading_text, text, muted=False):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(26, 20, 26, 20)
        lay.setSpacing(6)
        lay.addWidget(label(heading_text.upper(), caps(10, 2), T.AMBER.name()))
        lay.addWidget(label(text, body(12.5 if muted else 14, QFont.Weight.Normal if muted else QFont.Weight.Medium),
                            T.SOFT if muted else T.TEXT_BRIGHT, wrap=True))


# ---------------------------------------------------------------- My Focus (preferences)


class ListEditorCard(Card):
    """A list he can add to and remove from (focus statements, muted words)."""

    def __init__(self, tag, title, subtitle, items, placeholder, on_change, empty):
        super().__init__()
        self.items, self.on_change = list(items), on_change
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 20)
        lay.setSpacing(10)
        lay.addWidget(CardHeader({"tag": tag, "title": title, "subtitle": subtitle}, f"{len(items)} item{'s' if len(items) != 1 else ''}"))
        add = QHBoxLayout()
        add.setSpacing(8)
        self.entry = QLineEdit()
        self.entry.setPlaceholderText(placeholder)
        self.entry.returnPressed.connect(self.add)
        btn = Button("Add", "primary", small=True)
        btn.clicked.connect(self.add)
        add.addWidget(self.entry, 1)
        add.addWidget(btn)
        lay.addLayout(add)
        if not items:
            lay.addWidget(empty_note(empty))
        for i, text in enumerate(items):
            row = QHBoxLayout()
            row.setContentsMargins(4, 4, 0, 4)
            row.setSpacing(12)
            row.addWidget(rich_label(f"<span style='color:{T.AMBER.name()}'>▸</span>&nbsp; {html.escape(text)}", body(12)), 1)
            rm = Button("Remove", "ghost", small=True)
            rm.clicked.connect(lambda _=False, n=i: self.remove(n))
            row.addWidget(rm, 0, Qt.AlignmentFlag.AlignTop)
            lay.addLayout(row)
        lay.addStretch()

    def add(self):
        text = self.entry.text().strip()
        if text and text not in self.items:
            self.on_change(self.items + [text])

    def remove(self, index):
        self.on_change(self.items[:index] + self.items[index + 1:])


class AboutCard(Card):
    def __init__(self, window):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 20)
        lay.setSpacing(10)
        lay.addWidget(CardHeader({"tag": "ABOUT ME", "title": "About me",
                                  "subtitle": "A few lines the AI briefings read so they know who they're writing for"}))
        self.text = QPlainTextEdit(PROFILE["about"])
        self.text.setPlaceholderText("e.g. Where you live, what you follow, what you do…")
        self.text.setMinimumHeight(110)
        lay.addWidget(self.text)
        save = Button("Save", "primary", small=True)
        save.clicked.connect(lambda: window.update_profile(about=self.text.toPlainText().strip()))
        lay.addWidget(save, 0, Qt.AlignmentFlag.AlignLeft)
        lay.addStretch()


class AheadCard(Card):
    def __init__(self, window):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 20)
        lay.setSpacing(12)
        lay.addWidget(CardHeader({"tag": "TIME HORIZON", "title": "How far ahead",
                                  "subtitle": "Reminders, events and the AI briefings stop looking ahead after this"}))

        def spin(value, maximum):
            box = QSpinBox()
            box.setRange(7, maximum)
            box.setSuffix(" days")
            box.setValue(value)
            box.setFixedWidth(150)
            return box

        self.normal = spin(PROFILE["horizon_days"], 730)
        self.important = spin(PROFILE["important_days"], 1095)
        for text, box in (("Most things", self.normal), ("Things marked important ★", self.important)):
            row = QHBoxLayout()
            row.addWidget(label(text, body(12), T.TEXT), 1)
            row.addWidget(box)
            lay.addLayout(row)
        save = Button("Save", "primary", small=True)
        save.clicked.connect(lambda: window.update_profile(horizon_days=self.normal.value(), important_days=self.important.value()))
        lay.addWidget(save, 0, Qt.AlignmentFlag.AlignLeft)
        lay.addStretch()


def greeting_text():
    hour = datetime.now().hour
    tod = "morning" if hour < 12 else "afternoon" if hour < 18 else "evening"
    name = PROFILE.get("name", "").strip()
    template = PROFILE.get("greeting") or "Good {time_of_day}{comma_name}."
    try:
        return template.format(time_of_day=tod, name=name, comma_name=f", {name}" if name else "")
    except (KeyError, IndexError, ValueError):
        return template


class GreetingCard(Card):
    def __init__(self, window):
        super().__init__()
        lay = QVBoxLayout(self)
        lay.setContentsMargins(24, 22, 22, 20)
        lay.setSpacing(10)
        lay.addWidget(CardHeader({"tag": "START-UP", "title": "Greeting",
                                  "subtitle": "Shown when Briefing Room starts. {time_of_day} becomes morning, afternoon or evening; {name} becomes your name."}))
        self.name = QLineEdit(PROFILE.get("name", ""))
        self.name.setPlaceholderText("Your name (optional)")
        self.greeting = QLineEdit(PROFILE.get("greeting", ""))
        self.greeting.setPlaceholderText("Good {time_of_day}{comma_name}.")
        for text, box in (("Name", self.name), ("Greeting", self.greeting)):
            row = QHBoxLayout()
            row.addWidget(label(text, body(12), T.TEXT))
            row.addWidget(box, 1)
            lay.addLayout(row)
        lay.addWidget(label(f"Right now it reads:  “{greeting_text()}”", body(11), T.SOFT, wrap=True))
        save = Button("Save", "primary", small=True)
        save.clicked.connect(lambda: window.update_profile(name=self.name.text().strip(), greeting=self.greeting.text().strip() or "Good {time_of_day}{comma_name}."))
        lay.addWidget(save, 0, Qt.AlignmentFlag.AlignLeft)
        lay.addStretch()


# ---------------------------------------------------------------- side-scrolling columns & navigation


class Column(QScrollArea):
    """One card standing as a column in the side-scrolling page. If the card is
    taller than the screen it scrolls up/down inside the column (by moving the
    highlight); the mouse wheel always scrolls the page sideways."""

    def __init__(self, window, card, width, cfg=None, hug=False):
        super().__init__()
        self.window, self.cfg = window, cfg
        self.setWidgetResizable(True)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.setFixedWidth(width)
        holder = QWidget()
        lay = QVBoxLayout(holder)
        lay.setContentsMargins(4, 4, 10, 26)  # room for the card's shadow
        lay.addWidget(card)
        if hug:  # the card only as tall as what it holds
            lay.addStretch(1)
        self.setWidget(holder)
        self.verticalScrollBar().valueChanged.connect(lambda _: window.place_ring())

    def wheelEvent(self, e):
        self.window.page_wheel(e)

    def focusables(self):
        holder = self.widget()
        kinds = (ArticleRow, TodoRow, Button, QLineEdit, QPlainTextEdit, QSpinBox, QDateEdit, Segmented)
        found = [w for w in holder.findChildren(QWidget) if isinstance(w, kinds) and w.isVisibleTo(holder) and w.isEnabled()]
        # a button inside a story/reminder row is its own stop, after the row
        found.sort(key=lambda w: (w.mapTo(holder, QPointF(0, 0).toPoint()).y(), w.mapTo(holder, QPointF(0, 0).toPoint()).x()))
        return found


class FocusRing(QWidget):
    """The glowing outline that shows where the controller / keyboard is."""

    def __init__(self, parent):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        self.hide()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = QRectF(self.rect()).adjusted(3, 3, -3, -3)
        for i, alpha in ((6, 26), (4, 50), (2, 90)):
            c = QColor(T.ACCENT)
            c.setAlpha(alpha)
            p.setPen(QPen(c, i))
            p.drawPath(T.chamfer(r, 8))
        p.setPen(QPen(T.ACCENT, 1.6))
        p.drawPath(T.chamfer(r, 8))


class HintBar(QWidget):
    """Bottom strip listing the controls, console-style. Shows controller
    buttons when a controller is connected, keys otherwise."""

    PAD = [("A", "Open"), ("B", "Back"), ("X", "Headlines / Briefing"), ("Y", "See all · Brief me"),
           ("LB RB", "Page"), ("LT RT", "Scroll"), ("≡", "Refresh"), ("⧉", "My Focus")]
    KEYS = [("← → ↑ ↓", "Move"), ("Enter", "Open"), ("Esc", "Back"), ("Tab", "Next page"),
            ("1–7", "Go to page"), ("B", "Briefing"), ("S", "See all · Brief me"),
            ("R", "Refresh"), ("F", "My Focus")]

    def __init__(self):
        super().__init__()
        self.pad = False
        self.setFixedHeight(46)

    def set_pad(self, on):
        self.pad = on
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(QPen(T.EDGE, 1))
        p.drawLine(0, 0, self.width(), 0)
        x = 4
        key_font = T.font(T.DISPLAY, 10.5, QFont.Weight.Bold, 1)
        text_font = body(10)
        for key, what in (self.PAD if self.pad else self.KEYS):
            p.setFont(key_font)
            kw = p.fontMetrics().horizontalAdvance(key) + 16
            chip = QRectF(x, 12, kw, 22)
            if x + kw > self.width():
                break
            p.fillPath(T.chamfer(chip, 5, "tl br"), T.ACCENT_BG)
            p.setPen(T.ACCENT)
            p.drawText(chip, Qt.AlignmentFlag.AlignCenter, key)
            p.setFont(text_font)
            p.setPen(QColor(T.SOFT))
            tw = p.fontMetrics().horizontalAdvance(what)
            p.drawText(QRectF(x + kw + 8, 12, tw + 4, 22), Qt.AlignmentFlag.AlignVCenter, what)
            x += kw + tw + 30


# ---------------------------------------------------------------- sidebar


class NavItem(QWidget):
    """A page (big) or one of its categories (smaller, indented) in the sidebar."""

    clicked = pyqtSignal()

    def __init__(self, text, number="", count=0, active=False, sub=False):
        super().__init__()
        self.text, self.number, self.count = text, number, count
        self.active, self.sub = active, sub
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setAttribute(Qt.WidgetAttribute.WA_Hover)
        self.setFixedHeight(38 if sub else 50)
        self.text_font = body(11.5) if sub else heading(14, 0.8)
        self.num_font = caps(10, 1)
        self.count_font = T.font(T.BODY, 9.5 if sub else 10, QFont.Weight.Bold)

    def set_count(self, n):
        self.count = n
        self.update()

    def mouseReleaseEvent(self, e):
        self.clicked.emit()

    def enterEvent(self, e):
        self.update()

    def leaveEvent(self, e):
        self.update()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = QRectF(self.rect())
        hover = self.underMouse()
        if self.active:
            p.fillPath(T.chamfer(r.adjusted(0, 2, 0, -2), 8, "br"), QColor("#1d2128") if not self.sub else QColor("#191c22"))
            p.fillRect(QRectF(0, 4, 4, r.height() - 8), T.AMBER)
        elif hover:
            p.fillPath(T.chamfer(r.adjusted(0, 2, 0, -2), 8, "br"), QColor("#14171b"))

        x = 20
        if self.sub:
            x = 46
        elif self.number:
            p.setFont(self.num_font)
            p.setPen(T.AMBER if self.active else QColor(T.META))
            p.drawText(QRectF(16, 0, 30, r.height()), Qt.AlignmentFlag.AlignVCenter, self.number)
            x = 46

        badge_w = 0
        if self.count:
            p.setFont(self.count_font)
            txt = str(self.count) if self.count < 100 else "99+"
            badge_w = max(28, p.fontMetrics().horizontalAdvance(txt) + 16)
            bh = 22 if not self.sub else 20
            badge = QRectF(r.width() - badge_w - 14, (r.height() - bh) / 2, badge_w, bh)
            if self.sub:
                p.fillPath(T.chamfer(badge, 4, "tl br"), QColor(255, 255, 255, 18))
                p.setPen(QColor(T.SOFT))
            else:
                p.fillPath(T.chamfer(badge, 5, "tl br"), T.AMBER if self.active else T.AMBER_BG)
                p.setPen(T.DARK_ON_AMBER if self.active else T.AMBER)
            p.drawText(badge, Qt.AlignmentFlag.AlignCenter, txt)
            badge_w += 18

        p.setFont(self.text_font)
        if self.sub:
            color = T.TEXT_BRIGHT if (self.active or hover) else T.SOFT
        else:
            color = T.TEXT_BRIGHT if (self.active or hover) else T.TEXT
        p.setPen(QColor(color))
        text = self.text if self.sub else self.text.upper()
        avail = r.width() - x - badge_w - 8
        p.drawText(QRectF(x, 0, avail, r.height()), Qt.AlignmentFlag.AlignVCenter,
                   p.fontMetrics().elidedText(text, Qt.TextElideMode.ElideRight, int(avail)))


class Sidebar(QWidget):
    def __init__(self, window):
        super().__init__()
        self.window = window
        self.setFixedWidth(SIDEBAR_W)
        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 22, 0, 18)
        lay.setSpacing(0)

        brand = QHBoxLayout()
        brand.setContentsMargins(20, 0, 16, 0)
        brand.setSpacing(12)
        logo = QLabel()
        logo.setPixmap(jet_pixmap(42))
        brand.addWidget(logo)
        names = QVBoxLayout()
        names.setSpacing(0)
        names.addWidget(label("F-117", heading(30, 6), T.TEXT_BRIGHT))
        names.addWidget(label("BRIEFING ROOM", caps(9.5, 3), T.AMBER.name()))
        brand.addLayout(names)
        brand.addStretch()
        lay.addLayout(brand)
        self.date = label("", body(11), T.SOFT)
        self.date.setContentsMargins(20, 14, 16, 0)
        lay.addWidget(self.date)
        lay.addSpacing(22)

        self.nav_host = QWidget()
        self.nav = QVBoxLayout(self.nav_host)
        self.nav.setContentsMargins(10, 0, 10, 0)
        self.nav.setSpacing(2)
        scroll = scroll_area()
        scroll.setWidget(self.nav_host)
        lay.addWidget(scroll, 1)

        foot = QVBoxLayout()
        foot.setContentsMargins(20, 12, 20, 0)
        foot.setSpacing(10)
        self.status = label("", body(10), T.META, wrap=True)
        foot.addWidget(self.status)
        self.loading = LoadBar()
        foot.addWidget(self.loading)
        self.focus = Button("My Focus  ·  preferences", "outline", small=True)
        self.focus.setToolTip("What Briefing Room pays attention to for you — add or remove anything")
        self.focus.clicked.connect(window.open_prefs)
        foot.addWidget(self.focus)
        lay.addLayout(foot)
        self.tick()

    def tick(self):
        now = datetime.now()
        self.date.setText(now.strftime("%A, %B %d").replace(" 0", " ") + now.strftime("  ·  %I:%M %p").replace(" 0", " "))

    def rebuild(self):
        w = self.window
        clear_layout(self.nav)
        for i, tab in enumerate(w.tabs):
            active_page = i == w.page_index
            item = NavItem(tab["title"], f"{i + 1:02d}", w.unread_page(tab), active=active_page and not w.category and w.view == "pages")
            item.clicked.connect(lambda n=i: w.set_page(n))
            self.nav.addWidget(item)
            if active_page and w.view == "pages":
                for cfg in tab["panels"]:
                    sub = NavItem(cfg["title"], count=w.unread_panel(cfg), active=w.category == cfg["id"], sub=True)
                    sub.clicked.connect(lambda pid=cfg["id"]: w.open_category(pid))
                    self.nav.addWidget(sub)
                self.nav.addSpacing(8)
        self.nav.addStretch()

    def paintEvent(self, _):
        p = QPainter(self)
        p.fillRect(self.rect(), T.SIDEBAR)
        p.drawTiledPixmap(self.rect(), T.grain())
        p.setPen(QPen(T.EDGE, 1))
        p.drawLine(self.width() - 1, 0, self.width() - 1, self.height())


# ---------------------------------------------------------------- page header


class PageHeader(QWidget):
    def __init__(self, window):
        super().__init__()
        self.window = window
        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(16)
        left = QVBoxLayout()
        left.setSpacing(4)
        self.crumb = QLabel()
        self.crumb.setFont(caps(10, 1.8))
        self.crumb.setTextFormat(Qt.TextFormat.RichText)
        self.crumb.linkActivated.connect(lambda _: window.set_page(window.page_index))
        left.addWidget(self.crumb)
        self.title = label("", heading(30, 3), T.TEXT_BRIGHT)
        left.addWidget(self.title)
        self.blurb = label("", body(12), T.SOFT, wrap=True)
        left.addWidget(self.blurb)
        lay.addLayout(left, 1)

        right = QVBoxLayout()
        right.setSpacing(10)
        top = QHBoxLayout()
        top.setSpacing(10)
        top.addStretch()
        self.mode = Segmented([("headlines", "Headlines"), ("brief", "Briefing")], "headlines")
        self.mode.changed.connect(window.set_mode)
        top.addWidget(self.mode)
        top.addSpacing(18)
        self.clock = label("", heading(20, 2), T.TEXT_BRIGHT)
        top.addWidget(self.clock)
        # the one Refresh, beside the clock; it says when fresh data would help
        self.refresh = Button("⟳  Refresh", "ghost")
        self.refresh.clicked.connect(lambda: window.refresh_everything(self.refresh))
        top.addWidget(self.refresh)
        right.addLayout(top)
        bottom = QHBoxLayout()
        bottom.setSpacing(10)
        bottom.addStretch()
        self.period = Segmented(PERIODS, "day")
        self.period.changed.connect(window.set_period)
        bottom.addWidget(self.period)
        self.brief_all = Button("Brief all", "primary")
        self.brief_all.setToolTip("Have Claude brief every category on this page in one go")
        self.brief_all.clicked.connect(window.brief_all)
        bottom.addWidget(self.brief_all)
        right.addLayout(bottom)
        lay.addLayout(right)

    def update_for(self, w):
        tab = w.tabs[w.page_index]
        brief = w.mode == "brief"
        prefs = w.view == "prefs"
        self.mode.setVisible(not prefs)
        if prefs:
            self.period.setVisible(False)
            self.brief_all.setVisible(False)
            self.crumb.setText(f"<span style='color:{T.AMBER.name()}'>PREFERENCES</span>")
            self.crumb.setCursor(Qt.CursorShape.ArrowCursor)
            self.title.setText("MY FOCUS")
            self.blurb.setText("What Briefing Room pays attention to for you. Add or remove anything here — "
                               "the story filters and the AI briefings follow this page.")
            return
        self.mode.set_current(w.mode)
        self.period.set_current(w.period)
        self.period.setVisible(brief)
        if w.category:
            cfg = w.panel_by_id[w.category]
            self.crumb.setText(
                f"<a href='back' style='color:{T.AMBER.name()}; text-decoration:none'>← {html.escape(tab['title'].upper())}</a>"
            )
            self.crumb.setCursor(Qt.CursorShape.PointingHandCursor)
            self.title.setText(cfg["title"].upper())
            self.blurb.setText(cfg.get("subtitle", ""))
            self.brief_all.setVisible(False)
        else:
            self.crumb.setText(f"<span style='color:{T.AMBER.name()}'>PAGE {w.page_index + 1} OF {len(w.tabs)}</span>")
            self.crumb.setCursor(Qt.CursorShape.ArrowCursor)
            self.title.setText(tab["title"].upper())
            self.blurb.setText(tab.get("blurb", ""))
            busy = w.briefer.busy(f"tab:{tab['id']}", w.period)
            self.brief_all.setVisible(brief)
            self.brief_all.setEnabled(not busy)
            self.brief_all.setText("Writing…" if busy else "Brief all")


# ---------------------------------------------------------------- main window


PICTURES = {}  # headline key -> small QImage, from the last refresh (pictures.py)


class LoadBar(QWidget):
    """A thin loading bar with a soft glow at its leading edge. Hidden when idle."""

    def __init__(self):
        super().__init__()
        self.value = 0.0
        self.setFixedHeight(6)
        self.hide()

    def set(self, value):
        self.value = max(self.value, min(1.0, value))  # never runs backwards
        self.show()
        self.update()

    def reset(self):
        self.value = 0.0
        self.hide()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5)
        p.fillPath(T.chamfer(r, 3), QColor(255, 255, 255, 18))
        if self.value > 0:
            done = QRectF(r.left(), r.top(), max(6.0, r.width() * self.value), r.height())
            p.fillPath(T.chamfer(done, 3), T.ACCENT)


def confirm_tokens(parent, what, tokens, stories):
    """Ask before spending Claude tokens. Returns True only on an explicit yes."""
    box = QMessageBox(parent)
    box.setWindowTitle("This uses Claude tokens")
    box.setIcon(QMessageBox.Icon.Question)
    box.setText(f"<b>{html.escape(what)}</b> asks Claude ({ai.MODEL}) to read {stories} stories and write a summary.")
    box.setInformativeText(f"This will use about <b>{tokens:,} tokens</b> of your Claude usage.<br>"
                           "The estimate learns from what earlier briefings really used.")
    go = box.addButton(f"Use ~{tokens:,} tokens", QMessageBox.ButtonRole.AcceptRole)
    box.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
    box.setDefaultButton(box.buttons()[-1])  # Enter alone never spends tokens
    box.setStyleSheet(APP_STYLE + f"QMessageBox {{ background: {T.BG.name()}; }} QLabel {{ color: {T.TEXT}; }}")
    box.exec()
    return box.clickedButton() is go


class FetchThread(QThread):
    done = pyqtSignal(list, list)
    progress = pyqtSignal(float, str)  # 0..1, what it is doing (for the loading bars)

    def __init__(self, panels, with_pictures=True):
        super().__init__()
        self.panels, self.with_pictures = panels, with_pictures
        self.pictures = None

    def run(self):
        # sources are most of the wait; the pictures come after them
        share = 0.8 if self.with_pictures else 1.0
        t0 = time.monotonic()
        articles, errors = fetch_all(
            self.panels, lambda d, n: self.progress.emit(share * d / max(n, 1), f"Checking sources · {d} of {n}"))
        refreshmenu.took("news", time.monotonic() - t0)
        if not self.with_pictures:
            self.done.emit(articles, errors)
            return
        t0 = time.monotonic()
        try:
            self.pictures = pictures.gather(
                articles, lambda d, n: self.progress.emit(0.8 + 0.2 * d / max(n, 1), "Finding pictures…"))
            refreshmenu.took("pictures", time.monotonic() - t0)
        except Exception:  # pictures are a nicety: never let them stop the news
            self.pictures = None
        self.done.emit(articles, errors)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("F-117")
        self.setWindowIcon(QIcon(jet_pixmap(128)))
        self.resize(1640, 1000)
        self.setMinimumSize(1100, 720)

        self.tabs = json.loads(SOURCES_FILE.read_text())["tabs"]
        self.panels = [cfg for tab in self.tabs for cfg in tab["panels"]]
        self.panel_by_id = {cfg["id"]: cfg for cfg in self.panels}
        self.tab_of = {cfg["id"]: i for i, tab in enumerate(self.tabs) for cfg in tab["panels"]}
        self.feed_panels = [cfg for cfg in self.panels if cfg["sources"]]
        self.store = Store()
        self.store.drop_unlisted(
            {
                cfg["id"]: None
                # these name the publisher (or "10,000+ searches") per item, not per source
                if any("news.google.com" in s.get("url", "") or "reddit" in s or "type" in s for s in cfg["sources"])
                else {s["name"] for s in cfg["sources"]}
                for cfg in self.feed_panels
            }
        )
        for cfg in self.panels:
            if cfg.get("kind") == "checklist":
                self.store.seed_todos(cfg.get("items", []))
        self.briefer = Briefer(self.store)
        self.briefer.changed.connect(lambda: self.render(keep_scroll=True))
        self.fetcher = None
        self.errors = []
        self.page_index, self.category = 0, None
        self.view = "pages"  # or "prefs"
        self.mode, self.period = "headlines", "day"
        self.columns = 2
        self.cover = None  # word -> number of outlets covering it; rebuilt after each sync
        self.recent_titles = None

        root = QWidget()
        root.setStyleSheet(APP_STYLE)
        self.setCentralWidget(root)
        outer = QHBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        self.sidebar = Sidebar(self)
        outer.addWidget(self.sidebar)

        self.main = Backdrop()
        main_lay = QVBoxLayout(self.main)
        main_lay.setContentsMargins(36, 26, 22, 0)
        main_lay.setSpacing(20)
        self.header = PageHeader(self)
        self.header.setContentsMargins(0, 0, 14, 0)
        main_lay.addWidget(self.header)
        # the page scrolls left to right
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.scroll.viewport().installEventFilter(self)
        self.scroll.horizontalScrollBar().valueChanged.connect(lambda _: self.place_ring())
        main_lay.addWidget(self.scroll, 1)
        self.hints = HintBar()
        main_lay.addWidget(self.hints)
        outer.addWidget(self.main, 1)
        self.columns_list, self.sel, self.nav_on = [], [0, 0], False
        self.ring = FocusRing(root)
        self.glide = None
        self.gamepad = Gamepad(self)
        self.gamepad.action.connect(self.on_action)
        self.gamepad.connected.connect(self.hints.set_pad)
        self.hints.set_pad(self.gamepad.any_connected())
        QGuiApplication.instance().installEventFilter(self)


        self.clock = QTimer(self, interval=15000, timeout=self.sidebar.tick)
        self.clock.start()
        # Nothing refreshes by itself (his choice, 2026-10-26: "very little data to refresh
        # automatically"); instead the Refresh buttons say when fresh data would help.
        self.nudge = QTimer(self, interval=60 * 1000, timeout=lambda: (self.check_online(), self.update_refresh_buttons()))
        self.nudge.start()
        self.online = True
        self.check_online()
        self.resize_timer = QTimer(self, singleShot=True, interval=120, timeout=self.on_resized)

        self.auto_panels = []  # what the 15-minute timer refreshes (what he ticked)
        self.render(fade=False)
        self.boot_done = False
        self.tabs_with_feeds = [t for t in self.tabs if any(c["sources"] for c in t["panels"])]
        self.panel = None  # the control panel window, made after start-up
        self.menu = None  # the Refresh checklist
        self.update_refresh_buttons()

    def showEvent(self, e):
        super().showEvent(e)
        if not getattr(self, "booted", False):
            self.booted = True
            QTimer.singleShot(0, self.boot)

    def boot(self):
        """Start-up, in the order that keeps the animation smooth (his request, 2026-10-26:
        "luxury and seamless"): first build and place everything, unseen (both windows open
        invisible, panel.rules_before_opening); wait for that to settle; only then put the
        animation up, and start its clock once every screen has drawn a frame. While it
        plays, nothing slow runs here: the app fades in from a background thread."""
        see_through(0.0, ("F-117",))  # the window rule already does this; belt and braces
        WorldMap.starting = True  # the map (its big border files, its breathing dots) waits until it has played
        self.prepare_behind()
        self.settle_from = time.monotonic()
        QTimer.singleShot(150, self.start_when_settled)

    def prepare_behind(self):
        """Make the control panel and put both windows on their screens, still invisible."""
        if self.panel is None:
            self.panel = ControlPanel(self, sys.modules[__name__])
        self.panel.show()
        QGuiApplication.processEvents()  # let both windows map before placing them
        place_windows(self, self.panel)
        see_through(0.0)

    def start_when_settled(self):
        """Placing resizes the windows, which re-lays the page out a moment later; wait
        for that (up to 1.5 s) so it can't steal frames from the animation."""
        busy = self.resize_timer.isActive() or time.monotonic() - getattr(self, "rendered_at", 0) < 0.25
        if busy and time.monotonic() - self.settle_from < 1.5:
            QTimer.singleShot(60, self.start_when_settled)
            return
        n_sources = sum(len(c["sources"]) for c in self.feed_panels)
        todos = [t for t in self.store.todos() if not t["done"] and in_horizon(t)]
        due = sum(1 for t in todos if t["due"] and (date.fromisoformat(t["due"]) - date.today()).days <= 3)
        lines = [
            f"{len(self.tabs)} pages · {n_sources} sources linked",
            f"Archive · {self.store.stats()['stories']:,} stories on file",
            f"Reminders · {due} due in the next 3 days",
            f"Focus profile · {len(PROFILE['focus'])} preferences loaded",
            "Systems online",
        ]
        # one start-up window on every screen, driven as a single display
        screens = QGuiApplication.screens()
        self.director = BootDirector(screens, self.screen(), greeting_text(), lines, [t["title"] for t in self.tabs])
        self.director.finished.connect(self.after_boot)
        self.director.ready.connect(self.play)
        self.director.launch()

    def play(self):
        """Every start-up screen shows its first (dark) frame. Hyprland hides windows behind
        a full-screen one, so the still-invisible app windows go in front of the start-up
        screens, where they can fade in over it; then the clock starts."""
        d = self.director
        if d is None or getattr(self, "playing", False):
            return
        self.playing = True
        see_through(0.0)
        raise_windows("F-117")
        raise_windows("F-117 · Control Panel")
        Fader(app_addresses(), lambda: d.reveal(d.now()) if d.t0 is not None else 0.0).start()
        QTimer.singleShot(30, d.go)  # a beat for Hyprland to settle the order

    def after_boot(self):
        """The news fills this screen and the control panel (panel.py) another, both
        leaving the bars visible, already in place behind the fading animation."""
        self.director = None
        self.boot_done = True
        WorldMap.starting = False
        see_through(1.0)  # in case the fade thread fell behind
        self.activateWindow()
        self.update_refresh_buttons()

    def closeEvent(self, e):
        super().closeEvent(e)
        if self.panel is not None and self.panel.isVisible():
            self.panel.close()

    def refresh_pages(self, page_ids, with_pictures=True):
        if page_ids:
            self.update_profile(refresh_pages=page_ids)
        chosen = set(page_ids)
        self.auto_panels = [c for t in self.tabs if t["id"] in chosen for c in t["panels"] if c["sources"]]
        if self.auto_panels:
            self.refresh(self.auto_panels, with_pictures)
        elif self.panel is not None:
            self.panel.set_feed_status("Nothing ticked, so nothing was checked.")

    # -- navigation

    def current_tab(self):
        return self.tabs[self.page_index]

    def set_page(self, index):
        self.page_index, self.category, self.view = index, None, "pages"
        self.render()

    def open_prefs(self):
        self.view, self.category = "prefs", None
        self.render()

    def update_profile(self, **changes):
        global PROFILE
        PROFILE = {**PROFILE, **changes}
        profile_store.save(PROFILE)
        self.render(fade=False, keep_scroll=True)

    def set_tab(self, index):  # used by main.py's screenshot helper
        self.set_page(index)

    def open_category(self, panel_id):
        self.page_index, self.category, self.view = self.tab_of[panel_id], panel_id, "pages"
        self.render()

    def set_mode(self, mode):
        self.mode = mode
        self.render()

    def set_period(self, period):
        self.period = period
        self.render(keep_scroll=True)

    def toggle_summary(self):  # used by main.py's screenshot helper
        self.set_mode("headlines" if self.mode == "brief" else "brief")

    # -- data

    def coverage(self):
        if self.cover is None:
            self.cover = coverage(self.store.news_since(time.time() - 2 * 86400))
        return self.cover

    @staticmethod
    def keep(cfg, articles):
        """Apply a panel's own include / exclude keyword lists."""
        inc = cfg.get("include")
        exc = list(cfg.get("exclude") or []) + [w.lower() for w in PROFILE["mute"]]
        out = []
        for a in articles:
            text = f" {a['title'].lower()} "
            if inc and not any(w in text for w in inc):
                continue
            if exc and any(w in text for w in exc):
                continue
            out.append(a)
        return out

    def mix(self, cfg, since):
        """Panels on Right Now draw from other panels (or from everything)."""
        ids = cfg["from"]
        if ids == "all":
            ids = [p["id"] for p in self.feed_panels if p.get("kind") != "events"]
        seen, pool = set(), []
        for pid in ids:
            for a in self.keep(cfg, self.store.since(pid, since)):
                key = " ".join(a["title"].lower().split())
                if key not in seen:
                    seen.add(key)
                    pool.append(a)
        cover = self.coverage()
        need = cfg.get("min_coverage")
        if need:
            pool = [a for a in pool if self.outlets_covering(a) >= need]
        return quality_order(pool, cover)

    def outlets_covering(self, article):
        """How many different outlets ran a headline about the same thing
        (sharing at least three meaningful words) in the last two days."""
        if self.recent_titles is None:
            self.recent_titles = [
                (a["source"], set(w.lower() for w in terms(a["title"])))
                for a in self.store.news_since(time.time() - 2 * 86400)
            ]
        mine = set(w.lower() for w in terms(article["title"]))
        if len(mine) < 3:
            return 1
        return len({src for src, words in self.recent_titles if len(mine & words) >= 3} | {article["source"]})

    def headlines_for(self, cfg):
        kind = cfg.get("kind")
        if kind == "events":
            return self.keep(cfg, self.store.upcoming(cfg["id"], until=today_start() + PROFILE["horizon_days"] * 86400))
        if kind == "mix":
            return self.mix(cfg, time.time() - cfg.get("days", 3) * 86400)
        if cfg.get("order") == "newest" or kind == "checklist":
            return self.keep(cfg, self.store.recent(cfg["id"]))
        # quality over quantity: best-covered recent stories first
        return quality_order(self.keep(cfg, self.store.recent(cfg["id"], limit=80, max_age_days=10)), self.coverage())

    def window_for(self, cfg):
        kind = cfg.get("kind")
        if kind == "events":
            until = min(ai.window_end(self.period), today_start() + PROFILE["horizon_days"] * 86400)
            return [a for a in self.keep(cfg, self.store.upcoming(cfg["id"], until=until)) if a.get("event_at")]
        if kind == "mix":
            return self.mix(cfg, ai.window_start(self.period))[:40]
        if kind == "horizon":
            return []
        return self.keep(cfg, self.store.since(cfg["id"], ai.window_start(self.period)))

    def unread_panel(self, cfg):
        kind = cfg.get("kind")
        if kind in ("events", "checklist", "horizon"):
            return 0
        now = time.time()
        articles = self.headlines_for(cfg)[:CARD_ROWS] if kind == "mix" else self.store.recent(cfg["id"])
        return sum(1 for a in articles if not a["seen"] and now - a["published"] < 86400)

    def unread_page(self, tab):
        return sum(self.unread_panel(cfg) for cfg in tab["panels"])

    def request_brief(self, panels):
        """The only way into Claude: it shows the cost first and waits for a yes."""
        pa = [(cfg, self.window_for(cfg)) for cfg in panels if cfg.get("kind") not in ("checklist", "horizon")]
        pa = [(cfg, arts) for cfg, arts in pa if arts]
        if not pa:
            return
        tokens = ai.estimate_tokens(pa, len(pa) > 1)
        what = pa[0][0]["title"] if len(pa) == 1 else f"all {len(pa)} categories on this page"
        if not confirm_tokens(self, f"Brief me: {what}", tokens, sum(len(a) for _, a in pa)):
            return
        self.briefer.request(self.current_tab(), [cfg for cfg, _ in pa], self.period, pa)

    def brief_all(self):
        self.request_brief(self.current_tab()["panels"])

    # -- drawing

    def column_width(self):
        """About two and a half cards across, so there is always a hint of more
        to the right."""
        width = self.scroll.viewport().width()
        return int(max(470, min(660, (width - 40) / 2.4)))

    def on_resized(self):
        if self.column_width() != self.columns:
            self.render(fade=False, keep_scroll=True)

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self.resize_timer.start()

    def card_for(self, cfg, full=False):
        failed = {title for title, _, _ in self.errors}
        if cfg.get("kind") == "horizon":
            return HorizonCard(self, cfg)
        if cfg.get("kind") == "checklist":
            if self.mode == "brief" and not full:
                return DueSoonCard(self, cfg, self.period)
            return ChecklistCard(self, cfg, full)
        if self.mode == "brief":
            return BriefCard(self, cfg, self.window_for(cfg), self.period, full)
        status = "This source didn't answer on the last sync. It will try again automatically." if cfg["title"] in failed else ""
        return HeadlineCard(self, cfg, self.headlines_for(cfg), full, status)

    def build_content(self):
        content = QWidget()
        strip = QHBoxLayout(content)
        strip.setContentsMargins(0, 0, 40, 8)
        strip.setSpacing(18)
        tab = self.current_tab()
        width = self.columns = self.column_width()
        self.columns_list = []

        def add(card, cfg=None, w=None, hug=False):
            col = Column(self, card, w or width, cfg, hug)
            self.columns_list.append(col)
            strip.addWidget(col)

        if self.view == "prefs":
            add(ListEditorCard(
                "WHAT MATTERS TO ME", "What I want from my news",
                "Plain sentences. The AI briefings follow these.",
                PROFILE["focus"], "e.g. Skip celebrity gossip unless everyone's talking about it",
                lambda items: self.update_profile(focus=items),
                "Nothing yet. Add how you like your news."), w=int(width * 1.25))
            add(AboutCard(self))
            add(AheadCard(self))
            add(ListEditorCard(
                "LEAVE OUT", "Leave out stories mentioning",
                "Any headline containing one of these words or phrases is hidden everywhere.",
                PROFILE["mute"], "e.g. Kardashian",
                lambda items: self.update_profile(mute=items),
                "Nothing muted."))
            add(GreetingCard(self))
        elif self.category:
            cfg = self.panel_by_id[self.category]
            kind = cfg.get("kind")
            if kind in ("checklist", "horizon"):
                add(self.card_for(cfg, full=True), cfg, w=int(width * 1.3))
            elif self.mode == "brief":
                arts = self.window_for(cfg)
                add(BriefCard(self, cfg, arts, self.period, full=False), cfg)
                for i in range(0, len(arts), 6):
                    add(StoryColumn(self, f"All stories in this window · {i // 6 + 1}", arts[i:i + 6]), cfg)
            else:
                arts = self.headlines_for(cfg)
                status = ""
                add(HeadlineCard(self, cfg, arts[:5], full=True, status=status), cfg)
                for i in range(5, len(arts), 6):
                    add(StoryColumn(self, f"{cfg['title']} · continued", arts[i:i + 6]), cfg)
        else:
            if self.mode == "brief":
                scope = f"tab:{tab['id']}"
                overview = self.store.briefing(scope, self.period)
                if self.briefer.busy(scope, self.period):
                    add(OverviewCard("Writing", "Claude is reading every category on this page. This usually takes 15–40 seconds.", muted=True), w=int(width * 0.8))
                elif self.briefer.error(scope, self.period):
                    add(OverviewCard("AI briefing unavailable", explain(self.briefer.error(scope, self.period)), muted=True), w=int(width * 0.8))
                elif overview and overview.get("overview"):
                    add(OverviewCard(f"Overview · {dict(PERIODS)[self.period].lower()}", overview["overview"]), w=int(width * 0.8))
            for cfg in tab["panels"]:
                # a quiet watch (one story or none) is a small card; it grows with more
                quiet = (cfg.get("compact_when_quiet") and self.mode == "headlines"
                         and len(self.headlines_for(cfg)) <= 1)
                add(self.card_for(cfg), cfg, w=int(width * 0.62) if quiet else None, hug=quiet)
        strip.addStretch()
        return content

    def render(self, fade=True, keep_scroll=False):
        self.header.update_for(self)
        self.sidebar.rebuild()
        old_scroll = self.scroll.horizontalScrollBar().value()
        overlay = None
        if self.view == "prefs":
            fade = fade and not keep_scroll
        if fade and self.scroll.widget() is not None:
            # fade the old page out over the new one
            overlay = QLabel(self.main)
            overlay.setPixmap(self.scroll.grab())
            overlay.setGeometry(self.scroll.geometry())
            overlay.show()
        self.scroll.setWidget(self.build_content())
        if keep_scroll:
            QTimer.singleShot(0, lambda: self.scroll.horizontalScrollBar().setValue(old_scroll))
        else:
            self.sel = [0, 0]
        QTimer.singleShot(30, self.place_ring)
        self.rendered_at = time.monotonic()
        if overlay:
            effect = QGraphicsOpacityEffect(overlay)
            overlay.setGraphicsEffect(effect)
            anim = QPropertyAnimation(effect, b"opacity", overlay)
            anim.setDuration(200)
            anim.setStartValue(1.0)
            anim.setEndValue(0.0)
            anim.setEasingCurve(QEasingCurve.Type.OutCubic)
            anim.finished.connect(overlay.deleteLater)
            anim.start()

    # -- controller & keyboard

    def page_wheel(self, e):
        bar = self.scroll.horizontalScrollBar()
        delta = e.angleDelta().y() or e.angleDelta().x()
        bar.setValue(bar.value() - delta)

    def eventFilter(self, obj, e):
        if e.type() == e.Type.Wheel and obj is self.scroll.viewport():
            self.page_wheel(e)
            return True
        if e.type() == e.Type.KeyPress and self.isActiveWindow() or (e.type() == e.Type.KeyPress and getattr(self, "director", None)):
            return self.on_key(e)
        return False

    def typing(self):
        w = QGuiApplication.instance().focusWidget() if hasattr(QGuiApplication.instance(), "focusWidget") else None
        return isinstance(w, (QLineEdit, QPlainTextEdit, QSpinBox, QDateEdit)) and w.hasFocus()

    def on_key(self, e):
        if getattr(self, "director", None):
            self.director.skip()
            return True
        key, text = e.key(), e.text().lower()
        K = Qt.Key
        if self.typing():
            if key == K.Key_Escape:
                QGuiApplication.instance().focusWidget().clearFocus()
                return True
            return False
        moves = {K.Key_Left: "left", K.Key_Right: "right", K.Key_Up: "up", K.Key_Down: "down"}
        letters = {"h": "left", "l": "right", "k": "up", "j": "down", "b": "toggle_mode", "s": "secondary",
                   "r": "refresh", "f": "focus_page", " ": "activate"}
        if key in moves:
            self.on_action(moves[key])
        elif key in (K.Key_Return, K.Key_Enter):
            self.on_action("activate")
        elif key in (K.Key_Escape, K.Key_Backspace):
            self.on_action("back")
        elif key == K.Key_Tab:
            self.on_action("next_page")
        elif key == K.Key_Backtab:
            self.on_action("prev_page")
        elif key == K.Key_PageDown:
            self.on_action("page_right")
        elif key == K.Key_PageUp:
            self.on_action("page_left")
        elif key == K.Key_Home:
            self.select(0, 0)
        elif key == K.Key_End:
            self.select(len(self.columns_list) - 1, 0)
        elif text.isdigit() and 1 <= int(text) <= len(self.tabs):
            self.set_page(int(text) - 1)
        elif self.mode == "brief" and text in ("d", "w", "m") and self.view == "pages":
            self.set_period({"d": "day", "w": "week", "m": "month"}[text])
        elif text in letters:
            self.on_action(letters[text])
        else:
            return False
        return True

    def on_action(self, name):
        if getattr(self, "director", None):
            self.director.skip()
            return
        if name.startswith("glide:"):
            bar = self.scroll.horizontalScrollBar()
            bar.setValue(bar.value() + int(float(name[6:]) * 28))
            return
        self.nav_on = True
        if name in ("left", "right"):
            self.move_column(-1 if name == "left" else 1)
        elif name in ("up", "down"):
            self.move_item(-1 if name == "up" else 1)
        elif name == "activate":
            self.activate(self.selected())
        elif name == "back":
            if self.view == "prefs" or self.category:
                self.set_page(self.page_index)
        elif name == "toggle_mode" and self.view == "pages":
            self.set_mode("headlines" if self.mode == "brief" else "brief")
        elif name == "secondary":
            col = self.columns_list[self.sel[0]] if self.columns_list else None
            cfg = col.cfg if col else None
            if cfg and self.mode == "brief" and cfg.get("kind") not in ("checklist", "horizon"):
                self.request_brief([cfg])
            elif cfg and not self.category:
                self.open_category(cfg["id"])
        elif name in ("next_page", "prev_page"):
            step = 1 if name == "next_page" else -1
            self.set_page((self.page_index + step) % len(self.tabs))
        elif name in ("page_left", "page_right"):
            self.scroll_by_screen(-1 if name == "page_left" else 1)
        elif name == "refresh":  # what the checklist last fetched, without opening it
            if not self.refresh_blocked(self.refresh_reason()):
                self.run_refresh(PROFILE.get("refresh_kinds") or list(refreshmenu.KINDS))
        elif name == "focus_page":
            self.open_prefs()
        self.place_ring()

    def selected(self):
        if not self.columns_list:
            return None
        c = max(0, min(self.sel[0], len(self.columns_list) - 1))
        items = self.columns_list[c].focusables()
        if not items:
            return None
        return items[max(0, min(self.sel[1], len(items) - 1))]

    def select(self, col, item):
        self.sel = [max(0, min(col, len(self.columns_list) - 1)), max(0, item)]
        self.nav_on = True
        self.reveal()
        self.place_ring()

    def move_column(self, step):
        if not self.columns_list:
            return
        current = self.selected()
        y = current.mapTo(self, QPointF(0, 0).toPoint()).y() if current else 0
        col = max(0, min(self.sel[0] + step, len(self.columns_list) - 1))
        items = self.columns_list[col].focusables()
        best = 0
        if items:
            best = min(range(len(items)), key=lambda i: abs(items[i].mapTo(self, QPointF(0, 0).toPoint()).y() - y))
        self.select(col, best)

    def move_item(self, step):
        if not self.columns_list:
            return
        items = self.columns_list[self.sel[0]].focusables()
        self.select(self.sel[0], max(0, min(self.sel[1] + step, len(items) - 1)))

    def scroll_by_screen(self, step):
        bar = self.scroll.horizontalScrollBar()
        target = bar.value() + step * int(self.scroll.viewport().width() * 0.85)
        self.animate_scroll(target)
        # move the highlight to the first column now in view
        for i, col in enumerate(self.columns_list):
            if col.x() + col.width() / 2 >= target:
                self.sel = [i, 0]
                break

    def animate_scroll(self, target):
        bar = self.scroll.horizontalScrollBar()
        target = max(bar.minimum(), min(bar.maximum(), target))
        self.glide = QPropertyAnimation(bar, b"value", self)
        self.glide.setDuration(260)
        self.glide.setStartValue(bar.value())
        self.glide.setEndValue(target)
        self.glide.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.glide.start()

    def reveal(self):
        """Scroll so the highlighted item is fully on screen."""
        if not self.columns_list:
            return
        col = self.columns_list[self.sel[0]]
        bar = self.scroll.horizontalScrollBar()
        view = self.scroll.viewport().width()
        left, right = col.x(), col.x() + col.width()
        if left < bar.value() + 10:
            self.animate_scroll(left - 10)
        elif right > bar.value() + view - 10:
            self.animate_scroll(right - view + 10)
        w = self.selected()
        if w is not None:
            col.ensureWidgetVisible(w, 0, 60)

    def activate(self, w):
        if w is None:
            return
        if isinstance(w, ArticleRow):
            w.article["seen"] = 1
            w.refresh_look()
            self.open_article(w.article)
        elif isinstance(w, TodoRow):
            w.toggled.emit(w.todo["id"], not w.todo["done"])
        elif isinstance(w, Button):
            w.click()
        elif isinstance(w, Segmented):
            keys = [k for k, _ in w.options]
            nxt = keys[(keys.index(w.current) + 1) % len(keys)]
            w.set_current(nxt)
            w.changed.emit(nxt)
        else:
            w.setFocus()  # a text box: type, then Esc to leave it

    def place_ring(self):
        root = self.centralWidget()
        if root is None:
            return
        target = self.selected() if self.nav_on else None
        vp = self.scroll.viewport()
        top_left = vp.mapTo(root, QPointF(0, 0).toPoint())
        clip = vp.rect().translated(top_left)
        if target is None or not target.isVisible():
            self.ring.hide()
            return
        r = target.rect().translated(target.mapTo(root, QPointF(0, 0).toPoint())).adjusted(-6, -4, 6, 4)
        r = r.intersected(clip.adjusted(-6, -6, 6, 6))
        if r.isEmpty():
            self.ring.hide()
            return
        self.ring.setGeometry(r)
        self.ring.show()
        self.ring.raise_()
        self.ring.update()

    # -- feeds

    def refresh(self, panels=None, with_pictures=True):
        if self.fetcher and self.fetcher.isRunning():
            return
        panels = panels or self.feed_panels
        self.header.refresh.setEnabled(False)
        self.sidebar.status.setText("Checking sources for new stories…")
        if self.panel is not None:
            self.panel.set_feed_status("Checking sources for new stories…")
        self.fetcher = FetchThread(panels, with_pictures)
        self.fetcher.done.connect(self.on_fetched)
        self.fetcher.progress.connect(self.on_progress)
        self.on_progress(0.02, "Checking sources…")
        self.fetcher.start()

    def refresh_buttons(self):
        return [self.header.refresh] + ([self.panel.refresh_btn] if self.panel is not None else [])

    def check_online(self):
        """Is there a connection? Looked at quietly in the background once a minute (a name
        lookup, no data), so the Refresh button can say "offline" instead of failing."""
        def look():
            try:
                socket.getaddrinfo("en.wikipedia.org", 443)
                self.online = True
            except OSError:
                self.online = False
        threading.Thread(target=look, daemon=True).start()

    def refresh_blocked(self, why):
        """Why pressing Refresh now could not work, or None. Only what can be told ahead."""
        if not getattr(self, "online", True):
            return "Offline · can't refresh"
        wait = world.wiki_wait()
        if wait and why and why not in ("news",) and not why.startswith("news"):
            return f"{why} in {max(1, round(wait / 60))} min"  # it needs Wikipedia, which asked us to wait
        return None

    def refresh_reason(self):
        """Why a refresh would help now, in a few words, or None."""
        if self.fetcher and self.fetcher.isRunning():
            return None
        m = self.panel.map if self.panel is not None else None
        if m is not None and m.chosen is not None and m.missing():
            return m.chosen["name"]  # he zoomed in: its sides are not looked up yet
        last = self.store.last_fetched()
        if not last:
            return "news"
        age = time.time() - last
        if age > 3600:
            return f"news {int(age // 3600)}h old"
        if m is not None and (m.read_at is None or (datetime.now() - m.read_at).total_seconds() > 6 * 3600):
            return "world map"
        return None

    def update_refresh_buttons(self):
        """'Refresh' when all is fresh; 'Refresh · Ukraine' (lit) when fresh data would help."""
        self.header.clock.setText(datetime.now().strftime("%I:%M %p").lstrip("0"))
        if self.fetcher and self.fetcher.isRunning():
            return
        why = self.refresh_reason()
        blocked = self.refresh_blocked(why)
        for b in self.refresh_buttons():
            b.kind = "outline" if why and not blocked else "ghost"
            b.setEnabled(blocked is None)
            if blocked:
                b.setText(f"⟳  {blocked}")
                b.setToolTip("Refresh can't work right now: " + ("there is no internet connection." if "Offline" in blocked
                             else "Wikipedia asked us to wait before asking again. It turns itself back on."))
            else:
                b.setText(f"⟳  Refresh · {why}" if why else "⟳  Refresh")
                b.setToolTip("Fetch the ticked pages' news and the world map's data" + (f" (wanted: {why})" if why else ""))
            b.updateGeometry()
            b.update()

    def refresh_everything(self, button=None):
        """The one Refresh: opens the checklist of what to fetch (refreshmenu.py)."""
        if self.refresh_blocked(self.refresh_reason()):
            return
        if self.menu is None:
            self.menu = refreshmenu.RefreshMenu(self, sys.modules[__name__])
        self.menu.open_under(button or self.header.refresh)

    def run_refresh(self, kinds):
        """Fetch the kinds he ticked in the checklist."""
        if "news" in kinds:
            ticked = self.panel.feeds.ticked() if self.panel is not None else (PROFILE.get("refresh_pages") or [])
            self.refresh_pages(ticked, with_pictures="pictures" in kinds)
        if self.panel is not None:
            world_kinds = [k for k in ("wars", "sides", "front") if k in kinds]
            if world_kinds:
                self.panel.refresh_world(world_kinds)
            if "weather" in kinds:
                self.panel.check_weather()

    def on_progress(self, value, text):
        self.sidebar.loading.set(value)
        for b in self.refresh_buttons():
            b.setText(f"Refreshing · {round(self.sidebar.loading.value * 100)}%")
        if self.panel is not None:
            self.panel.loading.set(value)
            self.panel.set_feed_status(text)

    def on_fetched(self, articles, errors):
        self.sidebar.loading.reset()
        self.update_refresh_buttons()
        if self.panel is not None:
            self.panel.loading.reset()
        global PICTURES
        self.errors = errors
        if self.fetcher.pictures is not None:
            PICTURES = {**PICTURES, **self.fetcher.pictures} if self.fetcher.panels != self.feed_panels else self.fetcher.pictures
        added = self.store.add(articles)
        self.cover = self.recent_titles = None
        self.header.refresh.setEnabled(True)
        stamp = datetime.now().strftime("%I:%M %p").lstrip("0")
        text = f"Updated {stamp} · {added} new"
        if errors:
            text += f"\n{len(errors)} source{'s' if len(errors) > 1 else ''} didn't answer (hover for which)"
            self.sidebar.status.setToolTip("\n".join(f"{s} ({p})" for p, s, _ in errors))
        else:
            self.sidebar.status.setToolTip("")
        self.sidebar.status.setText(text)
        if self.panel is not None:
            self.panel.set_feed_status(text)
            self.panel.update_map()
        self.render(fade=False, keep_scroll=True)

    def open_article(self, article):
        self.store.mark_seen(article["id"])
        open_link(article["link"])
        QTimer.singleShot(0, self.sidebar.rebuild)
