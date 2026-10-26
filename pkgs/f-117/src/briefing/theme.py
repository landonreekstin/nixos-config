"""Colours, fonts and the angular shapes behind the F-117 look:
cool dark greys, faceted panels with cut corners that catch the light along their
top edge, a fine grain like matte paint, and one calm soft-blue accent.

He found the earlier amber accent stressful (2026-10-25) — keep the accent a calm
blue, and keep urgency signalled by brightness rather than warm colours.

Readability rules (he asked for it): reading text is never darker than META,
headlines are TEXT or brighter, and nothing he has to read is under 10pt."""

import random
from pathlib import Path

from PyQt6.QtCore import QPointF, QRectF
from PyQt6.QtGui import QColor, QFont, QFontDatabase, QImage, QPainterPath, QPixmap

ASSETS = Path(__file__).resolve().parent.parent / "assets"

BG = QColor("#0c0f13")
SIDEBAR = QColor("#080a0d")
FACET_SHADES = ["#0d1015", "#0f1218", "#11151b", "#0e1116", "#13171d", "#101419"]
CARD_TOP = QColor("#1c222a")  # cards are lit from above: lighter at the top
CARD_BOTTOM = QColor("#151a20")
CARD_HOVER = QColor("#222932")
ROW_HOVER = QColor("#242c36")
EDGE = QColor("#2b333d")
EDGE_HI = QColor("#414c59")
BEVEL = QColor("#566373")  # the lit top edge of a card
TEXT_BRIGHT = "#f2f5f8"  # titles
TEXT = "#e0e5eb"  # headlines
SOFT = "#bac3ce"  # snippets, subtitles
META = "#98a3b0"  # source / time lines
FAINT = "#6c7684"  # decoration only, never for reading

# The accent: a calm, soft steel blue. (Still called AMBER in code so every
# place that used the old accent follows automatically.)
ACCENT = QColor("#7fb0e0")
ACCENT_DIM = QColor("#4f7aa6")
ACCENT_BG = QColor(127, 176, 224, 30)
DARK_ON_ACCENT = QColor("#0b1622")
AMBER, AMBER_DIM, AMBER_BG, DARK_ON_AMBER = ACCENT, ACCENT_DIM, ACCENT_BG, DARK_ON_ACCENT

# kept for older names still used in a few places
PANEL = CARD_BOTTOM
PANEL_HOVER = CARD_HOVER
DIM = META

_grain = None


def grain():
    """A small tile of fine noise, painted faintly over backgrounds and cards
    for a matte, lightly textured finish."""
    global _grain
    if _grain is None:
        rnd = random.Random(117)
        img = QImage(160, 160, QImage.Format.Format_ARGB32)
        for y in range(160):
            for x in range(160):
                v = rnd.random()
                if v > 0.5:
                    img.setPixelColor(x, y, QColor(255, 255, 255, int((v - 0.5) * 22)))
                else:
                    img.setPixelColor(x, y, QColor(0, 0, 0, int((0.5 - v) * 34)))
        _grain = QPixmap.fromImage(img)
    return _grain


DISPLAY = "Rajdhani"
MONO = "Share Tech Mono"
BODY = "Noto Sans"


def load_fonts():
    for path in (ASSETS / "fonts").glob("*.ttf"):
        QFontDatabase.addApplicationFont(str(path))


def font(family, size, weight=QFont.Weight.Normal, spacing=0.0):
    f = QFont(family)
    f.setPointSizeF(size)
    f.setWeight(weight)
    if spacing:
        f.setLetterSpacing(QFont.SpacingType.AbsoluteSpacing, spacing)
    f.setHintingPreference(QFont.HintingPreference.PreferNoHinting)
    return f


def chamfer(rect: QRectF, cut: float, corners="tl br") -> QPainterPath:
    """A rectangle with its corners sliced off at 45 degrees."""
    c = {k: (cut if k in corners.split() else 0.0) for k in ("tl", "tr", "br", "bl")}
    x0, t, r, b = rect.left(), rect.top(), rect.right(), rect.bottom()
    pts = [
        QPointF(x0 + c["tl"], t),
        QPointF(r - c["tr"], t),
        QPointF(r, t + c["tr"]),
        QPointF(r, b - c["br"]),
        QPointF(r - c["br"], b),
        QPointF(x0 + c["bl"], b),
        QPointF(x0, b - c["bl"]),
        QPointF(x0, t + c["tl"]),
    ]
    path = QPainterPath(pts[0])
    for p in pts[1:]:
        path.lineTo(p)
    path.closeSubpath()
    return path


# Top-down outline of the F-117: sharp nose, swept wings, saw-tooth tail.
# (x, y) in a 0..1 box.
JET_OUTLINE = [
    (0.50, 0.00), (1.00, 0.80), (0.80, 0.86), (0.69, 0.72), (0.58, 0.92),
    (0.50, 0.80), (0.42, 0.92), (0.31, 0.72), (0.20, 0.86), (0.00, 0.80),
]

# Big flat facets painted very faintly behind everything.
BACKDROP_FACETS = [
    [(0.00, 0.00), (0.38, 0.00), (0.18, 0.42)],
    [(0.38, 0.00), (0.72, 0.00), (0.52, 0.30), (0.18, 0.42)],
    [(0.72, 0.00), (1.00, 0.00), (1.00, 0.36), (0.52, 0.30)],
    [(0.00, 0.42), (0.18, 0.42), (0.40, 1.00), (0.00, 1.00)],
    [(0.18, 0.42), (0.52, 0.30), (0.70, 0.74), (0.40, 1.00)],
    [(0.52, 0.30), (1.00, 0.36), (1.00, 1.00), (0.70, 0.74)],
    [(0.70, 0.74), (1.00, 1.00), (0.40, 1.00)],
]
