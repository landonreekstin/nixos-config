"""The control panel's world map: click a country to zoom in and see its wars, who is
fighting, the cities in the news and (for Ukraine) the front line. Data: world.py.

Calm on purpose (he reads the news partly to keep his anxiety down): countries at war
are tinted in the app's soft blue, darker for deadlier wars, never red; the front line
is a muted sand colour; every panel names its source and how fresh it is.
"""

import html
import json
import math
import threading
import time

from PyQt6.QtCore import QEasingCurve, QPointF, QRectF, Qt, QTimer, QVariantAnimation
from PyQt6.QtGui import QBrush, QColor, QPainter, QPainterPath, QPen, QRadialGradient
from PyQt6.QtWidgets import QFrame, QLabel, QScrollArea, QToolTip, QVBoxLayout, QWidget

from . import theme as T
from . import world as W

# major war, war, conflict; skirmishes are not tinted (they would turn half the world blue)
TINT = [QColor(127, 176, 224, 125), QColor(127, 176, 224, 78), QColor(127, 176, 224, 38), None]
OCCUPIED = QColor(201, 170, 120, 120)
CONTESTED = QColor(201, 170, 120, 50)
FRONT = QColor("#e3c690")  # the front line itself: the edge of the occupied land
REGION_EDGE = QColor("#3a4654")
RIVER = QColor("#35577d")
DETAIL_BELOW = 75.0  # degrees of longitude shown: closer than this, regions, rivers and towns appear
WORLD = (-180.0, -56.0, 180.0, 78.0)  # lon/lat shown when nothing is chosen


class InfoBox(QScrollArea):
    """The card over the right of the map about the chosen country."""

    def __init__(self, parent):
        super().__init__(parent)
        self.setWidgetResizable(True)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setStyleSheet(f"QScrollArea {{ background: rgba(12,15,19,225); border: 1px solid {T.EDGE_HI.name()}; }}")
        self.text = QLabel()
        self.text.setWordWrap(True)
        self.text.setTextFormat(Qt.TextFormat.RichText)
        self.text.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.text.setStyleSheet(f"color: {T.SOFT}; background: transparent; padding: 14px 16px;")
        self.text.setFont(T.font(T.BODY, 10.5))
        self.text.setOpenExternalLinks(True)
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.addWidget(self.text)
        self.setWidget(box)
        self.hide()


