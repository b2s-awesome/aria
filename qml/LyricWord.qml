// One word of word-synced lyrics, animated like Spicy Lyrics' "Spring" mode:
// scale / lift / glow springs chase curves of the word's progress; gradient sweeps across it.
// Words held ≥ 1000 ms split into letters that swell in turn (falloff 1/(1+d^2.8)).
import QtQuick
import QtQuick.Effects
import "spring.js" as Sp

Item {
    id: w
    property string text
    property real t: 0                       // ms
    property real end: 0
    property real clock: 0                   // current time (ms)
    property bool lineActive: false
    property font font
    property color color: "white"

    readonly property real dur: Math.max(1, end - t)
    readonly property int phase: clock < t ? 0 : clock >= end ? 2 : 1          // NotSung / Active / Sung
    readonly property real p: Math.max(0, Math.min(1, (clock - t) / dur))
    readonly property bool letters: dur >= 1000 && text.length > 1             // Spicy: IsLetterCapable

    implicitWidth: plain.implicitWidth
    implicitHeight: plain.implicitHeight

    property var sScale: Sp.make(1, Sp.S.scale[0], Sp.S.scale[1])
    property var sY: Sp.make(0, Sp.S.y[0], Sp.S.y[1])
    property var sGlow: Sp.make(0, Sp.S.glow[0], Sp.S.glow[1])
    property real scaleV: 1
    property real yV: 0
    property real glowV: 0

    FrameAnimation {
        running: w.lineActive || !(Sp.resting(w.sScale) && Sp.resting(w.sY) && Sp.resting(w.sGlow))
        onTriggered: {
            const x = !w.lineActive ? 1 : w.phase === 0 ? 0 : w.phase === 2 ? 1 : w.p;
            w.sScale.goal = Sp.at(Sp.ScaleRange, x);
            w.sY.goal = Sp.at(Sp.YOffsetRange, x);
            w.sGlow.goal = w.letters ? 0 : Sp.at(Sp.GlowRange, x);
            const dt = Math.min(0.05, frameTime);
            w.scaleV = Sp.step(w.sScale, dt);
            w.yV = Sp.step(w.sY, dt);
            w.glowV = Sp.step(w.sGlow, dt);
        }
    }

    Item {
        id: body
        width: parent.width; height: parent.height
        transform: [
            Scale { origin.x: body.width / 2; origin.y: body.height; xScale: w.letters ? 1 : w.scaleV; yScale: xScale },
            Translate { y: w.letters ? 0 : w.font.pixelSize * w.yV }
        ]

        // inactive line: plain text (Spicy only applies the gradient inside the active line)
        Text { id: plain; text: w.text; font: w.font; color: w.color; visible: !w.lineActive }

        GradientFill {
            visible: w.lineActive && !w.letters
            width: plain.implicitWidth; height: plain.implicitHeight
            text: w.text; font: w.font; color: w.color
            pos: Sp.gradientPos(w.phase, w.p)
        }

        Row {
            visible: w.lineActive && w.letters
            Repeater {
                model: w.letters ? w.text.split("") : []
                LyricLetter {
                    word: w
                    count: w.text.length
                    font: w.font; color: w.color
                }
            }
        }

        // glow: text-shadow 0 0 (4 + 2g)px rgba(text, min(g·35, 100)%)
        layer.enabled: w.glowV > 0.01
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: w.color
            blurMax: 32; shadowBlur: (4 + 2 * w.glowV) / 32
            shadowOpacity: Math.min(1, w.glowV * 0.35)
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
        }
    }
}
