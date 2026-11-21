// Album / playlist card: cover + name + subtitle. Click opens it.
import QtQuick
import Quickshell.Widgets

Rectangle {
    id: card
    required property var modelData
    property var colors
    signal opened()

    width: 158; height: 200; radius: 14
    color: hover.containsMouse ? Qt.alpha(colors.text, 0.08) : Qt.alpha(colors.surface, 0.35)
    Behavior on color { ColorAnimation { duration: 120 } }

    Column {
        anchors { fill: parent; margins: 10 }
        spacing: 6
        ClippingRectangle {
            width: 138; height: 138; radius: 10; color: Qt.alpha(card.colors.primary, 0.2)
            Image {
                anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(276, 276)
                source: card.modelData && card.modelData.images && card.modelData.images.length ? card.modelData.images[0].url : ""
            }
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: card.modelData ? card.modelData.name : ""
            color: card.colors.text; font { family: "Inter"; pixelSize: 13; weight: Font.Medium }
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: !card.modelData ? "" : card.modelData.type === "album"
                  ? (card.modelData.artists || []).map(a => a.name).join(", ")
                  : "Playlist · " + (card.modelData.owner ? card.modelData.owner.display_name : "")
            color: card.colors.textDim; font { family: "Inter"; pixelSize: 11 }
        }
    }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.opened() }
}
