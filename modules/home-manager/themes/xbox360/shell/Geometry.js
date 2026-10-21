// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Geometry.js
// Blade geometry. Everything is laid out on the console's 1280x720 reference
// frame and scaled to the screen, so a 2400x1350 monitor and a 1280x800 VM show
// the same dashboard.
//
// Every edge on screen — each band and both sides of the open panel — is ONE
// curve: a smooth, even arc down the whole screen that bows toward the centre
// at mid-height, shifted to a different top-x. The knots are Config.curveY / Config.curveD, which
// blade.frag is generated from too, so the shader's panel mask and these
// polygons are the same curve by construction.
.pragma library
.import "Config.js" as Cfg

var KY = Cfg.curveY;
var KD = Cfg.curveD;
var N = KY.length;

// Horizontal offset of the curve at reference height y. Catmull-Rom through
// the knots, clamped at both ends — blade.frag implements the same formula.
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

// Sampled once: 49 rows from y = 0 to 720.
var ROWS = 48;
var PROFILE = (function () {
    var out = [];
    for (var r = 0; r <= ROWS; r++) {
        var y = 720 * r / ROWS;
        out.push({ y: y, d: curve(y) });
    }
    return out;
})();

// Where every band and the panel sit with blade `a` open (0-4), or with the
// sixth, "steel" state (a = 5) used for workspaces past the five blades.
// Bands up to and including the open one stack on the LEFT of the panel and
// are mirrored; the rest stack on the right. Collapsed bands touch (width =
// pitch); the open blade's own band is a little wider, as on the console.
function layout(a) {
    var left = Cfg.leftStackX, P = Cfg.tabPitch;
    var L = a < 5 ? left + P * a + Cfg.activeTabWidth : left + P * 5;
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
        weight.push(k === a ? 1 : 0);   // 1 = this band wears the blade colour
    }
    return { a: a, L: L, R: R, tabs: tabs, widths: widths, mirror: mirror, weight: weight };
}

function lerp(x, y, t) { return x + (y - x) * t; }

// The on-screen state part-way through a blade move. Every number is
// interpolated on its own, which is what makes a switch "re-deal the hand"
// rather than cut: bands slide to their new slots, and one crossing from one
// stack to the other straightens and flips its curve on the way.
function mix(A, B, t) {
    var o = { a: t < 0.5 ? A.a : B.a, L: lerp(A.L, B.L, t), R: lerp(A.R, B.R, t),
              tabs: [], widths: [], mirror: [], weight: [] };
    for (var k = 0; k < 5; k++) {
        o.tabs.push(lerp(A.tabs[k], B.tabs[k], t));
        o.widths.push(lerp(A.widths[k], B.widths[k], t));
        o.mirror.push(lerp(A.mirror[k], B.mirror[k], t));
        o.weight.push(lerp(A.weight[k], B.weight[k], t));
    }
    return o;
}

// One edge as screen points, top to bottom. `m` is the mirror factor: -1 for
// the left-stack family, +1 for the right, anything between while flipping.
function edgeX(topX, m, y) { return topX + m * curve(y); }
function edge(topX, m, sx, sy) {
    var pts = [];
    for (var r = 0; r <= ROWS; r++) {
        var p = PROFILE[r];
        pts.push(Qt.point((topX + m * p.d) * sx, p.y * sy));
    }
    return pts;
}

// A closed ribbon between two edges: down the first, back up the second.
function ribbon(leftX, leftM, rightX, rightM, sx, sy) {
    var a = edge(leftX, leftM, sx, sy);
    var b = edge(rightX, rightM, sx, sy).reverse();
    var pts = a.concat(b);
    pts.push(a[0]);
    return pts;
}

function smooth(t) { return t * t * (3 - 2 * t); }

// The grey label box on a band, as on the console: it fills the band's INNER
// side (toward the panel), leaving a light strip on the outer side; it starts
// with a rounded corner at `top` and, at `step`, S-curves back across the band
// to meet the inner edge by `end`. `m` < 0 is a left-stack band (box on the
// right of the band), > 0 a right-stack one (box on the left).
function tabBox(topX, width, m, top, sx, sy) {
    var step = Cfg.tabBoxStep, end = Cfg.tabBoxEnd, rad = Cfg.tabBoxRadius;
    var strip = width * Cfg.tabBoxInset;
    var leftSide = m < 0;
    // x of the band's inner edge, and of the box's outer boundary, at y.
    function inner(y) { return edgeX(leftSide ? topX + width : topX, m, y); }
    function outer(y) { return edgeX(leftSide ? topX + strip : topX + width - strip, m, y); }
    var dir = leftSide ? 1 : -1;      // from the outer boundary toward the inner edge
    var pts = [];
    var n = 24, i, y;
    // Down the inner edge.
    for (i = 0; i <= n; i++) {
        y = top + (end - top) * i / n;
        pts.push(Qt.point(inner(y) * sx, y * sy));
    }
    // The S back up from `end` to `step`, ending on the outer boundary.
    for (i = n; i >= 0; i--) {
        y = step + (end - step) * i / n;
        var t = smooth(i / n);
        pts.push(Qt.point(lerp(outer(y), inner(y), t) * sx, y * sy));
    }
    // Up the outer boundary to the start of the rounded corner.
    for (i = n; i >= 0; i--) {
        y = top + rad + (step - top - rad) * i / n;
        pts.push(Qt.point(outer(y) * sx, y * sy));
    }
    // The corner: a quarter circle from the outer boundary onto the top edge.
    var cx = outer(top + rad) + dir * rad, cy = top + rad;
    for (i = 0; i <= 8; i++) {
        var ang = Math.PI / 2 * i / 8;
        pts.push(Qt.point((cx - dir * rad * Math.cos(ang)) * sx, (cy - rad * Math.sin(ang)) * sy));
    }
    pts.push(pts[0]);
    return pts;
}

// How far the panel's edges bow in at mid-height: tiled windows are kept
// inside the narrowest part (see Blades.qml).
var WAIST = (function () {
    var w = 0;
    for (var r = 0; r <= ROWS; r++) w = Math.min(w, PROFILE[r].d);
    return -w;
})();
