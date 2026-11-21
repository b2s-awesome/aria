// Thin bar that thickens and shows a knob on hover. value: 0..1. Emits picked(fraction).
import QtQuick

Item {
    id: s
    property var colors
    property real value: 0
    property color fill: colors.primary
    signal picked(real fraction)

    height: 14
    readonly property bool hot: m.containsMouse || m.pressed

    Rectangle {
        id: groove
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: s.hot ? 6 : 4; radius: height / 2
        color: Qt.alpha(s.colors.text, 0.15)
        Behavior on height { NumberAnimation { duration: 120 } }
        Rectangle {
            height: parent.height; radius: parent.radius
            width: parent.width * Math.max(0, Math.min(1, s.value))
            color: s.hot ? s.fill : Qt.alpha(s.fill, 0.85)
        }
    }
    Rectangle {
        width: 12; height: 12; radius: 6
        color: s.colors.text
        x: groove.width * Math.max(0, Math.min(1, s.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        opacity: s.hot ? 1 : 0; scale: s.hot ? 1 : 0.4
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
    }
    MouseArea {
        id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: e => s.picked(Math.max(0, Math.min(1, e.x / width)))
    }
}
