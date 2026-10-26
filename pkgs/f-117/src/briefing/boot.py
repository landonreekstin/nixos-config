"""The start-up sequence, spread across every connected screen.

One borderless full-screen window per monitor, all driven by one clock so they
act as a single display:

  0.0–1.0s  the faceted panels light up in a wave that starts at the main screen
  0.3–1.5s  a soft blue scan line sweeps down every screen
  1.0–2.8s  an F-117 silhouette flies across ALL the screens, left to right,
            with a light trail (positions are worked out in desktop coordinates)
  1.6s on   main screen: logo, "F-117", the greeting, then status lines
            other screens: a big clock / the page roster / system readouts
  ~4.8s     everything fades out and the app is underneath

Any key, click or controller button skips straight to the fade.

Smoothness (2026-10-26, "luxury and seamless"): the app is fully built and placed
*before* any of this appears (ui.MainWindow.boot), the clock only starts once every
screen has drawn its first frame, nothing slow runs on the main thread while it plays
(the app's fade-in is a background thread, panel.Fader), and the unchanging background
is drawn once per screen and reused.
"""

import math
import time

from PyQt6.QtCore import QObject, QPointF, QRectF, QSize, Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QColor, QLinearGradient, QPainter, QPen, QPixmap, QPolygonF
from PyQt6.QtWidgets import QWidget

from . import theme as T

HOLD_UNTIL = 4.8  # seconds before the app starts to show
# The hand-over (2026-10-26, "the crossfade can be improved"): first the app fades in
# *over* the start-up, which stays solid behind it, so the desktop never shows through
# half-way; only then does the start-up slip away (by then it only shows round the app's
# edges: the bar strip, the gap under the title bar).
REVEAL = 0.7  # the app fading in over the start-up
FADE = 0.45  # then the start-up fading out


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def phase(t, start, length):
    return ease((t - start) / length)


TITLE = "F-117 · start-up"

class BootDirector(QObject):
    """Owns the clock and the windows; tells them when to paint and when to go."""

    finished = pyqtSignal()
    ready = pyqtSignal()  # every screen has drawn its first frame; call go() to play

    def __init__(self, screens, primary, greeting, lines, roster):
        super().__init__()
        self.greeting, self.lines, self.roster = greeting, lines, roster
        self.rects = [QRectF(s.geometry()) for s in screens]
        self.desktop = self.rects[0]
        for r in self.rects[1:]:
            self.desktop = self.desktop.united(r)
        self.primary_index = screens.index(primary) if primary in screens else 0
        self.windows = [
            BootScreen(self, i, screen, i == self.primary_index) for i, screen in enumerate(screens)
        ]
        self.t0 = None
        self.skip_at = None
        self.told = False
        self.timer = QTimer(self, interval=8, timeout=self.tick)
        self.timer.setTimerType(Qt.TimerType.PreciseTimer)

    def launch(self):
        """Put the windows up, holding the first frame (a dark screen) until go()."""
        for w in self.windows:
            w.launch()

    def first_frame(self):
        if self.t0 is None and not self.told and all(w.painted for w in self.windows):
            self.told = True
            self.ready.emit()

    def go(self):
        if self.t0 is None:
            self.t0 = time.monotonic()
            self.timer.start()

    def now(self):
        return 0.0 if self.t0 is None else time.monotonic() - self.t0

    def fade_start(self):
        return min(HOLD_UNTIL, self.skip_at) if self.skip_at is not None else HOLD_UNTIL

    def skip(self):
        if self.skip_at is None:
            self.skip_at = self.now()

    def reveal(self, t):
        """How far the app has faded in (0..1), eased."""
        return ease((t - self.fade_start()) / REVEAL)

    def alpha(self, t):
        return 1.0 - ease((t - self.fade_start() - REVEAL) / FADE)

    def tick(self):
        t = self.now()
        for w in self.windows:
            w.update()
        if t > self.fade_start() + REVEAL + FADE:
            self.timer.stop()
            for w in self.windows:
                w.close()
                w.deleteLater()
            self.finished.emit()

    # where the jet is, in desktop coordinates, at time t
    def jet(self, t):
        p = phase(t, 1.0, 1.8)
        if p <= 0 or p >= 1:
            return None
        d = self.desktop
        main = self.rects[self.primary_index]
        x = d.left() - 300 + (d.width() + 600) * p
        y = main.top() + main.height() * 0.30 + math.sin(p * math.pi) * -60
        return QPointF(x, y), p


