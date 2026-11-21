// The hero button: accent gradient disc with a soft glow; grows on hover, squishes on press.
import QtQuick
import QtQuick.Effects
import "icons.js" as I

Item {
    id: b
    property var colors
    property bool playing: false
    property int size: 48
    signal clicked()

    width: size; height: size
    scale: m.pressed ? 0.9 : (m.containsMouse ? 1.07 : 1)
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

    Rectangle {
        id: disc
        anchors.fill: parent; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(b.colors.primary, 1.35) }
            GradientStop { position: 1.0; color: b.colors.primary }
        }
        visible: false
    }
    MultiEffect {
        source: disc; anchors.fill: disc
        shadowEnabled: true; shadowColor: b.colors.primary
        shadowBlur: 0.9; shadowOpacity: m.containsMouse ? 0.75 : 0.45
        shadowHorizontalOffset: 0; shadowVerticalOffset: 3
        Behavior on shadowOpacity { NumberAnimation { duration: 180 } }
    }
    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: b.playing ? 0 : 1      // optical centring of the triangle
        text: b.playing ? I.cp.pause : I.cp.play
        font.family: I.family; font.pixelSize: b.size * 0.44
        color: b.colors.accentText
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
