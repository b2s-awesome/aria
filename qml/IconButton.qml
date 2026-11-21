// Round icon button: soft accent halo on hover, bounce on press, dot under it when active.
import QtQuick
import "icons.js" as I

Item {
    id: b
    property var colors
    property string icon
    property int size: 38
    property int iconSize: 19
    property bool active: false
    property bool enabledState: true
    signal clicked()

    width: size; height: size
    opacity: enabledState ? 1 : 0.35
    scale: m.pressed ? 0.86 : 1
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Rectangle {
        anchors.fill: parent; radius: width / 2
        color: Qt.alpha(b.colors.primary, m.containsMouse ? 0.16 : 0)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Text {
        anchors.centerIn: parent
        text: I.cp[b.icon] ?? ""
        font.family: I.family; font.pixelSize: b.iconSize
        color: (b.active || m.containsMouse) ? b.colors.primary : b.colors.text
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Rectangle {
        visible: b.active
        width: 4; height: 4; radius: 2; color: b.colors.primary
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -2 }
    }
    MouseArea {
        id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (b.enabledState) b.clicked()
    }
}
