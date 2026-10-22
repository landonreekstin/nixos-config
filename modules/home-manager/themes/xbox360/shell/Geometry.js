// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Geometry.js
// Blade geometry, on the console's reference frame: 1280x720 on a 16:9 screen.
//
// One uniform scale `s` (px per reference unit) maps it to the screen, chosen
// so the whole 1280 x 720 fits: a taller screen (16:10, a portrait monitor)
// gets a taller reference frame `H`, a wider one a wider `W`, and nothing is
// ever stretched. Every function takes `g` = { s, W, H, cf }, where `cf` is how
// curved the edges are (1 on the blades dashboard, 0 for the straight-sided
// frame around apps and full-screen pages; in between while morphing).
//
// Every edge on screen — each band and both sides of the open panel — is ONE
// curve: a smooth, even arc down the whole screen that bows toward the centre
// at mid-height, shifted to a different top-x. The knots are Config.curveY /
// Config.curveD, which blade.frag is generated from too, so the shader's panel
// mask and these polygons are the same curve by construction.
.pragma library
.import "Config.js" as Cfg

var KY = Cfg.curveY;
var KD = Cfg.curveD;
var N = KY.length;

// Horizontal offset of the curve at height y of the 720-tall frame.
// Catmull-Rom through the knots, clamped — blade.frag implements the same.
function curve(y) {
    if (y <= KY[0]) return KD[0];
    if (y >= KY[N - 1]) return KD[N - 1];
    var i = 0;
    while (i < N - 2 && y >= KY[i + 1]) i++;
    var p0 = KD[Math.max(i - 1, 0)], p1 = KD[i], p2 = KD[i + 1], p3 = KD[Math.min(i + 2, N - 1)];
    var t = (y - KY[i]) / (KY[i + 1] - KY[i]);
    var t2 = t * t, t3 = t2 * t;
    return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                  + (3 * p1 - p0 - 3 * p2 + p3) * t3);
}

// The curve at height y of a frame H tall: the arc always spans the screen.
function curveAt(y, g) { return g.cf * curve(y * 720 / g.H); }

// The reference frame for a screen of w x h pixels.
function frameFor(w, h) {
    var s = Math.min(w / 1280, h / 720);
    if (!(s > 0)) s = 1;
    return { s: s, W: w / s, H: h / s, cf: 1 };
}

// The reference frame for a PORTRAIT screen of w x h pixels: the dashboard
// turned a quarter (Frame.qml transposes its chrome), so the blades run
// across the screen and stack top to bottom. The header and footer stay
// upright across the top and bottom (`top`/`bottom` px); the turned stage
// is the rest, and is W x H reference units on its own, long side first.
// Inside it the panel's own header and footer bands would sit at the
// screen's left and right edges, so they shrink to a margin (`hb`/`fh`).
function verticalFrame(w, h) {
    var hb = Cfg.headerBottom, fh = Cfg.footerHeight;
    var s = Math.min(h / (1280 + hb + fh), w / 720);
    if (!(s > 0)) s = 1;
    var top = hb * s, bottom = fh * s;
    return { s: s, W: (h - top - bottom) / s, H: w / s, cf: 1,
             vertical: true, top: top, bottom: bottom, hb: 14, fh: 14 };
}

var ROWS = 48;
var WAIST = Cfg.curveDepth;   // how far the panel's sides bow in at mid-height

function lerp(x, y, t) { return x + (y - x) * t; }

// Where every band and the panel sit with blade `a` open (0-4) on the
// dashboard. Bands up to and including the open one stack on the LEFT of the
// panel and are mirrored; the rest stack on the right. Collapsed bands touch
// (width = pitch); the open blade's own band is a little wider. On a frame
// wider than 1280 the whole dashboard is centred.
function layout(a, W) {
    var ox = Math.max(0, (W - 1280) / 2);
    var left = ox + Cfg.leftStackX, P = Cfg.tabPitch;
    var L = left + P * a + Cfg.activeTabWidth;
    var R = L + Cfg.panelWidth;
    var tabs = [], widths = [], mirror = [], weight = [];
    for (var k = 0; k < 5; k++) {
        if (k <= a) {
            tabs.push(left + P * k);
            mirror.push(-1);
        } else {
            tabs.push(R + P * (k - a - 1));
            mirror.push(1);
        }
        widths.push(k === a ? Cfg.activeTabWidth : P);
        weight.push(k === a ? 1 : 0);
    }
    return { a: a, L: L, R: R, cf: 1, tabs: tabs, widths: widths, mirror: mirror, weight: weight };
}

