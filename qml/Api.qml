// Spotify Web API client. Gets access tokens from `aria-auth token` and retries once on 401.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: api

    property string token: ""
    property var queue: []          // calls waiting for a token
    property string lastError: ""

    readonly property string authBin: Quickshell.env("HOME") + "/.local/bin/aria-auth"

    property Process tokenProc: Process {
        command: [api.authBin, "token"]
        stdout: StdioCollector {
            onStreamFinished: {
                api.token = text.trim();
                const waiting = api.queue;
                api.queue = [];
                waiting.forEach(f => f());
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") api.lastError = text.trim()
        }
    }

    // Access tokens last an hour; aria-auth refreshes them itself, we just ask again.
    property Timer refresher: Timer {
        interval: 40 * 60 * 1000; running: true; repeat: true
        onTriggered: api.renewToken()
    }

    function renewToken() {
        if (!tokenProc.running) tokenProc.running = true;
    }

    // call("GET", "/me/player", null, (data, status) => …)
    function call(method, path, body, cb, retried) {
        if (token === "") {
            queue = queue.concat([() => call(method, path, body, cb, retried)]);
            renewToken();
            return;
        }
        const x = new XMLHttpRequest();
        x.open(method, path.startsWith("http") ? path : "https://api.spotify.com/v1" + path);
        x.setRequestHeader("Authorization", "Bearer " + token);
        const hasBody = body !== undefined && body !== null;
        if (hasBody) x.setRequestHeader("Content-Type", "application/json");
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status === 401 && !retried) {
                token = "";
                call(method, path, body, cb, true);
                return;
            }
            let data = null;
            try { data = x.responseText ? JSON.parse(x.responseText) : null; } catch (e) {}
            if (x.status >= 400) api.lastError = (data && data.error && data.error.message) || ("HTTP " + x.status);
            if (cb) cb(data, x.status);
        };
        x.send(hasBody ? JSON.stringify(body) : null);
    }

    function get(path, cb) { call("GET", path, null, cb); }
    function put(path, body, cb) { call("PUT", path, body, cb); }
    function post(path, body, cb) { call("POST", path, body, cb); }

    Component.onCompleted: renewToken()
}