class WorldMap(QWidget):
    def __init__(self):
        super().__init__()
        self.setMouseTracking(True)
        self.setMinimumHeight(260)
        self.countries = W.load_countries()
        self.index = W.country_index(self.countries)
        self.cities = W.load_cities()
        self.spots, self.front, self.conflicts, self.city_hits = [], None, [], {}
        self.read_at = None
        self.hover, self.chosen = None, None
        self.view = WORLD
        self.anim = None
        self.factions, self.threads = {}, []
        self.info = InfoBox(self)
        self.t0 = time.monotonic()
        # dots breathe slowly (not while the start-up plays: a redraw costs it a frame)
        self.pulse = QTimer(self, interval=100, timeout=lambda: WorldMap.starting or self.update())
        self.pulse.start()
        self.paths = {}  # (country name, view) -> QPainterPath, rebuilt when the view moves
        self.regions = self.rivers = None  # map detail, loaded in the background (8 MB of borders)
        self.press = None  # (where, view) while the mouse button is down: a click or a drag
        QTimer.singleShot(2500, self.start_detail)

    # Parsing the detail holds Python's lock for a few hundred ms even in a thread, which
    # froze the start-up animation; ui.MainWindow sets this while the animation plays
    # (it also pauses the breathing dots).
    starting = False

    def start_detail(self):
        if WorldMap.starting:
            QTimer.singleShot(500, self.start_detail)
        else:
            threading.Thread(target=self.load_detail, daemon=True).start()

    def load_detail(self):
        def bbox(pts):
            xs, ys = [q[0] for q in pts], [q[1] for q in pts]
            return (min(xs), min(ys), max(xs), max(ys))
        try:
            regions = json.loads((T.ASSETS / "regions.json").read_text())["regions"]
            for rg in regions:
                rg["bbox"] = bbox([q for ring in rg["rings"] for q in ring])
            rivers = json.loads((T.ASSETS / "rivers.json").read_text())["rivers"]
            for rv in rivers:
                rv["bbox"] = bbox(rv["pts"])
        except (OSError, ValueError, KeyError):
            return
        self.regions, self.rivers = regions, rivers

    # --- data ------------------------------------------------------------------------
    def set_spots(self, spots):
        self.spots = spots
        self.update()

    def set_world(self, conflicts, front, read_at, factions=None):
        self.conflicts, self.front, self.read_at = conflicts, front, read_at
        if factions:
            self.factions.update(factions)
        for c in self.countries:
            c["conflicts"] = []
        for cf in conflicts:
            for name in cf["countries"]:
                c = self.index.get(name.lower()) or self.index.get(name.split(" (")[0].lower())
                if c is not None and cf not in c["conflicts"]:
                    c["conflicts"].append(cf)
        self.refresh_info()
        if self.chosen is not None:  # the data may change where the war zone is
            self.chosen = next((c for c in self.countries if c["name"] == self.chosen["name"]), None)
            if self.chosen is not None:
                self.glide_to(self.view_for(self.chosen))
        self.update()

    def set_cities(self, hits):
        self.city_hits = hits
        self.refresh_info()
        self.update()

    # --- where things are on screen ------------------------------------------------------
    def frame(self):
        """The map's rectangle for the current view, as large as fits at its shape."""
        x0, y0, x1, y1 = self.view
        w, h = self.width(), self.height()
        aspect = (x1 - x0) / max(y1 - y0, 0.01)
        mw = min(w, h * aspect)
        return QRectF((w - mw) / 2, (h - mw / aspect) / 2, mw, mw / aspect)

    def to_xy(self, lat, lon, r=None):
        r = r or self.frame()
        x0, y0, x1, y1 = self.view
        return QPointF(r.left() + (lon - x0) / (x1 - x0) * r.width(), r.top() + (y1 - lat) / (y1 - y0) * r.height())

    def path_of(self, c, r):
        key = (c["name"], self.view, self.width(), self.height())
        p = self.paths.get(key)
        if p is None:
            p = QPainterPath()
            for ring in c["rings"]:
                pts = [self.to_xy(lat, lon, r) for lon, lat in ring]
                p.moveTo(pts[0])
                for pt in pts[1:]:
                    p.lineTo(pt)
                p.closeSubpath()
            if len(self.paths) > 2000:
                self.paths.clear()
            self.paths[key] = p
        return p

    def region_at(self, pos):
        if self.regions is None or self.view[2] - self.view[0] > DETAIL_BELOW:
            return None
        lon, lat = self.to_lonlat(pos)
        r = self.frame()
        for rg in self.regions:
            b = rg["bbox"]
            if b[0] <= lon <= b[2] and b[1] <= lat <= b[3] and self.rings_path(rg["rings"], r).contains(QPointF(pos)):
                return rg
        return None

    def rings_path(self, rings, r, closed=True):
        p = QPainterPath()
        for ring in rings:
            pts = [self.to_xy(lat, lon, r) for lon, lat in ring]
            p.moveTo(pts[0])
            for pt in pts[1:]:
                p.lineTo(pt)
            if closed:
                p.closeSubpath()
        return p

    def country_at(self, pos):
        r = self.frame()
        for c in self.countries:
            if self.path_of(c, r).contains(QPointF(pos)):
                return c
        return None

    # --- choosing ----------------------------------------------------------------------
    def choose(self, c):
        self.chosen = c
        if c is None:
            target = WORLD
            self.info.hide()
        else:
            target = self.view_for(c)
            self.place_info()
            self.info.show()
            self.refresh_info()
        self.glide_to(target)
        self.chosen_changed()  # the panel's Refresh button offers to fetch what is missing

    def focus_box(self, c):
        """What to zoom to for a country: the war zone for Ukraine and Russia (the front
        line and Ukraine), the main landmass for countries over the date line (Russia,
        the US, Fiji), else the whole country."""
        if self.front and c["name"] in ("Ukraine", "Russia"):
            ukr = next((k for k in self.countries if k["name"] == "Ukraine"), None)
            ux0, uy0, ux1, uy1 = ukr["bbox"] if ukr else (22, 44, 41, 53)
            # DeepStateMap also marks far-off occupied places (out to the Pacific): only the
            # areas in and around Ukraine count towards the war zone
            near = [ring for ring in self.front["occupied"] + self.front["contested"]
                    if ux0 - 4 <= sum(q[0] for q in ring) / len(ring) <= ux1 + 4
                    and uy0 - 3 <= sum(q[1] for q in ring) / len(ring) <= uy1 + 3]
            pts = [q for ring in near for q in ring]
            if ukr:
                pts += [q for ring in ukr["rings"] for q in ring]
            xs, ys = [q[0] for q in pts], [q[1] for q in pts]
            return min(xs), min(ys), max(xs), max(ys)
        x0, y0, x1, y1 = c["bbox"]
        if x1 - x0 > 180:
            ring = max(c["rings"], key=len)
            xs, ys = [q[0] for q in ring], [q[1] for q in ring]
            x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
        return x0, y0, x1, y1

    def view_for(self, c):
        """A close view of the country, filling the map, on the left of the card."""
        x0, y0, x1, y1 = self.focus_box(c)
        w, h = max(x1 - x0, 0.5), max(y1 - y0, 0.5)
        pad = max(w, h) * 0.08 + 0.3
        aspect = self.width() / max(self.height(), 1)
        room = 0.58  # the card covers the right ~40%
        vw = max((w + 2 * pad) / room, (h + 2 * pad) * aspect)
        vh = vw / aspect
        cy = (y0 + y1) / 2
        left = x0 - pad - ((vw * room) - (w + 2 * pad)) / 2
        return (left, cy - vh / 2, left + vw, cy + vh / 2)

    def glide_to(self, target):
        start = self.view
        if self.anim:
            self.anim.stop()
        self.anim = QVariantAnimation(self, startValue=0.0, endValue=1.0, duration=450)
        self.anim.setEasingCurve(QEasingCurve.Type.InOutCubic)

        def step(k):
            self.view = tuple(a + (b - a) * k for a, b in zip(start, target))
            self.update()

        self.anim.valueChanged.connect(step)
        self.anim.start()

    def chosen_changed(self):
        pass  # the panel replaces this

    def missing(self):
        """The chosen country's wars whose sides have not been looked up yet."""
        if self.chosen is None:
            return []
        return [cf for cf in sorted(self.chosen["conflicts"], key=lambda cf: cf["rank"])[:4]
                if cf["name"] not in self.factions]

    def got_factions(self, name, article, sides):
        self.factions[name] = (article, sides)
        self.refresh_info()

    def place_info(self):
        w = min(420, int(self.width() * 0.4))
        self.info.setGeometry(self.width() - w - 6, 6, w, self.height() - 12)

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self.place_info()

    # --- the card ------------------------------------------------------------------------
    def refresh_info(self):
        c = self.chosen
        if c is None:
            return
        esc = html.escape
        hd = f"color:{T.TEXT_BRIGHT}; font-family:'{T.DISPLAY}'; font-weight:700; letter-spacing:1.5px"
        cap = f"color:{T.META}; font-family:'{T.MONO}'; letter-spacing:1.4px; font-size:9.5pt"
        out = [f"<div style=\"{cap}\">◂ CLICK THE SEA TO SEE THE WHOLE WORLD</div>",
               f"<div style=\"{hd}; font-size:19pt; margin-top:6px\">{esc(c['name'].upper())}</div>"]
        wars = sorted(c["conflicts"], key=lambda cf: cf["rank"])
        if not wars:
            out.append(f"<p style='color:{T.SOFT}'>No ongoing armed conflict is listed here.</p>")
        for cf in wars:
            deaths = f" · {cf['deaths_year']:,} deaths in {cf['year']}" if cf.get("deaths_year") else ""
            out.append(f"<div style='margin-top:12px; {hd}; font-size:12.5pt'>{esc(cf['name'])}</div>"
                       f"<div style=\"{cap}\">{esc(cf['level'].upper())} · SINCE {esc(cf['since'])}{deaths}</div>")
            got = self.factions.get(cf["name"])
            if cf in wars[:4]:
                if got is None:
                    out.append(f"<div style='color:{T.ACCENT.name()}'>Press Refresh (top right) to look up who is fighting.</div>")
                elif got[1]:
                    article, sides = got
                    for i, side in enumerate(sides[:3]):
                        names = ", ".join(esc(n) for n in side[:6])
                        out.append(f"<div style='margin-top:3px'><span style='color:{T.ACCENT.name()}'>Side {i + 1}:</span> {names}</div>")
                    if article != cf["article"]:
                        out.append(f"<div style='color:{T.META}; font-size:9.5pt'>From “{esc(article)}”, its current phase.</div>")
                else:
                    out.append(f"<div style='color:{T.META}'>Wikipedia lists no sides for this one.</div>")
        cities = self.city_hits.get(c.get("iso") or "", [])
        if cities:
            out.append(f"<div style='margin-top:14px; {hd}; font-size:12.5pt'>Cities in the news</div>"
                       f"<div style=\"{cap}\">NAMED IN CONFLICT STORIES · PAST {W.CITY_DAYS} DAYS</div>")
            for name, _, _, n, headline in cities[:8]:
                out.append(f"<div style='margin-top:4px'><span style='color:{T.TEXT}'>{esc(name)}</span>"
                           f" <span style='color:{T.META}'>· {n}</span><br><span style='color:{T.SOFT}; font-size:9.5pt'>{esc(headline)}</span></div>")
        if self.front and c["name"] in ("Ukraine", "Russia"):
            when = self.front["when"].strftime("%B %d").replace(" 0", " ")
            out.append(f"<div style='margin-top:14px; {hd}; font-size:12.5pt'>Front line</div>"
                       f"<div><span style='color:{OCCUPIED.name()}'>■</span> occupied &nbsp; "
                       f"<span style='color:{CONTESTED.lighter(160).name()}'>□</span> status unclear</div>"
                       f"<div style='color:{T.META}; font-size:9.5pt'>DeepStateMap, updated {when}.</div>")
        read = f"read {self.read_at:%I:%M %p}".replace(" 0", " ") if self.read_at else "not read yet"
        out.append(f"<div style='margin-top:16px; color:{T.META}; font-size:9pt'>Wars and sides: Wikipedia, “List of ongoing "
                   f"armed conflicts” and each war's page ({read}). Editors keep them current; numbers are estimates.</div>")
        self.info.text.setText("".join(out))

    # --- input ---------------------------------------------------------------------------------
    def wheelEvent(self, e):
        """Zoom in and out around the pointer."""
        steps = e.angleDelta().y() / 120
        if not steps:
            return
        k = 0.8 ** steps
        x0, y0, x1, y1 = self.view
        w, h = x1 - x0, y1 - y0
        if (w * k < 1.5 and k < 1) or (w * k > 360 and k > 1):
            return
        lon, lat = self.to_lonlat(e.position())
        fx, fy = (lon - x0) / w, (y1 - lat) / h
        nw, nh = w * k, h * k
        nx0, ny1 = lon - fx * nw, lat + fy * nh
        if self.anim:
            self.anim.stop()
        self.view = (nx0, ny1 - nh, nx0 + nw, ny1)
        self.update()
        e.accept()

    def to_lonlat(self, pos):
        r = self.frame()
        x0, y0, x1, y1 = self.view
        return (x0 + (pos.x() - r.left()) / r.width() * (x1 - x0), y1 - (pos.y() - r.top()) / r.height() * (y1 - y0))

    def mousePressEvent(self, e):
        if e.button() == Qt.MouseButton.LeftButton:
            self.press = (e.position(), self.view)

    def mouseMoveEvent(self, e):
        if self.press is not None and e.buttons() & Qt.MouseButton.LeftButton:
            start, view = self.press
            d = e.position() - start
            if abs(d.x()) + abs(d.y()) > 5:  # a drag: the map follows the pointer
                r = self.frame()
                dx = d.x() / r.width() * (view[2] - view[0])
                dy = d.y() / r.height() * (view[3] - view[1])
                self.view = (view[0] - dx, view[1] + dy, view[2] - dx, view[3] + dy)
                self.dragged = True
                self.update()
                return
        c = self.country_at(e.position())
        if c is not self.hover or self.view[2] - self.view[0] < DETAIL_BELOW:
            self.hover = c
            self.update()
            if c is not None:
                wars = sorted(c["conflicts"], key=lambda cf: cf["rank"])
                tip = c["name"] + (f" · {wars[0]['level'].lower()}: {wars[0]['name']}" if wars else "")
                region = self.region_at(e.position())
                if region:
                    tip = f"{region['name']}, {tip}"
                QToolTip.showText(e.globalPosition().toPoint(), tip, self)
            else:
                QToolTip.hideText()

    def leaveEvent(self, e):
        self.hover = None
        self.update()

    def mouseReleaseEvent(self, e):
        if e.button() != Qt.MouseButton.LeftButton:
            return
        self.press = None
        if getattr(self, "dragged", False):
            self.dragged = False
            return
        c = self.country_at(e.position())
        self.choose(None if c is None or c is self.chosen else c)

    # --- drawing ------------------------------------------------------------------------------
    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        r = self.frame()
        p.save()
        p.setClipRect(QRectF(self.rect()))
        # a faint plotting-table grid
        p.setPen(QPen(QColor(255, 255, 255, 12), 1))
        x0, y0, x1, y1 = self.view
        step = 30 if x1 - x0 > 120 else 10 if x1 - x0 > 40 else 5
        for lon in range(int(x0 // step * step), int(x1) + 1, step):
            x = self.to_xy(0, lon, r).x()
            p.drawLine(QPointF(x, r.top()), QPointF(x, r.bottom()))
        for lat in range(int(y0 // step * step), int(y1) + 1, step):
            y = self.to_xy(lat, 0, r).y()
            p.drawLine(QPointF(r.left(), y), QPointF(r.right(), y))
        for c in self.countries:
            path = self.path_of(c, r)
            if not path.boundingRect().intersects(QRectF(self.rect())):
                continue
            base = QColor("#232b35")
            if c is self.hover or c is self.chosen:
                base = QColor("#2e3946")
            p.fillPath(path, base)
            tint = TINT[min(cf["rank"] for cf in c["conflicts"])] if c["conflicts"] else None
            if tint is not None:
                p.fillPath(path, tint)
            p.setPen(QPen(QColor("#3c4855"), 0.8))
            p.drawPath(path)
        if self.chosen is not None:
            p.setPen(QPen(T.ACCENT, 1.6))
            p.drawPath(self.path_of(self.chosen, r))
        zoomed = (x1 - x0) < 200
        close = (x1 - x0) < DETAIL_BELOW
        view_box = (x0, y0, x1, y1)

        def seen(b):
            return b[2] >= view_box[0] and b[0] <= view_box[2] and b[3] >= view_box[1] and b[1] <= view_box[3]

        if close and self.regions is not None:
            p.setPen(QPen(REGION_EDGE, 0.7))
            for rg in self.regions:
                if seen(rg["bbox"]):
                    p.drawPath(self.rings_path(rg["rings"], r))
        if close and self.rivers is not None:
            biggest = 5 if x1 - x0 > 40 else 7 if x1 - x0 > 15 else 9
            p.setPen(QPen(RIVER, 1.1))
            for rv in self.rivers:
                if (rv["rank"] or 9) <= biggest and seen(rv["bbox"]):
                    p.drawPath(self.rings_path([rv["pts"]], r, closed=False))
        if self.front and zoomed:
            for kind, color in (("contested", CONTESTED), ("occupied", OCCUPIED)):
                path = QPainterPath()
                for ring in self.front[kind]:
                    pts = [self.to_xy(lat, lon, r) for lon, lat in ring]
                    path.moveTo(pts[0])
                    for pt in pts[1:]:
                        path.lineTo(pt)
                    path.closeSubpath()
                p.fillPath(path, color)
                if kind == "contested":
                    p.fillPath(path, QBrush(CONTESTED.lighter(140), Qt.BrushStyle.BDiagPattern))
                    p.setPen(QPen(color.lighter(130), 1))
                else:  # the edge of the occupied land is the front line
                    p.setPen(QPen(FRONT, 1.8 if close else 1.0))
                p.drawPath(path)
        t = time.monotonic() - self.t0
        if close:
            self.draw_towns(p, r, view_box)
        if zoomed and self.chosen is not None:
            self.draw_cities(p, r, t)
        else:
            self.draw_spots(p, r, t)
        p.restore()

    def draw_spots(self, p, r, t):
        """The news's tension dots (panel.tensions), as on the plain map."""
        if not self.spots:
            return
        most = max(s[3] for s in self.spots)
        p.setFont(T.font(T.MONO, 10.5, spacing=1.2))
        for i, (name, lat, lon, n, _) in reversed(list(enumerate(self.spots))):
            c = self.to_xy(lat, lon, r)
            k = math.sqrt(n / most)
            rad = (5 + 20 * k) * r.width() / 1500
            self.dot(p, c, rad, k, t + i)
        self.labels(p, r, [(s[0], s[1], s[2], s[3]) for s in self.spots[:8]])

    def draw_towns(self, p, r, box):
        """Place names for orientation (Natural Earth): more of them the closer you are;
        region names too once quite close."""
        x0, y0, x1, y1 = box
        w = x1 - x0
        least = 1_000_000 if w > 40 else 300_000 if w > 20 else 100_000 if w > 10 else 25_000
        fm_font = T.font(T.MONO, 9, spacing=0.8)
        p.setFont(fm_font)
        fm = p.fontMetrics()
        taken = [QRectF(self.info.geometry())] if self.info.isVisible() else []
        if self.regions is not None and w < 30:
            p.setPen(QColor(152, 163, 176, 150))
            for rg in self.regions:
                lon, lat = rg["at"]
                if x0 <= lon <= x1 and y0 <= lat <= y1 and rg["name"]:
                    c = self.to_xy(lat, lon, r)
                    text = rg["name"].upper()
                    box = QRectF(c.x() - fm.horizontalAdvance(text) / 2, c.y() - fm.ascent(), fm.horizontalAdvance(text), fm.height())
                    if not any(box.intersects(o) for o in taken):
                        taken.append(box.adjusted(-4, -2, 4, 2))
                        p.drawText(box.bottomLeft() - QPointF(0, fm.descent()), text)
        towns = sorted((c for c in self.cities if c[4] >= least and x0 <= c[2] <= x1 and y0 <= c[1] <= y1),
                       key=lambda c: -c[4])[:60]
        for name, lat, lon, _, _ in towns:
            c = self.to_xy(lat, lon, r)
            box = QRectF(c.x() + 5, c.y() - fm.ascent() + 3, fm.horizontalAdvance(name), fm.height())
            if any(box.intersects(o) for o in taken):
                continue
            taken.append(box.adjusted(-3, -1, 3, 1))
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(QColor("#9aa6b4"))
            p.drawEllipse(c, 2.0, 2.0)
            p.setPen(QColor(T.SOFT))
            p.drawText(QPointF(c.x() + 5, c.y() + 3), name)

    def draw_cities(self, p, r, t):
        cities = self.city_hits.get(self.chosen.get("iso") or "", [])
        if not cities:
            return
        most = max(c[3] for c in cities)
        p.setFont(T.font(T.MONO, 10, spacing=1.0))
        for i, (name, lat, lon, n, _) in enumerate(cities[:12]):
            k = math.sqrt(n / most)
            self.dot(p, self.to_xy(lat, lon, r), 4 + 9 * k, k, t + i)
        self.labels(p, r, [(c[0], c[1], c[2], c[3]) for c in cities[:10]])

    def dot(self, p, c, rad, k, t):
        breathe = 1 + 0.08 * math.sin(t * 1.2)
        g = QRadialGradient(c, rad * 2.4 * breathe)
        g.setColorAt(0, QColor(127, 176, 224, int(120 + 80 * k)))
        g.setColorAt(0.35, QColor(127, 176, 224, int(40 + 40 * k)))
        g.setColorAt(1, QColor(127, 176, 224, 0))
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(g)
        p.drawEllipse(c, rad * 2.4 * breathe, rad * 2.4 * breathe)
        p.setBrush(QColor("#cfe3f6"))
        p.drawEllipse(c, max(2.0, rad * 0.32), max(2.0, rad * 0.32))

    def labels(self, p, r, items):
        """Names beside dots, never on top of one another or of the card."""
        fm = p.fontMetrics()
        taken = [QRectF(self.info.geometry())] if self.info.isVisible() else []
        for name, lat, lon, n in items:
            c = self.to_xy(lat, lon, r)
            text = f"{name.upper()} · {n}"
            w, h = fm.horizontalAdvance(text), fm.height()
            for dx, dy in ((8, -8), (8, h + 4), (-8 - w, -8), (-8 - w, h + 4)):
                box = QRectF(c.x() + dx, c.y() + dy - fm.ascent(), w, h).adjusted(-3, -2, 3, 2)
                if not any(box.intersects(o) for o in taken):
                    break
            else:
                continue
            taken.append(box)
            at = QPointF(c.x() + dx, c.y() + dy)
            p.setPen(QColor(0, 0, 0, 180))
            p.drawText(at + QPointF(1, 1), text)
            p.setPen(QColor(T.TEXT))
            p.drawText(at, text)
