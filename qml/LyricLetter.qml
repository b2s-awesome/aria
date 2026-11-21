// One letter of a held word (Spicy Lyrics letter group): springs chase the letter curves,
// strongest at the letter being sung and falling off with distance (scale/y 1/(1+d^2.8), glow 1/(1+0.9d)).
import QtQuick
import QtQuick.Effects
import "spring.js" as Sp

Item {
    id: l
    required property string modelData
    required property int index
    property var word                        // the LyricWord
    property int count: 1
    property font font
    property color color: "white"

    implicitWidth: g.implicitWidth
    implicitHeight: g.implicitHeight

    readonly property real lp: Math.max(0, Math.min(1, word.p * count - index))   // this letter's progress

    property var sScale: Sp.make(1, Sp.S.scale[0], Sp.S.scale[1])
    property var sY: Sp.make(0, Sp.S.y[0], Sp.S.y[1])
    property var sGlow: Sp.make(0, Sp.S.glow[0], Sp.S.glow[1])
    property real scaleV: 1
    property real yV: 0
    property real glowV: 0

    FrameAnimation {
        running: l.word.lineActive || !(Sp.resting(l.sScale) && Sp.resting(l.sY) && Sp.resting(l.sGlow))
        onTriggered: {
            const st = l.word.lineActive ? l.word.phase : 2;
            if (st === 1) {
                const active = l.word.p * l.count;                    // fractional index of the sung letter
                const ai = Math.min(l.count - 1, Math.floor(active));
                const ap = active - ai;                               // progress through that letter
                const d = Math.abs(l.index - ai);
                const fall = Math.max(0, 1 / (1 + Math.pow(d, 2.8)));
                const gfall = Math.max(0, 1 / (1 + d * 0.9));
                l.sScale.goal = 1 + (Sp.at(Sp.LetterScaleRange, ap) - 1) * fall;
                l.sY.goal = Sp.at(Sp.LetterYOffsetRange, ap) * 2 * fall;
                l.sGlow.goal = Sp.at(Sp.GlowRange, ap) * gfall;
            } else {
                l.sScale.goal = st === 0 ? Sp.LetterScaleRange[0][1] : 1;
                l.sY.goal = st === 0 ? Sp.LetterYOffsetRange[0][1] * 2 : 0;
                l.sGlow.goal = 0;
            }
            const dt = Math.min(0.05, frameTime);
            l.scaleV = Sp.step(l.sScale, dt);
            l.yV = Sp.step(l.sY, dt);
            l.glowV = Sp.step(l.sGlow, dt);
        }
    }

    GradientFill {
        id: g
        width: implicitWidth; height: implicitHeight
        text: l.modelData; font: l.font; color: l.color
        pos: l.word.phase === 0 ? -20 : l.word.phase === 2 ? 100 : -20 + 120 * Sp.easeSinOut(l.lp)
        transform: [
            Scale { origin.x: g.width / 2; origin.y: g.height; xScale: l.scaleV; yScale: l.scaleV },
            Translate { y: l.font.pixelSize * l.yV }
        ]
        // letter glow: blur 4 + 12g px, opacity g · 185%
        layer.enabled: l.glowV > 0.01
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: l.color
            blurMax: 32; shadowBlur: (4 + 12 * l.glowV) / 32
            shadowOpacity: Math.min(1, l.glowV * 1.85)
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        }
    }
}
