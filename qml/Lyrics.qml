// Lyrics in Spicy Lyrics' shapes (github.com/Spikerko/spicy-lyrics):
//   type "Line"     — line-synced: each line fills as a whole (no guessed word timing, like Spicy)
//   type "Syllable" — word-synced: real per-word timing (LRCLIB enhanced LRC, <mm:ss.xx> tags)
//   type "Static"   — plain text, no timing
// items: [{ kind: "line", t, end, text, words: [{t, end, text}] }   (words only for Syllable)
//         { kind: "interlude", t, end }]                            times in ms
// Source: LRCLIB (free, no account). Spicy's own syllable source needs a developer API key
// (developers.spicylyrics.org); shortcut: LRCLIB only, add that source once there's a key.
import QtQuick

QtObject {
    id: l
    property var item: null                 // Spotify track object (player.item)
    property string type: "Static"
    property var items: []
    property string plain: ""
    property string status: "idle"          // idle | loading | synced | plain | none
    property string trackId: ""
    property var cache: ({})                // trackId -> { type, items, plain, status }

    // last item that has started at `ms` (-1 before the first)
    function indexAt(ms) {
        let i = -1;
        for (let k = 0; k < items.length && items[k].t <= ms; k++) i = k;
        return i;
    }

    onItemChanged: if (item && item.id !== trackId) load()

    Component.onCompleted: {                // self-check
        const a = build("[00:05.00] hello world\n[00:08.00] \n[00:15.00] next");
        console.assert(a.type === "Line" && a.items.length === 4, "lyrics: line items " + a.items.length);
        console.assert(a.items[0].kind === "interlude" && a.items[0].end === 4500, "lyrics: intro interlude");
        console.assert(a.items[1].text === "hello world" && a.items[1].end === 8000, "lyrics: line end = next start");
        console.assert(a.items[2].kind === "interlude" && a.items[2].end === 14500, "lyrics: blank-line interlude");
        const b = build("[00:01.00] <00:01.00> one <00:01.50> two <00:02.20>\n[00:03.00] end");
        console.assert(b.type === "Syllable" && b.items[0].words[1].t === 1500 && b.items[0].words[1].end === 2200, "lyrics: enhanced LRC");
    }

    function stamp(m) { return (parseInt(m[1]) * 60 + parseFloat(m[2])) * 1000; }

    function build(lrc) {
        const raw = [];
        lrc.split("\n").forEach(row => {
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;          // no matchAll in QML's JS engine
            const text = row.replace(/\[[^\]]*\]/g, "").trim();
            let m;
            while ((m = re.exec(row)) !== null) raw.push({ t: stamp(m), text: text });
        });
        raw.sort((a, b) => a.t - b.t);
        const syllable = /<\d+:\d+/.test(lrc);

        const out = [];
        if (raw.length && raw[0].t > 3500) out.push({ kind: "interlude", t: 0, end: raw[0].t - 500 });
        raw.forEach((r, i) => {
            const next = i + 1 < raw.length ? raw[i + 1].t : r.t + 5000;
            const text = r.text.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
            if (text === "" || text === "♪") {                  // instrumental gap → dots
                if (next - r.t > 2500) out.push({ kind: "interlude", t: r.t, end: next - 500 });
                return;
            }
            const line = { kind: "line", t: r.t, end: next, text: text, words: [] };
            if (syllable) {
                let at = r.t;
                r.text.split(/(<\d+:\d+(?:\.\d+)?>)/).forEach(part => {
                    const m = /<(\d+):(\d+(?:\.\d+)?)>/.exec(part);
                    if (m) {
                        at = stamp(m);
                        const last = line.words[line.words.length - 1];
                        if (last && last.end === null) last.end = at;
                        return;
                    }
                    part.split(/\s+/).filter(w => w).forEach(w => line.words.push({ t: at, end: null, text: w }));
                });
                line.words.forEach((w, k) => { if (w.end === null) w.end = k + 1 < line.words.length ? line.words[k + 1].t : Math.min(next, w.t + 600); });
                if (line.words.length) line.end = line.words[line.words.length - 1].end;
            }
            out.push(line);
        });
        return { type: syllable ? "Syllable" : "Line", items: out };
    }

    function accept(d) {
        if (d && d.syncedLyrics) {
            const b = build(d.syncedLyrics);
            type = b.type; items = b.items; status = "synced"; return true;
        }
        if (d && d.plainLyrics) { type = "Static"; plain = d.plainLyrics; status = "plain"; return true; }
        return false;
    }

    function fetch(url, cb) {
        const x = new XMLHttpRequest();
        x.open("GET", url);
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let d = null;
            try { d = JSON.parse(x.responseText); } catch (e) {}
            cb(x.status === 200 ? d : null);
        };
        x.send();
    }

    function remember() { cache[trackId] = { type: type, items: items, plain: plain, status: status }; }

    function load() {
        trackId = item.id;
        const c = cache[trackId];
        if (c) { type = c.type; items = c.items; plain = c.plain; status = c.status; return; }
        type = "Static"; items = []; plain = ""; status = "loading";
        const id = trackId;
        const artist = item.artists && item.artists.length ? item.artists[0].name : "";
        const q = "artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(item.name)
                + "&album_name=" + encodeURIComponent(item.album ? item.album.name : "")
                + "&duration=" + Math.round(item.duration_ms / 1000);
        fetch("https://lrclib.net/api/get?" + q, d => {
            if (id !== trackId) return;                               // track changed meanwhile
            if (accept(d)) return remember();
            fetch("https://lrclib.net/api/search?q=" + encodeURIComponent(artist + " " + item.name), r => {
                if (id !== trackId) return;
                const list = Array.isArray(r) ? r : [];
                if (!accept(list.find(x => x.syncedLyrics) ?? list[0])) status = "none";
                remember();
            });
        });
    }
}
