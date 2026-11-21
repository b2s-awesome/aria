// Now Playing + lyrics: a clone of Spicy Lyrics (github.com/Spikerko/spicy-lyrics, "Spring" mode)
// on the rice's glass: the window is see-through (Hyprland blurs the desktop) and uses Noctalia colours.
//   • Syllable lyrics: per-word springs + gradient (LyricWord / LyricLetter)
//   • Line lyrics: the whole line fills top→bottom over its duration, with a line glow
//   • lines: NotSung .51 / Active 1 (scale 1.05) / Sung .497 opacity; blur 1.25 px per line away (max 6.83)
//   • interludes: three spring-animated dots; current line sits 33% down
//   • scroll freely (unblurs), auto-follow resumes after 3 s; click a line to seek
//   • keys: Esc close/leave fullscreen · Space play/pause · F fullscreen · [ ] lyrics offset ∓50 ms
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "spring.js" as Sp

Item {
    id: np
    property var colors
    property var player
    property var lyrics
    property bool fullscreen: false
    signal closeRequested()
    signal fullscreenToggled()

    property real offset: 0                       // ms ([ and ])
    property real clock: 0                        // ms, smooth playback position (every frame)
    readonly property int cur: lyrics.indexAt(clock)
    property bool userScroll: false
    readonly property real fontPx: Math.max(26, Math.min(52, width * 0.024))
    readonly property font lyricFont: Qt.font({ family: "Inter Display", pixelSize: fontPx, weight: Font.ExtraBold })

    focus: visible
    Keys.onEscapePressed: fullscreen ? fullscreenToggled() : closeRequested()
    Keys.onSpacePressed: player.toggle()
    Keys.onPressed: e => {
        if (e.key === Qt.Key_F) fullscreenToggled();
        else if (e.key === Qt.Key_BracketLeft || e.key === Qt.Key_BracketRight) {
            offset += e.key === Qt.Key_BracketRight ? 50 : -50;
            toast.text = "Lyrics offset " + (offset > 0 ? "+" : "") + offset + " ms"; toast.show();
        }
    }

    FrameAnimation { running: np.visible; onTriggered: np.clock = np.player.now() + np.offset }

    // glass: the window's own tint (shell.qml) + the blurred desktop behind it — nothing drawn here

    // ---- left: cover, title, controls ----
    Column {
        id: left
        anchors { left: parent.left; leftMargin: np.width * 0.07; verticalCenter: parent.verticalCenter }
        width: Math.min(np.width * 0.32, np.height * 0.52)
        spacing: 22

        ClippingRectangle {
            width: parent.width; height: width; radius: 22; color: Qt.alpha(np.colors.primary, 0.15)
            Image { anchors.fill: parent; source: np.player.art; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        Column {
            width: parent.width; spacing: 4
            Text { width: parent.width; elide: Text.ElideRight; text: np.player.title || "Nothing playing"
                   color: np.colors.text; font { family: "Inter Display"; pixelSize: 28; weight: Font.Bold } }
            Text { width: parent.width; elide: Text.ElideRight; text: np.player.artists
                   color: np.colors.textDim; font { family: "Inter"; pixelSize: 18 } }
        }
        Seekbar {
            width: parent.width; colors: np.colors
            value: np.player.duration > 0 ? np.player.localPos / np.player.duration : 0
            onPicked: f => np.player.seek(np.player.duration * f)
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 22
            IconButton { colors: np.colors; icon: "shuffle"; iconSize: 19; active: np.player.shuffle; onClicked: np.player.setShuffle(); anchors.verticalCenter: parent.verticalCenter }
            IconButton { colors: np.colors; icon: "prev"; size: 46; iconSize: 24; onClicked: np.player.previous(); anchors.verticalCenter: parent.verticalCenter }
            PlayButton { colors: np.colors; size: 64; playing: np.player.playing; onClicked: np.player.toggle() }
            IconButton { colors: np.colors; icon: "next"; size: 46; iconSize: 24; onClicked: np.player.next(); anchors.verticalCenter: parent.verticalCenter }
            IconButton { colors: np.colors; icon: np.player.repeat === "track" ? "repeatOne" : "repeat"; iconSize: 19; active: np.player.repeat !== "off"; onClicked: np.player.cycleRepeat(); anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- right: lyrics ----
    ListView {
        id: lines
        anchors { left: left.right; leftMargin: np.width * 0.06; right: parent.right; rightMargin: np.width * 0.05; top: parent.top; bottom: parent.bottom }
        visible: np.lyrics.status === "synced"
        model: np.lyrics.items
        spacing: np.fontPx * 0.5
        clip: true
        currentIndex: Math.max(0, np.cur)
        highlightRangeMode: np.userScroll ? ListView.NoHighlightRange : ListView.ApplyRange
        preferredHighlightBegin: height * 0.33
        preferredHighlightEnd: height * 0.33
        highlightMoveDuration: 500
        highlightMoveVelocity: -1
        header: Item { height: lines.height * 0.33 }
        footer: Item { height: lines.height * 0.6 }

        onMovementStarted: { np.userScroll = true; resume.stop(); }
        onMovementEnded: resume.restart()
        Timer { id: resume; interval: 3000; onTriggered: np.userScroll = false }

        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool now: index === np.cur
            readonly property bool interlude: modelData.kind === "interlude"
            readonly property int dist: Math.abs(index - np.cur)
            readonly property int phase: index < np.cur ? 2 : now ? 1 : 0          // Sung / Active / NotSung
            readonly property real p: Math.max(0, Math.min(1, (np.clock - modelData.t) / Math.max(1, modelData.end - modelData.t)))
            width: ListView.view.width
            height: interlude ? (now ? np.fontPx * 1.8 : 0) : body.implicitHeight
            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

            // ---- sung line ----
            Item {
                id: body
                visible: !row.interlude
                width: parent.width
                implicitHeight: np.lyrics.type === "Syllable" ? flow.implicitHeight : lineFill.implicitHeight
                transformOrigin: Item.Left
                scale: row.now ? 1.05 : 1
                opacity: row.phase === 1 ? 1 : row.phase === 2 ? 0.497 : 0.51
                Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 300 } }

                // blur by distance: min(1.25 · d, 6.83125) px; none while scrolling by hand
                layer.enabled: !row.now && !np.userScroll
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 8; blur: Math.min(1.25 * row.dist, 6.83125) / 8 }

                // Syllable: words
                Flow {
                    id: flow
                    visible: np.lyrics.type === "Syllable"
                    width: parent.width / 1.05                    // room for the active 1.05 scale
                    spacing: np.fontPx * 0.26
                    Repeater {
                        model: row.interlude || np.lyrics.type !== "Syllable" ? [] : row.modelData.words
                        LyricWord {
                            required property var modelData
                            text: modelData.text; t: modelData.t; end: modelData.end
                            clock: np.clock; lineActive: row.now
                            font: np.lyricFont; color: np.colors.text
                        }
                    }
                }

                // Line: whole line fills top → bottom, plus a line glow spring
                Item {
                    id: lineFill
                    visible: np.lyrics.type !== "Syllable"
                    width: parent.width / 1.05
                    implicitHeight: lineText.implicitHeight
                    Text { id: lineText; width: parent.width; wrapMode: Text.WordWrap; text: row.modelData.text ?? ""
                           font: np.lyricFont; color: np.colors.text; visible: !row.now }
                    GradientFill {
                        visible: row.now
                        width: parent.width; height: lineText.implicitHeight
                        wrapMode: Text.WordWrap; vertical: true
                        text: row.modelData.text ?? ""; font: np.lyricFont; color: np.colors.text
                        pos: Sp.gradientPos(row.phase, row.p)
                    }
                    property var sGlow: Sp.make(0, Sp.S.lineGlow[0], Sp.S.lineGlow[1])
                    property real glowV: 0
                    FrameAnimation {
                        running: lineFill.visible && (row.now || !Sp.resting(lineFill.sGlow))
                        onTriggered: {
                            lineFill.sGlow.goal = row.now ? Sp.at(Sp.LineGlowRange, row.p) : 0;
                            lineFill.glowV = Sp.step(lineFill.sGlow, Math.min(0.05, frameTime));
                        }
                    }
                    layer.enabled: glowV > 0.01
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: np.colors.text
                        blurMax: 32; shadowBlur: (4 + 2 * lineFill.glowV) / 32
                        shadowOpacity: Math.min(1, lineFill.glowV * 0.35)
                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                    }
                }
            }

            // ---- interlude: three dots, each with Spicy's dot springs; group pops away 500 ms before the end ----
            Row {
                id: dots
                visible: row.interlude
                anchors.verticalCenter: parent.verticalCenter
                spacing: np.fontPx * 0.32
                readonly property bool closing: !row.now || np.clock > row.modelData.end - 500
                transformOrigin: Item.Left
                scale: closing ? 0 : 1
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
                Repeater {
                    model: row.interlude ? 3 : 0
                    Rectangle {
                        id: dot
                        required property int index
                        readonly property real dp: Math.max(0, Math.min(1, row.p * 3 - index))
                        property var sS: Sp.make(0.75, Sp.S.dotScale[0], Sp.S.dotScale[1])
                        property var sY: Sp.make(0, Sp.S.dotY[0], Sp.S.dotY[1])
                        property var sG: Sp.make(0, Sp.S.dotGlow[0], Sp.S.dotGlow[1])
                        property var sO: Sp.make(0.35, Sp.S.dotOpacity[0], Sp.S.dotOpacity[1])
                        property real g: 0
                        width: np.fontPx * 0.42; height: width; radius: width / 2
                        color: np.colors.text
                        FrameAnimation {
                            running: row.now
                            onTriggered: {
                                const dt = Math.min(0.05, frameTime);
                                dot.sS.goal = Sp.at(Sp.DotScale, dot.dp); dot.sY.goal = Sp.at(Sp.DotYOffset, dot.dp);
                                dot.sG.goal = Sp.at(Sp.DotGlow, dot.dp);  dot.sO.goal = Sp.at(Sp.DotOpacity, dot.dp);
                                dot.scale = Sp.step(dot.sS, dt);
                                dot.transform[0].y = np.fontPx * Sp.step(dot.sY, dt);
                                dot.g = Sp.step(dot.sG, dt);
                                dot.opacity = Sp.step(dot.sO, dt);
                            }
                        }
                        transform: [ Translate { y: 0 } ]
                        layer.enabled: g > 0.01
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: np.colors.text
                            blurMax: 32; shadowBlur: (4 + 8 * dot.g) / 32; shadowOpacity: Math.min(1, dot.g * 0.6)
                            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent; enabled: !row.interlude; cursorShape: Qt.PointingHandCursor
                onClicked: { np.userScroll = false; np.player.seek(row.modelData.t - np.offset); }
            }
        }
    }

    // Static lyrics or status
    Flickable {
        anchors.fill: lines
        visible: np.lyrics.status !== "synced"
        contentHeight: plainText.implicitHeight + 200; clip: true
        Text {
            id: plainText
            y: np.lyrics.status === "plain" ? 80 : (np.height - implicitHeight) / 2
            width: parent.width; wrapMode: Text.WordWrap
            text: np.lyrics.status === "plain" ? np.lyrics.plain
                : np.lyrics.status === "loading" ? "Finding lyrics…"
                : np.player.title ? "No lyrics for this track" : ""
            color: np.lyrics.status === "plain" ? np.colors.text : np.colors.textDim
            font { family: "Inter Display"; pixelSize: np.lyrics.status === "plain" ? 26 : 30; weight: Font.Bold }
            lineHeight: 1.25
        }
    }

    // offset toast
    Rectangle {
        id: toast
        property alias text: toastText.text
        function show() { opacity = 1; toastTimer.restart(); }
        anchors { bottom: parent.bottom; horizontalCenter: lines.horizontalCenter; bottomMargin: 40 }
        width: toastText.implicitWidth + 32; height: 40; radius: 20
        color: Qt.alpha(np.colors.surface, 0.8); opacity: 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Text { id: toastText; anchors.centerIn: parent; color: np.colors.text; font { family: "Inter"; pixelSize: 14; weight: Font.Medium } }
        Timer { id: toastTimer; interval: 1400; onTriggered: toast.opacity = 0 }
    }

    Row {
        anchors { top: parent.top; right: parent.right; margins: 24 }
        spacing: 6
        IconButton { colors: np.colors; icon: "fullscreen"; size: 44; iconSize: 20; active: np.fullscreen; onClicked: np.fullscreenToggled() }
        IconButton { colors: np.colors; icon: "close"; size: 44; iconSize: 22; onClicked: np.closeRequested() }
    }
}
