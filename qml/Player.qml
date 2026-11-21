// Playback state (polled from /me/player) and controls. Plays on the spotifyd device
// named `deviceName` (else this PC's official Spotify app), transferring playback to it when needed.
import QtQuick

QtObject {
    id: p

    required property var api
    property string deviceName: ""             // empty = this PC's Spotify app (first "Computer" device)
    property bool fast: true                   // poll every second while the window is open

    property var state: null                   // last /me/player response (null = nothing playing)
    property string deviceId: ""
    property real localPos: 0                  // ms, interpolated between polls
    property double anchorPos: 0               // position (ms) at wall-clock anchorAt; pos = anchor + elapsed
    property double anchorAt: 0

    readonly property var item: state ? state.item : null
    readonly property bool playing: state ? state.is_playing : false
    readonly property bool shuffle: state ? state.shuffle_state : false
    readonly property string repeat: state ? state.repeat_state : "off"
    readonly property int volume: state && state.device ? (state.device.volume_percent ?? 50) : 50
    readonly property real duration: item ? item.duration_ms : 0
    readonly property string title: item ? item.name : ""
    readonly property string artists: item && item.artists ? item.artists.map(a => a.name).join(", ") : ""
    readonly property string art: item && item.album && item.album.images.length ? item.album.images[0].url : ""
    readonly property string activeDevice: state && state.device ? state.device.name : ""
    readonly property string activeDeviceType: state && state.device ? state.device.type : ""

    property Timer poller: Timer {
        interval: p.fast ? 1000 : 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: p.refresh()
    }
    property Timer ticker: Timer {             // smooth progress between polls
        interval: 250; running: p.playing; repeat: true
        onTriggered: p.localPos = p.now()
    }

    // Smooth position for lyrics (call every frame). Polls only re-anchor when drift > 300 ms, so no jitter.
    function now() { return playing ? Math.min(duration, anchorPos + Date.now() - anchorAt) : anchorPos; }
    function anchor(ms) { anchorPos = ms; anchorAt = Date.now(); localPos = ms; }

    function refresh() {
        const sent = Date.now();
        api.get("/me/player", (d, s) => {
            const prevId = p.item ? p.item.id : "";
            p.state = (s === 200) ? d : null;
            if (!p.state) return;
            const pos = (p.state.progress_ms ?? 0) + (p.state.is_playing ? (Date.now() - sent) / 2 : 0);
            if (!p.state.is_playing || prevId !== (p.item ? p.item.id : "") || Math.abs(pos - p.now()) > 300) p.anchor(pos);
        });
    }

    function findDevice(cb) {
        api.get("/me/player/devices", d => {
            const list = d && d.devices || [];
            // the official app (hidden engine) names itself after the PC, so fall back to any "Computer" device
            const dev = list.find(x => x.name.toLowerCase() === p.deviceName.toLowerCase()) ?? list.find(x => x.type === "Computer");
            p.deviceId = dev ? dev.id : "";
            cb(p.deviceId);
        });
    }

    function withDevice(fn) {
        if (deviceId !== "") fn(deviceId); else findDevice(fn);
    }

    // play({ context_uri, offset: { uri } }) or play({ uris: [...] }); no body = resume
    function play(body) {
        withDevice(id => {
            const q = id ? "?device_id=" + id : "";
            api.put("/me/player/play" + q, body ?? null, (d, s) => {
                if (s === 404) { p.deviceId = ""; }   // device went away; look it up next time
                Qt.callLater(p.refresh);
            });
        });
    }
    function toggle()   { playing ? api.put("/me/player/pause", null, refresh) : play(); }
    function next()     { api.post("/me/player/next", null, refresh); }
    function previous() { api.post("/me/player/previous", null, refresh); }
    function seek(ms)   { anchor(ms); api.put("/me/player/seek?position_ms=" + Math.round(ms), null, refresh); }
    function setVolume(v) { api.put("/me/player/volume?volume_percent=" + Math.round(v), null, refresh); }
    function setShuffle() { api.put("/me/player/shuffle?state=" + !shuffle, null, refresh); }
    function cycleRepeat() {
        const nextMode = { off: "context", context: "track", track: "off" }[repeat] ?? "off";
        api.put("/me/player/repeat?state=" + nextMode, null, refresh);
    }
    function transferHere() {
        withDevice(id => { if (id) api.put("/me/player", { device_ids: [id], play: true }, refresh); });
    }
}
