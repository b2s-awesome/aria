// Lyrics in Spicy Lyrics' shapes. Sources, in order:
//   1. Spicy Lyrics developer API (GET api.spicylyrics.org/v1/lyrics/{spotify id}, key in
//      ~/.config/aria/spicy.key) — Syllable (word-level), Line or Static, times in seconds
//   2. LRCLIB (free) — Line, or Syllable when it has enhanced LRC <mm:ss.xx> word tags
// items: [{ kind: "line", t, end, text, opposite, words: [word], bg: [word] }
//         { kind: "interlude", t, end }]          word = { t, end, syl: [{ t, end, text }] }   ms
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: l
    property var item: null                 // Spotify track object (player.item)
    property string type: "Static"          // Syllable | Line | Static
    property var items: []
    property string plain: ""
    property string status: "idle"          // idle | loading | synced | plain | none
    property string source: ""              // spicy | lrclib
    property string trackId: ""
    property var cache: ({})

    property FileView keyFile: FileView {
        path: Quickshell.env("HOME") + "/.config/aria/spicy.key"
        blockLoading: true
        printErrors: false
    }
    readonly property string key: keyFile.loaded ? keyFile.text().trim() : ""

    function indexAt(ms) {
        let i = -1;
        for (let k = 0; k < items.length && items[k].t <= ms; k++) i = k;
        return i;
    }

    onItemChanged: if (item && item.id && item.id !== trackId) load()

    Component.onCompleted: {                // self-checks
        const a = build("[00:05.00] hello world\n[00:08.00] \n[00:15.00] next");
        console.assert(a.type === "Line" && a.items.length === 4, "lyrics: line items " + a.items.length);
        console.assert(a.items[1].text === "hello world" && a.items[1].end === 8000, "lyrics: line end = next start");
        console.assert(a.items[2].kind === "interlude" && a.items[2].end === 14500, "lyrics: blank-line interlude");
        const b = build("[00:01.00] <00:01.00> one <00:01.50> two <00:02.20>\n[00:03.00] end");
        console.assert(b.type === "Syllable" && b.items[0].words[1].t === 1500 && b.items[0].words[1].end === 2200, "lyrics: enhanced LRC");
        const s = fromSpicy({ Type: "Syllable", Content: [
            { Type: "Vocal", OppositeAligned: true, Lead: { Syllables: [
                { Text: "hel", IsPartOfWord: true, StartTime: 5, EndTime: 5.2 }, { Text: "lo", IsPartOfWord: false, StartTime: 5.2, EndTime: 5.5 },
                { Text: "you", IsPartOfWord: false, StartTime: 5.5, EndTime: 6 } ] },
              Background: [{ Syllables: [{ Text: "ooh", IsPartOfWord: false, StartTime: 5.6, EndTime: 6.4 }] }] } ] });
        console.assert(s.items[0].kind === "interlude" && s.items[1].opposite === true, "spicy: intro + opposite");
        console.assert(s.items[1].words.length === 2 && s.items[1].words[0].syl.length === 2 && s.items[1].words[0].end === 5500, "spicy: syllables → words");
        console.assert(s.items[1].bg.length === 1 && s.items[1].end === 6400, "spicy: background vocals");
    }

    // ---- Spicy Lyrics JSON → items ----
    function words(syls) {                  // join IsPartOfWord syllables into words
        const out = [];
        let cur = null;
        syls.forEach(s => {
            const y = { t: s.StartTime * 1000, end: s.EndTime * 1000, text: s.Text };
            if (!cur) { cur = { t: y.t, end: y.end, syl: [] }; out.push(cur); }
            cur.syl.push(y); cur.end = y.end;
            if (!s.IsPartOfWord) cur = null;
        });
        return out;
    }
    function withInterludes(lines) {        // dots for the intro and for gaps ≥ 4 s
        const out = [];
        lines.forEach((ln, i) => {
            const prevEnd = i === 0 ? 0 : lines[i - 1].end;
            if (ln.t - prevEnd >= (i === 0 ? 3000 : 4000)) out.push({ kind: "interlude", t: prevEnd, end: ln.t - 500 });
            out.push(ln);
        });
        return out;
    }
    function fromSpicy(b) {
        if (b.Type === "Static") return { type: "Static", plain: (b.Lines || []).map(x => x.Text).join("\n") };
        const lines = (b.Content || []).filter(c => c.Type === "Vocal").map(c => {
            if (b.Type === "Line")
                return { kind: "line", t: c.StartTime * 1000, end: c.EndTime * 1000, text: c.Text, opposite: !!c.OppositeAligned, words: [], bg: [] };
            const w = words(c.Lead.Syllables);
            const bg = [].concat(...(c.Background || []).map(x => words(x.Syllables)));
            const end = Math.max(w.length ? w[w.length - 1].end : 0, bg.length ? bg[bg.length - 1].end : 0);
            return { kind: "line", t: w.length ? w[0].t : c.Lead.StartTime * 1000, end: end,
                     text: w.map(x => x.syl.map(y => y.text).join("")).join(" "), opposite: !!c.OppositeAligned, words: w, bg: bg };
        });
        return { type: b.Type, items: withInterludes(lines) };
    }

    // ---- LRCLIB (LRC) → items ----
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
            if (text === "" || text === "♪") {
                if (next - r.t > 2500) out.push({ kind: "interlude", t: r.t, end: next - 500 });
                return;
            }
            const line = { kind: "line", t: r.t, end: next, text: text, opposite: false, words: [], bg: [] };
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
                line.words = line.words.map((w, k, a) => {
                    const end = w.end !== null ? w.end : k + 1 < a.length ? a[k + 1].t : Math.min(next, w.t + 600);
                    return { t: w.t, end: end, syl: [{ t: w.t, end: end, text: w.text }] };
                });
                if (line.words.length) line.end = line.words[line.words.length - 1].end;
            }
            out.push(line);
        });
        return { type: syllable ? "Syllable" : "Line", items: out };
    }

    // ---- fetching ----
    function request(url, headers, cb) {
        const x = new XMLHttpRequest();
        x.open("GET", url);
        for (const h in headers) x.setRequestHeader(h, headers[h]);
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let d = null;
            try { d = JSON.parse(x.responseText); } catch (e) {}
            cb(x.status === 200 ? d : null, x.status);
        };
        x.send();
    }
    function set(r, src) {
        type = r.type; source = src;
        if (r.type === "Static") { plain = r.plain; items = []; status = plain ? "plain" : "none"; }
        else { items = r.items; status = items.length ? "synced" : "none"; }
        cache[trackId] = { type: type, items: items, plain: plain, status: status, source: source };
    }
    function lrclib(id) {
        const artist = item.artists && item.artists.length ? item.artists[0].name : "";
        const accept = d => {
            if (d && d.syncedLyrics) { set(build(d.syncedLyrics), "lrclib"); return true; }
            if (d && d.plainLyrics) { set({ type: "Static", plain: d.plainLyrics }, "lrclib"); return true; }
            return false;
        };
        const q = "artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(item.name)
                + "&album_name=" + encodeURIComponent(item.album ? item.album.name : "")
                + "&duration=" + Math.round(item.duration_ms / 1000);
        request("https://lrclib.net/api/get?" + q, {}, d => {
            if (id !== trackId || accept(d)) return;
            request("https://lrclib.net/api/search?q=" + encodeURIComponent(artist + " " + item.name), {}, r => {
                if (id !== trackId) return;
                const list = Array.isArray(r) ? r : [];
                if (!accept(list.find(x => x.syncedLyrics) ?? list[0])) set({ type: "Static", plain: "" }, "");
            });
        });
    }
    function load() {
        trackId = item.id;
        const c = cache[trackId];
        if (c) { type = c.type; items = c.items; plain = c.plain; status = c.status; source = c.source; return; }
        type = "Static"; items = []; plain = ""; source = ""; status = "loading";
        const id = trackId;
        if (key === "") return lrclib(id);
        request("https://api.spicylyrics.org/v1/lyrics/" + id, { "Authorization": "Bearer " + key }, d => {
            if (id !== trackId) return;
            const b = d && d.Body;
            if (b && (b.Content || b.Lines)) set(fromSpicy(b), "spicy");
            else lrclib(id);                  // not found / error / rate-limited → LRCLIB
        });
    }
}