class BootScreen(QWidget):
    def __init__(self, director, index, screen, primary):
        super().__init__(None, Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.d, self.index, self.screen_obj, self.primary = director, index, screen, primary
        self.rect_desktop = director.rects[index]
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setCursor(Qt.CursorShape.BlankCursor)
        self.setWindowTitle(TITLE)  # not "F-117": the app's own windows are found by that name
        self.f_big = T.font(T.DISPLAY, 72, T.QFont.Weight.Bold, 26)
        self.f_tag = T.font(T.MONO, 13, spacing=9)
        self.f_greet = T.font(T.BODY, 26, T.QFont.Weight.Light)
        self.f_line = T.font(T.MONO, 12.5, spacing=2.4)
        self.f_clock = T.font(T.DISPLAY, 150, T.QFont.Weight.Bold, 8)
        self.f_head = T.font(T.MONO, 14, spacing=6)
        self.f_roster = T.font(T.DISPLAY, 26, T.QFont.Weight.Bold, 4)
        self.painted = False
        self.base = None  # the dark grained background, drawn once

    def base_layer(self, w, h):
        if self.base is None or self.base.size() != QSize(w, h):
            dpr = self.devicePixelRatioF()
            self.base = QPixmap(int(w * dpr), int(h * dpr))
            self.base.setDevicePixelRatio(dpr)
            self.base.fill(QColor("#06080b"))
            q = QPainter(self.base)
            q.drawTiledPixmap(QRectF(0, 0, w, h).toRect(), T.grain())
            q.end()
        return self.base

    def launch(self):
        self.create()
        if self.windowHandle() is not None:
            self.windowHandle().setScreen(self.screen_obj)
        self.setGeometry(self.screen_obj.geometry())
        self.showFullScreen()

    # skip on any input
    def keyPressEvent(self, e):
        self.d.skip()

    def mousePressEvent(self, e):
        self.d.skip()

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        self.paint_at(p, self.d.now(), self.width(), self.height())
        p.end()
        if not self.painted:
            self.painted = True
            QTimer.singleShot(0, self.d.first_frame)

    def paint_at(self, p, t, w, h):
        a = self.d.alpha(t)
        p.setOpacity(a)
        p.drawPixmap(0, 0, self.base_layer(w, h))

        # facets light up in a wave that starts at the main screen
        main = self.d.rects[self.d.primary_index]
        dist = abs(self.rect_desktop.center().x() - main.center().x()) / max(self.d.desktop.width(), 1)
        for i, facet in enumerate(T.BACKDROP_FACETS):
            k = phase(t, 0.05 + dist * 0.9 + i * 0.07, 0.6)
            if k <= 0:
                continue
            poly = QPolygonF([QPointF(x * w, y * h) for x, y in facet])
            p.setBrush(QColor(T.FACET_SHADES[i % len(T.FACET_SHADES)]).darker(115))
            edge = QColor(T.AMBER)
            edge.setAlphaF(0.55 * k * (1 - phase(t, 1.4 + i * 0.05, 0.8)) + 0.08 * k)
            p.setPen(QPen(edge, 1.2))
            p.drawPolygon(poly)

        # scan line sweeping down
        s = phase(t, 0.3 + dist * 0.4, 1.1)
        if 0 < s < 1:
            y = h * s
            grad = QLinearGradient(0, y - 120, 0, y)
            c0 = QColor(T.AMBER)
            c0.setAlpha(0)
            c1 = QColor(T.AMBER)
            c1.setAlpha(60)
            grad.setColorAt(0, c0)
            grad.setColorAt(1, c1)
            p.fillRect(QRectF(0, y - 120, w, 120), grad)
            p.fillRect(QRectF(0, y - 1, w, 2), T.AMBER)

        # the jet flying across every screen
        jet = self.d.jet(t)
        if jet:
            pos, prog = jet
            local = QPointF(pos.x() - self.rect_desktop.left(), pos.y() - self.rect_desktop.top())
            self.paint_jet(p, local, prog, w)

        if self.primary:
            self.paint_primary(p, t, w, h)
        else:
            self.paint_secondary(p, t, w, h)

        # thin frame corners, like a HUD
        k = phase(t, 0.6, 0.6)
        if k > 0:
            p.setPen(QPen(T.AMBER_DIM, 2))
            L = 60 * k
            for cx, cy, sx, sy in ((30, 30, 1, 1), (w - 30, 30, -1, 1), (30, h - 30, 1, -1), (w - 30, h - 30, -1, -1)):
                p.drawLine(QPointF(cx, cy), QPointF(cx + L * sx, cy))
                p.drawLine(QPointF(cx, cy), QPointF(cx, cy + L * sy))

    def paint_jet(self, p, c, prog, w):
        size = 210
        # engine trail
        grad = QLinearGradient(c.x() - 900, 0, c.x() - size * 0.3, 0)
        t0 = QColor(T.AMBER)
        t0.setAlpha(0)
        t1 = QColor(T.AMBER)
        t1.setAlpha(150)
        grad.setColorAt(0, t0)
        grad.setColorAt(1, t1)
        p.fillRect(QRectF(c.x() - 900, c.y() - 2, 900 - size * 0.3, 4), grad)
        p.fillRect(QRectF(c.x() - 600, c.y() - 14, 600 - size * 0.3, 1), grad)
        p.fillRect(QRectF(c.x() - 600, c.y() + 13, 600 - size * 0.3, 1), grad)
        # the aircraft, nose pointing right (outline rotated 90°)
        pts = [QPointF(c.x() + (y - 0.5) * size, c.y() + (x - 0.5) * size * 0.95) for x, y in T.JET_OUTLINE]
        pts = [QPointF(2 * c.x() - q.x(), q.y()) for q in pts]  # nose to the right
        left = QPolygonF([pts[0], pts[5], pts[6], pts[7], pts[8], pts[9]])
        right = QPolygonF([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5]])
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QColor("#c4cad3"))
        p.drawPolygon(left)
        p.setBrush(QColor("#7d848f"))
        p.drawPolygon(right)

    def centered(self, p, font, color, text, y, w, opacity=1.0):
        p.save()
        p.setOpacity(p.opacity() * opacity)
        p.setFont(font)
        p.setPen(QColor(color))
        p.drawText(QRectF(0, y, w, 200), Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop, text)
        p.restore()

    def paint_primary(self, p, t, w, h):
        k = phase(t, 1.6, 0.7)
        cy = h * 0.34
        if k > 0:
            size = 130
            c = QPointF(w / 2, cy - 30 - 20 * (1 - k))
            pts = [QPointF(c.x() + (x - 0.5) * size, c.y() + (y - 0.5) * size * 0.84) for x, y in T.JET_OUTLINE]
            p.save()
            p.setOpacity(p.opacity() * k)
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(QColor("#c4cad3"))
            p.drawPolygon(QPolygonF([pts[0], pts[5], pts[6], pts[7], pts[8], pts[9]]))
            p.setBrush(QColor("#7d848f"))
            p.drawPolygon(QPolygonF([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5]]))
            p.restore()
            self.centered(p, self.f_big, T.TEXT_BRIGHT, "F-117", cy + 60, w, k)
            self.centered(p, self.f_tag, T.AMBER_DIM.name(), "BRIEFING  ROOM", cy + 175, w, k)
        g = phase(t, 2.1, 0.8)
        if g > 0:
            self.centered(p, self.f_greet, T.AMBER.name(), self.d.greeting, cy + 235, w, g)
        shown = int(clamp((t - 2.4) / 0.28, 0, len(self.d.lines)))
        p.setFont(self.f_line)
        x0 = w / 2 - 260
        for i, line in enumerate(self.d.lines[:shown]):
            y = cy + 330 + i * 32
            last = i == len(self.d.lines) - 1
            p.setPen(T.AMBER)
            p.drawText(QPointF(x0, y), "◆")
            p.setPen(QColor(T.AMBER.name() if last else T.SOFT))
            p.drawText(QPointF(x0 + 34, y), line)

    def paint_secondary(self, p, t, w, h):
        k = phase(t, 1.4 + self.index * 0.15, 0.8)
        if k <= 0:
            return
        others = [i for i in range(len(self.d.rects)) if i != self.d.primary_index]
        if others.index(self.index) % 2 == 1:
            # a big clock and date
            now = time.localtime()
            self.centered(p, self.f_head, T.AMBER.name(), f"DISPLAY {self.index + 1:02d}  ·  ONLINE", h * 0.26, w, k)
            self.centered(p, self.f_clock, T.TEXT_BRIGHT, time.strftime("%H:%M", now), h * 0.32, w, k)
            self.centered(p, self.f_tag, T.SOFT, time.strftime("%A  %d  %B  %Y", now).upper(), h * 0.32 + 230, w, k)
        else:
            # the page roster, lighting up one by one
            self.centered(p, self.f_head, T.AMBER.name(), f"DISPLAY {self.index + 1:02d}  ·  PAGES LINKED", h * 0.2, w, k)
            p.setFont(self.f_roster)
            for i, name in enumerate(self.d.roster):
                r = phase(t, 1.8 + i * 0.22, 0.4)
                if r <= 0:
                    continue
                y = h * 0.3 + i * 64
                p.save()
                p.setOpacity(p.opacity() * r)
                p.setPen(T.AMBER)
                p.drawText(QRectF(0, y, w / 2 - 20, 60), Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter, f"{i + 1:02d}")
                p.setPen(QColor(T.TEXT_BRIGHT))
                p.drawText(QRectF(w / 2 + 20, y, w / 2, 60), Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter, name.upper())
                p.restore()
