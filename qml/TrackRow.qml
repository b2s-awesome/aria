// One track in a list: cover, title/artist, album, length. Double-click (or Enter) plays it.
import QtQuick
import Quickshell.Widgets
import "icons.js" as I

Rectangle {
    id: row
    required property var modelData      // Spotify track object
    readonly property var track: modelData
    required property int index
    property var colors
    property bool current: false
    signal activated()

    width: ListView.view ? ListView.view.width : 600
    height: 56
    radius: 12
    color: current ? Qt.alpha(colors.primary, 0.22)
         : hover.containsMouse ? Qt.alpha(colors.text, 0.07) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    function fmt(ms) {
        const s = Math.floor(ms / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Row {
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 12
        width: parent.width - 20

        Text {
            width: 22; anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: row.current ? I.cp.music : (row.index + 1)
            font.family: row.current ? I.family : "Inter"; font.pixelSize: row.current ? 15 : 12
            color: row.current ? row.colors.primary : row.colors.textDim
        }
        ClippingRectangle {
            width: 40; height: 40; radius: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(row.colors.primary, 0.2)
            Image {
                anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(80, 80)
                source: {
                    const im = row.track && row.track.album ? row.track.album.images : [];
                    return im && im.length ? im[im.length - 1].url : "";
                }
            }
        }
        Column {
            width: (parent.width - 22 - 40 - 60 - 72) * 0.55
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width; elide: Text.ElideRight
                text: row.track ? row.track.name : ""
                color: row.current ? row.colors.primary : row.colors.text
                font { family: "Inter"; pixelSize: 14; weight: Font.Medium }
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: row.track && row.track.artists ? row.track.artists.map(a => a.name).join(", ") : ""
                color: row.colors.textDim; font { family: "Inter"; pixelSize: 12 }
            }
        }
        Text {
            width: (parent.width - 22 - 40 - 60 - 72) * 0.45
            anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
            text: row.track && row.track.album ? row.track.album.name : ""
            color: row.colors.textDim; font { family: "Inter"; pixelSize: 12 }
        }
        Text {
            width: 60; anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: row.track ? row.fmt(row.track.duration_ms) : ""
            color: row.colors.textDim; font { family: "Inter"; pixelSize: 12 }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent; hoverEnabled: true
        onDoubleClicked: row.activated()
    }
}
