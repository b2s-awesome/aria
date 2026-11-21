// Text filled like Spicy Lyrics' active lyrics: linear-gradient(rgba(text, .85) pos%,
// rgba(text, .35) pos+20%). Horizontal for words/letters, top→bottom for whole lines.
// Shader: shaders/gradient.frag (rebuild: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o shaders/gradient.frag.qsb shaders/gradient.frag)
import QtQuick

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

    ShaderEffect {
        width: label.width; height: label.height
        property var source: label
        property real pos: g.pos
        property real vertical: g.vertical ? 1 : 0
        property real lit: g.lit
        property real unlit: g.unlit
        fragmentShader: Qt.resolvedUrl("shaders/gradient.frag.qsb")
    }
}
