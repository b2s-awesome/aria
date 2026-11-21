// Aria — a frosted, persona-themed Spotify client for the rice.
// Playback: the official Spotify app, hidden (Spotify blocks librespot/spotifyd audio keys on this account). Browsing/control: Spotify Web API.
// Run: qs -c aria   ·   Super+N: qs -c aria ipc call aria toggle
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "icons.js" as I

ShellRoot {
    id: root

    Colors { id: c }
    FontLoader { source: "file:///usr/share/noctalia/assets/fonts/noctalia-tabler.ttf" }   // Tabler, as in Noctalia
    Api { id: api }
    Lyrics { id: lyrics; item: player.item }
    Player { id: player; api: api; fast: win.visible }

    property bool shown: false
    property bool nowPlaying: false        // lyrics view (in the window)
    property bool fullscreen: false        // …taking over the whole monitor
    onNowPlayingChanged: if (!nowPlaying) fullscreen = false
    property string view: "home"            // home | search | liked | albums | playlist | album
    property string heading: "Home"
    property string subheading: ""
    property string headerArt: ""
    property var tracks: []                 // track objects shown in the list
    property string contextUri: ""          // album/playlist uri, or "" = play `tracks` as a list
    property var playlists: []
    property var albums: []
    property var searchAlbums: []
    property var searchPlaylists: []
    property string meId: ""

    IpcHandler {
        target: "aria"
        function toggle(): void { root.shown = !root.shown }
        function show(): void   { root.shown = true }
        function hide(): void   { root.shown = false }
        function lyrics(): void { root.shown = true; root.nowPlaying = !root.nowPlaying; root.fullscreen = root.nowPlaying }
    }

    // ---- data loading -------------------------------------------------------------------
    function open(v, arg) {
        view = v; tracks = []; contextUri = ""; headerArt = ""; subheading = "";
        if (v === "home") {
            heading = "Recently played";
            api.get("/me/player/recently-played?limit=50", d => {
                const seen = {}, out = [];
                (d && d.items || []).forEach(i => { if (i.track && !seen[i.track.id]) { seen[i.track.id] = 1; out.push(i.track); } });
                tracks = out;
            });
        } else if (v === "liked") {
            heading = "Liked Songs"; subheading = "Your library";
            api.get("/me/tracks?limit=50", d => tracks = (d && d.items || []).map(i => i.track).filter(t => t));
        } else if (v === "albums") {
            heading = "Albums";
            api.get("/me/albums?limit=50", d => albums = (d && d.items || []).map(i => i.album));
        } else if (v === "playlist") {
            heading = arg.name; subheading = "Playlist · " + (arg.owner ? arg.owner.display_name : "");
            headerArt = arg.images && arg.images.length ? arg.images[0].url : "";
            contextUri = arg.uri;
            const load = (path, fallback) => api.get(path, (d, s) => {
                if (s >= 400 && fallback) return load(fallback, null);
                tracks = (d && d.items || []).map(i => i.track || i.item).filter(t => t && t.type === "track");
            });
            load("/playlists/" + arg.id + "/tracks?limit=100", "/playlists/" + arg.id + "/items?limit=100");
        } else if (v === "album") {
            api.get("/albums/" + arg.id, d => {
                if (!d) return;
                heading = d.name; subheading = "Album · " + d.artists.map(a => a.name).join(", ");
                headerArt = d.images && d.images.length ? d.images[0].url : "";
                contextUri = d.uri;
                tracks = (d.tracks && d.tracks.items || []).map(t => Object.assign({}, t, { album: d }));
            });
        } else if (v === "search") {
            heading = "Search";
        }
    }

    function search(q) {
        if (q.trim() === "") return;
        view = "search"; heading = "Results for “" + q + "”"; contextUri = "";
        api.get("/search?type=track,album,playlist&limit=20&q=" + encodeURIComponent(q), d => {
            tracks = d && d.tracks ? d.tracks.items.filter(t => t) : [];
            searchAlbums = d && d.albums ? d.albums.items.filter(a => a) : [];
            searchPlaylists = d && d.playlists ? d.playlists.items.filter(p => p) : [];
        });
    }

    function playTrack(i) {
        const t = tracks[i];
        if (!t) return;
        if (contextUri !== "") player.play({ context_uri: contextUri, offset: { uri: t.uri } });
        else player.play({ uris: tracks.slice(i, i + 100).map(x => x.uri) });
    }
    function playAll() {
        if (contextUri !== "") player.play({ context_uri: contextUri });
        else if (tracks.length) player.play({ uris: tracks.slice(0, 100).map(x => x.uri) });
    }

    Component.onCompleted: {
        api.get("/me", d => meId = d ? d.id : "");
        api.get("/me/playlists?limit=50", d => playlists = d && d.items ? d.items.filter(p => p) : []);
        open("home");
    }

    function fmt(ms) {
        const s = Math.floor(Math.max(0, ms) / 1000);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // ---- window ---------------------------------------------------------------------------
    FloatingWindow {
        id: win
        title: "Aria"
        visible: root.shown
        implicitWidth: 1180
        implicitHeight: 760
        color: "transparent"                    // Hyprland blurs everything behind the glass

        onVisibleChanged: if (visible) player.refresh()

        Connections {
            target: root
            function onFullscreenChanged() { fsTimer.restart() }
        }
        Timer {                                // whole-monitor fullscreen while in the lyrics view;
            id: fsTimer; interval: 250         // delayed so the window is mapped + focused first
            onTriggered: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.window.fullscreen({ mode = 'fullscreen', action = '" + (root.fullscreen ? "set" : "unset") + "' })"])
        }

        ClippingRectangle {
            anchors.fill: parent
            color: Qt.alpha(c.surface, 0.62)
            radius: 0

            // ---- sidebar ----
            Rectangle {
                id: sidebar
                visible: !root.nowPlaying
                anchors { left: parent.left; top: parent.top; bottom: bar.top; margins: 12; rightMargin: 0 }
                width: 230; radius: 18
                color: Qt.alpha(c.surface, 0.45)

                Column {
                    id: nav
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 4

                    Text { text: "Aria"; color: c.primary; font { family: "Inter Display"; pixelSize: 26; weight: Font.Bold } bottomPadding: 10 }

                    Repeater {
                        model: [
                            { v: "home",   label: "Home",        glyph: I.cp.home },
                            { v: "search", label: "Search",      glyph: I.cp.search },
                            { v: "liked",  label: "Liked Songs", glyph: I.cp.heart },
                            { v: "albums", label: "Albums",      glyph: I.cp.vinyl }
                        ]
                        Rectangle {
                            required property var modelData
                            width: nav.width; height: 38; radius: 10
                            color: root.view === modelData.v ? Qt.alpha(c.primary, 0.2) : (navHover.containsMouse ? Qt.alpha(c.text, 0.06) : "transparent")
                            Row {
                                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                spacing: 12
                                Text { text: modelData.glyph; font.family: I.family; font.pixelSize: 18; color: root.view === modelData.v ? c.primary : c.text }
                                Text { text: modelData.label; font { family: "Inter"; pixelSize: 14; weight: Font.Medium } color: root.view === modelData.v ? c.primary : c.text }
                            }
                            MouseArea {
                                id: navHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.open(modelData.v); if (modelData.v === "search") searchBox.forceActiveFocus(); }
                            }
                        }
                    }

                    Text { text: "PLAYLISTS"; color: c.textDim; font { family: "Inter"; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.2 } topPadding: 16; bottomPadding: 4; leftPadding: 4 }
                }

                ListView {
                    anchors { left: parent.left; right: parent.right; top: nav.bottom; bottom: parent.bottom; margins: 14; topMargin: 2 }
                    clip: true; spacing: 2
                    model: root.playlists
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width; height: 46; radius: 10
                        color: (root.view === "playlist" && root.contextUri === modelData.uri) ? Qt.alpha(c.primary, 0.2)
                             : (plHover.containsMouse ? Qt.alpha(c.text, 0.06) : "transparent")
                        Row {
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                            spacing: 10
                            ClippingRectangle {
                                width: 34; height: 34; radius: 7; color: Qt.alpha(c.primary, 0.2)
                                Image { anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(68, 68)
                                        source: modelData.images && modelData.images.length ? modelData.images[modelData.images.length - 1].url : "" }
                            }
                            Text { width: 150; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                   text: modelData.name; color: c.text; font { family: "Inter"; pixelSize: 13 } }
                        }
                        MouseArea { id: plHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.open("playlist", modelData) }
                    }
                }
            }

            // ---- main ----
            Item {
                id: main
                visible: !root.nowPlaying
                anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: bar.top; margins: 12 }

                // search field
                Rectangle {
                    id: searchField
                    visible: root.view === "search"
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: visible ? 46 : 0; radius: 23
                    color: Qt.alpha(c.surface, 0.55)
                    border.width: searchBox.activeFocus ? 2 : 1
                    border.color: searchBox.activeFocus ? c.primary : Qt.alpha(c.outline, 0.4)
                    Text { anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                           text: I.cp.search; font.family: I.family; font.pixelSize: 18; color: c.textDim }
                    TextInput {
                        id: searchBox
                        anchors { left: parent.left; right: parent.right; leftMargin: 48; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        color: c.text; font { family: "Inter"; pixelSize: 15 }
                        selectionColor: Qt.alpha(c.primary, 0.4); clip: true
                        onAccepted: root.search(text)
                        Text { visible: !parent.text; text: "What do you want to listen to?"; color: c.textDim; font: parent.font }
                    }
                }

                // header (title, art, play button)
                Row {
                    id: header
                    anchors { left: parent.left; right: parent.right; top: searchField.bottom; topMargin: searchField.visible ? 14 : 4 }
                    spacing: 20
                    height: Math.max(root.headerArt ? 150 : 0, headerCol.implicitHeight)

                    ClippingRectangle {
                        visible: root.headerArt !== ""
                        width: 150; height: 150; radius: 16; color: Qt.alpha(c.primary, 0.2)
                        Image { anchors.fill: parent; source: root.headerArt; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    }
                    Column {
                        id: headerCol
                        anchors.bottom: parent.bottom; spacing: 6
                        Text { text: root.subheading; visible: text !== ""; color: c.textDim; font { family: "Inter"; pixelSize: 13 } }
                        Text { text: root.heading; color: c.text; font { family: "Inter Display"; pixelSize: root.headerArt ? 38 : 30; weight: Font.Bold }
                               width: main.width - 190; elide: Text.ElideRight }
                        PlayButton {
                            visible: root.tracks.length > 0 && root.view !== "search"
                            colors: c; size: 52
                            playing: player.playing && root.contextUri !== "" && player.state && player.state.context && player.state.context.uri === root.contextUri
                            onClicked: playing ? player.toggle() : root.playAll()
                        }
                    }
                }

                // album / playlist cards (Albums view and search results)
                ListView {
                    id: cards
                    visible: root.view === "search" && (root.searchAlbums.length + root.searchPlaylists.length) > 0
                    anchors { left: parent.left; right: parent.right; top: header.bottom; topMargin: 14 }
                    height: visible ? 196 : 0
                    orientation: ListView.Horizontal; spacing: 14; clip: true
                    model: root.searchAlbums.concat(root.searchPlaylists)
                    delegate: Card { colors: c; onOpened: root.open(modelData.type === "album" ? "album" : "playlist", modelData) }
                }

                GridView {
                    id: albumGrid
                    visible: root.view === "albums"
                    anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom; topMargin: 14 }
                    cellWidth: 172; cellHeight: 214; clip: true
                    model: root.albums
                    delegate: Card { colors: c; onOpened: root.open("album", modelData) }
                }

                ListView {
                    id: list
                    visible: root.view !== "albums"
                    anchors { left: parent.left; right: parent.right; top: cards.bottom; bottom: parent.bottom; topMargin: 12 }
                    clip: true; spacing: 2
                    model: root.tracks
                    delegate: TrackRow {
                        colors: c
                        current: player.item && modelData && player.item.id === modelData.id
                        onActivated: root.playTrack(index)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.tracks.length === 0 && root.view !== "search"
                        text: api.lastError !== "" ? api.lastError : "Loading…"
                        color: c.textDim; font { family: "Inter"; pixelSize: 14 }
                    }
                }
            }

            // ---- now-playing bar ----
            Rectangle {
                id: bar
                visible: !root.nowPlaying
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                height: 88; radius: 20
                color: Qt.alpha(c.surface, 0.55)
                border.width: 1; border.color: Qt.alpha(c.outline, 0.25)

                Row {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 12; width: 320
                    ClippingRectangle {
                        width: 64; height: 64; radius: 12; color: Qt.alpha(c.primary, 0.2)
                        Image { anchors.fill: parent; source: player.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(128, 128) }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; width: 240
                        Text { width: parent.width; elide: Text.ElideRight; text: player.title || "Nothing playing"
                               color: c.text; font { family: "Inter"; pixelSize: 14; weight: Font.DemiBold } }
                        Text { width: parent.width; elide: Text.ElideRight; text: player.artists
                               color: c.textDim; font { family: "Inter"; pixelSize: 12 } }
                        Text { visible: player.activeDevice !== "" && player.activeDeviceType !== "Computer"
                               text: "Playing on " + player.activeDevice + " · move here"; color: c.primary
                               font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                               MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.transferHere() } }
                    }
                }

                Column {
                    anchors.centerIn: parent; spacing: 4; width: 460
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
                        IconButton { colors: c; icon: "shuffle"; iconSize: 17; active: player.shuffle; onClicked: player.setShuffle(); anchors.verticalCenter: parent.verticalCenter }
                        IconButton { colors: c; icon: "prev"; onClicked: player.previous(); anchors.verticalCenter: parent.verticalCenter }
                        PlayButton { colors: c; playing: player.playing; size: 46; onClicked: player.toggle() }
                        IconButton { colors: c; icon: "next"; onClicked: player.next(); anchors.verticalCenter: parent.verticalCenter }
                        IconButton { colors: c; icon: player.repeat === "track" ? "repeatOne" : "repeat"; iconSize: 17; active: player.repeat !== "off"; onClicked: player.cycleRepeat(); anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: 10; anchors.horizontalCenter: parent.horizontalCenter
                        Text { text: root.fmt(player.localPos); color: c.textDim; font { family: "Inter"; pixelSize: 11 } width: 36; horizontalAlignment: Text.AlignRight }
                        Seekbar {
                            width: 360; anchors.verticalCenter: parent.verticalCenter; colors: c
                            value: player.duration > 0 ? player.localPos / player.duration : 0
                            onPicked: f => player.seek(player.duration * f)
                        }
                        Text { text: root.fmt(player.duration); color: c.textDim; font { family: "Inter"; pixelSize: 11 } width: 36 }
                    }
                }

                Row {
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    IconButton { colors: c; icon: "lyrics"; iconSize: 18; size: 34; active: root.nowPlaying
                                 onClicked: root.nowPlaying = true; anchors.verticalCenter: parent.verticalCenter }
                    IconButton { colors: c; icon: player.volume === 0 ? "volumeOff" : "volume"; iconSize: 18; size: 34
                                 onClicked: player.setVolume(player.volume === 0 ? 60 : 0); anchors.verticalCenter: parent.verticalCenter }
                    Seekbar {
                        width: 110; anchors.verticalCenter: parent.verticalCenter; colors: c; fill: c.text
                        value: player.volume / 100
                        onPicked: f => player.setVolume(100 * f)
                    }
                }
            }

            NowPlaying {
                anchors.fill: parent
                visible: root.nowPlaying
                colors: c; player: player; lyrics: lyrics; fullscreen: root.fullscreen
                onCloseRequested: root.nowPlaying = false
                onFullscreenToggled: root.fullscreen = !root.fullscreen
            }
        }
    }
}
