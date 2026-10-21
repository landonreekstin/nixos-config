// ~/nixos-config/modules/home-manager/themes/xbox360/shell/Geometry.js
// Blade geometry. Everything is laid out on the console's 1280x720 reference
// frame and scaled to the screen, so a 2400x1350 monitor and a 1280x800 VM show
// the same dashboard.
//
// Every edge on screen — each collapsed tab and both sides of the open panel —
// is ONE curve, the "lazy S", shifted to a different top-x: straight off the
// top, a near-vertical shoulder, a slight inward bow at the waist, then a flare
// out through the bottom. The knots are Config.curveY / Config.curveD, which
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

// Where every tab and the panel sit with blade `a` open (0-4), or with the
// sixth, "steel" state (a = 5) used for workspaces past the five blades.
// Tabs up to and including the open one fan out on the LEFT of the panel and
// are mirrored (bow right, flare left); the rest fan out on the right.
function layout(a) {
    var L = Cfg.leftStackX + Cfg.tabPitch * a + Cfg.tabWidth;
    var R = L + Cfg.panelWidth;
    var tabs = [], mirror = [], weight = [];
    for (var k = 0; k < 5; k++) {
        if (k <= a) {
            tabs.push(Cfg.leftStackX + Cfg.tabPitch * k);
            mirror.push(-1);
        } else {
            tabs.push(R + Cfg.tabPitch * (k - a - 1));
            mirror.push(1);
        }
        weight.push(k === a ? 1 : 0);   // 1 = this tab wears the blade colour
    }
    return { a: a, L: L, R: R, tabs: tabs, mirror: mirror, weight: weight };
}

function lerp(x, y, t) { return x + (y - x) * t; }

// The on-screen state part-way through a blade move. Every number is
// interpolated on its own, which is what makes a switch "re-deal the hand"
// rather than cut: tabs slide to their new slots, and one crossing from one
// stack to the other straightens and flips its curve on the way.
function mix(A, B, t) {
    var o = { a: t < 0.5 ? A.a : B.a, L: lerp(A.L, B.L, t), R: lerp(A.R, B.R, t),
              tabs: [], mirror: [], weight: [] };
    for (var k = 0; k < 5; k++) {
        o.tabs.push(lerp(A.tabs[k], B.tabs[k], t));
        o.mirror.push(lerp(A.mirror[k], B.mirror[k], t));
        o.weight.push(lerp(A.weight[k], B.weight[k], t));
    }
    return o;
}

// One edge as screen points, top to bottom. `m` is the mirror factor: -1 for
// the left-stack family, +1 for the right, anything between while flipping.
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

// The panel's waist: the narrowest it gets, which is the rectangle tiled
// windows are kept inside (see Reserve.qml).
var WAIST = (function () {
    var w = 0;
    for (var r = 0; r <= ROWS; r++) w = Math.min(w, PROFILE[r].d);
    return -w;
})();
