.pragma library
// Springs + curves from Spicy Lyrics (src/modules/Spring.ts, Animator/Lyrics/LyricsAnimator.ts).
// Spring(position, frequency Hz, damping ratio); step(dt seconds).

function make(p, freq, damping) {
    return { p: p, v: 0, goal: p, w: freq * 2 * Math.PI, d: damping };
}

function step(s, dt) {
    const n = Math.max(1, Math.ceil(dt / 0.004));          // small substeps keep it stable
    const h = dt / n;
    for (let i = 0; i < n; i++) {
        const a = -s.w * s.w * (s.p - s.goal) - 2 * s.d * s.w * s.v;
        s.v += a * h;
        s.p += s.v * h;
    }
    return s.p;
}

function resting(s) {                                      // Spicy's CanSleep thresholds
    return (s.p - s.goal) * (s.p - s.goal) <= Math.pow(1 / 3840, 2) && s.v * s.v <= 0.0001;
}

// Piecewise curve through [x, y] points, eased between them
function at(pts, x) {
    if (x <= pts[0][0]) return pts[0][1];
    for (let i = 1; i < pts.length; i++) {
        if (x <= pts[i][0]) {
            const a = pts[i - 1], b = pts[i];
            const t = (x - a[0]) / (b[0] - a[0]);
            return a[1] + (b[1] - a[1]) * (0.5 - Math.cos(t * Math.PI) / 2);
        }
    }
    return pts[pts.length - 1][1];
}

// Spicy's curves (non-Bloom "Spring" mode)
var ScaleRange        = [[0, 0.95], [0.7, 1.0505], [1, 1]];
var YOffsetRange      = [[0, 1 / 100], [0.9, -(1 / 60)], [1, 0]];          // × font size
var GlowRange         = [[0, 0], [0.15, 1], [0.6, 1], [1, 0]];
var LetterScaleRange  = [[0, 0.95], [0.7, 1.175], [1, 1]];
var LetterYOffsetRange = [[0, 0.01], [0.9, -(1 / 56)], [1, 0]];            // × font size × 2
var LineGlowRange     = [[0, 0], [0.5, 1], [1, 0]];
var DotScale          = [[0, 0.75], [0.7, 1.05], [1, 1]];
var DotYOffset        = [[0, 0], [0.9, -0.12], [1, 0]];                     // em
var DotGlow           = [[0, 0], [0.6, 1], [1, 1]];
var DotOpacity        = [[0, 0.35], [0.6, 1], [1, 1]];

// spring settings [frequency, damping]
var S = { scale: [0.88, 0.64], y: [1.45, 0.4], glow: [1.18, 0.56], lineGlow: [1, 0.5],
          dotScale: [0.7, 0.6], dotY: [1.25, 0.4], dotGlow: [1, 0.5], dotOpacity: [1, 0.5] };

function easeSinOut(x) { return Math.sin(x * Math.PI / 2); }

// gradient position (%) like Spicy: NotSung -20, Active -20 + 120p, Sung 100
function gradientPos(state, p) { return state === 0 ? -20 : state === 2 ? 100 : -20 + 120 * p; }

// self-check
(function () {
    const s = make(0, 1.45, 0.4); s.goal = 1;
    for (let i = 0; i < 300; i++) step(s, 1 / 60);
    if (Math.abs(s.p - 1) > 0.01) console.warn("spring.js: spring does not settle");
    if (at(ScaleRange, 0.7) !== 1.0505 || at(ScaleRange, 0) !== 0.95) console.warn("spring.js: curve broken");
})();
