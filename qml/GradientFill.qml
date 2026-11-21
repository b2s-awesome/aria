// Text filled like Spicy Lyrics' active lyrics: linear-gradient(rgba(text, .85) pos%,
// rgba(text, .35) pos+20%). Horizontal for words/letters, top→bottom for whole lines.
import QtQuick
import QtQuick.Effects

Item {
    id: g
    property alias text: label.text
    property alias font: label.font
    property alias wrapMode: label.wrapMode
    property color color: "white"
    property real pos: -20                  // gradient position in %
    property bool vertical: false
    property real lit: 0.85
    property real unlit: 0.35

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text { id: label; width: g.width; color: g.color; visible: false; layer.enabled: true }

    // alpha at x (0..1) along the gradient
    function a(x) {
        const p1 = pos / 100, p2 = (pos + 20) / 100;
        return x <= p1 ? lit : x >= p2 ? unlit : lit + (unlit - lit) * (x - p1) / (p2 - p1);
    }
    Rectangle {
        id: mask
        anchors.fill: label; visible: false; layer.enabled: true
        gradient: Gradient {
            orientation: g.vertical ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, g.a(0)) }
            GradientStop { position: Math.max(0.001, Math.min(0.998, g.pos / 100)); color: Qt.rgba(1, 1, 1, g.a(g.pos / 100)) }
            GradientStop { position: Math.max(0.002, Math.min(0.999, (g.pos + 20) / 100)); color: Qt.rgba(1, 1, 1, g.a((g.pos + 20) / 100)) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, g.a(1)) }
        }
    }
    MultiEffect {
        anchors.fill: label; source: label
        maskEnabled: true; maskSource: mask
        maskThresholdMin: 0; maskSpreadAtMin: 1          // mask alpha → text alpha
    }
}