// The straight-sided, full-width frame of a page or an app workspace, as the
// console draws its submenus: the open blade's panel grown to the screen
// edges, the bands dealt off either side.
function frame(a, W) {
    var P = Cfg.tabPitch, m = Cfg.frameMargin;
    var tabs = [], widths = [], mirror = [], weight = [];
    for (var k = 0; k < 5; k++) {
        if (k <= a) {
            tabs.push(-40 - P * (a - k + 1));
            mirror.push(-1);
        } else {
            tabs.push(W + 40 + P * (k - a - 1));
            mirror.push(1);
        }
        widths.push(k === a ? Cfg.activeTabWidth : P);
        weight.push(k === a ? 1 : 0);
    }
    return { a: a, L: m, R: W - m, cf: 0, tabs: tabs, widths: widths, mirror: mirror, weight: weight };
}

// The on-screen state part-way through a move. Every number is interpolated
// on its own, which is what makes a switch "re-deal the hand" rather than cut.
function mix(A, B, t) {
    var o = { a: t < 0.5 ? A.a : B.a, L: lerp(A.L, B.L, t), R: lerp(A.R, B.R, t),
              cf: lerp(A.cf, B.cf, t), tabs: [], widths: [], mirror: [], weight: [] };
    for (var k = 0; k < 5; k++) {
        o.tabs.push(lerp(A.tabs[k], B.tabs[k], t));
        o.widths.push(lerp(A.widths[k], B.widths[k], t));
        o.mirror.push(lerp(A.mirror[k], B.mirror[k], t));
        o.weight.push(lerp(A.weight[k], B.weight[k], t));
    }
    return o;
}

// x of an edge whose top is at topX, at height y. `m` is the mirror factor:
// -1 for the left-stack family, +1 for the right.
function edgeX(topX, m, y, g) { return topX + m * curveAt(y, g); }

// One edge as screen points, top to bottom.
function edge(topX, m, g) {
    var pts = [];
    for (var r = 0; r <= ROWS; r++) {
        var y = g.H * r / ROWS;
        pts.push(Qt.point(edgeX(topX, m, y, g) * g.s, y * g.s));
    }
    return pts;
}

// A closed ribbon between two edges: down the first, back up the second.
function ribbon(leftX, leftM, rightX, rightM, g) {
    var a = edge(leftX, leftM, g);
    var b = edge(rightX, rightM, g).reverse();
    var pts = a.concat(b);
    pts.push(a[0]);
    return pts;
}

function smooth(t) { return t * t * (3 - 2 * t); }

// The grey label box on a band: it fills the band's INNER side (toward the
// panel), leaving a light strip on the outer side; a rounded corner at `top`
// and, at Config.tabBoxStep, an S-curve back across the band to meet the inner
// edge by Config.tabBoxEnd. `m` < 0 is a left-stack band.
function tabBox(topX, width, m, top, g) {
    var step = Cfg.tabBoxStep, end = Cfg.tabBoxEnd, rad = Cfg.tabBoxRadius;
    var strip = width * Cfg.tabBoxInset;
    var leftSide = m < 0;
    function inner(y) { return edgeX(leftSide ? topX + width : topX, m, y, g); }
    function outer(y) { return edgeX(leftSide ? topX + strip : topX + width - strip, m, y, g); }
    var dir = leftSide ? 1 : -1;
    var pts = [];
    var n = 24, i, y;
    for (i = 0; i <= n; i++) {
        y = top + (end - top) * i / n;
        pts.push(Qt.point(inner(y) * g.s, y * g.s));
    }
    for (i = n; i >= 0; i--) {
        y = step + (end - step) * i / n;
        pts.push(Qt.point(lerp(outer(y), inner(y), smooth(i / n)) * g.s, y * g.s));
    }
    for (i = n; i >= 0; i--) {
        y = top + rad + (step - top - rad) * i / n;
        pts.push(Qt.point(outer(y) * g.s, y * g.s));
    }
    var cx = outer(top + rad) + dir * rad, cy = top + rad;
    for (i = 0; i <= 8; i++) {
        var ang = Math.PI / 2 * i / 8;
        pts.push(Qt.point((cx - dir * rad * Math.cos(ang)) * g.s, (cy - rad * Math.sin(ang)) * g.s));
    }
    pts.push(pts[0]);
    return pts;
}

// The content card's usable rectangle (reference units) inside a panel with
// edges L/R: inside the waist, between the header and footer bands (the
// frame's own `hb`/`fh` when it has them: a turned, portrait frame).
function cardRect(L, R, cf, g) {
    var inset = Cfg.cardInset + cf * WAIST;
    var hb = g.hb !== undefined ? g.hb : Cfg.headerBottom;
    var fh = g.fh !== undefined ? g.fh : Cfg.footerHeight;
    return { x: L + inset, y: hb, w: R - L - 2 * inset, h: g.H - fh - hb };
}
