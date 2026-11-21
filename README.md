# Aria

A frosted-glass Spotify client for Linux, written in [Quickshell](https://quickshell.org) (QML) for Hyprland.
Aria takes its colours from your [Noctalia](https://github.com/noctalia-dev/noctalia-shell) theme, and its lyrics view clones
[Spicy Lyrics](https://github.com/Spikerko/spicy-lyrics).

- **Library:** Home (recently played), Search (tracks, albums, playlists), Liked Songs, Albums and your playlists.
- **Now-playing bar:** shuffle, previous/next, play/pause, repeat, seek and volume, using Noctalia's Tabler icons.
- **Lyrics view (in the window or fullscreen):**
  - Word-synced lyrics are animated with Spicy Lyrics' spring physics: each word swells, lifts and glows, and long notes animate letter by letter.
  - Line-synced lyrics fill line by line.
  - Instrumental breaks show animated dots.
  - Lines blur and dim with distance from the current one.
  - You can scroll freely and click a line to jump to it.
- **Glass:** the window is transparent, and Hyprland blurs the desktop behind it.

## How it plays music

Aria is a remote control. The **official Spotify app** runs hidden in the background and plays the audio, and Aria drives it
through the Spotify Web API. Librespot-based players such as spotifyd are refused audio keys on many accounts
([librespot#1649](https://github.com/librespot-org/librespot/issues/1649)), so Aria doesn't use them.
Spotify Premium is required.

## Lyrics

- Aria fetches lyrics from [LRCLIB](https://lrclib.net), which is free and needs no account.
- Line-synced lyrics fill as whole lines. That's what Spicy Lyrics does when it has no word timing.
- Enhanced LRC (with `<mm:ss.xx>` word tags) switches on the word-by-word mode.
- With a [Spicy Lyrics developer API](https://developers.spicylyrics.org) key in `~/.config/aria/spicy.key`, Aria uses Spicy's syllable-synced lyrics first, then falls back to LRCLIB.

Keys in the lyrics view:
- `Esc`: leave fullscreen, or close the view
- `Space`: play or pause
- `F`: toggle fullscreen
- `[` and `]`: shift the lyrics by 50 ms

## Setup

Requirements: Quickshell 0.3+, Qt 6.8+ (for `FrameAnimation` and `MultiEffect`), Python 3, `spotify-launcher`, and Hyprland.

1. Create an app at the [Spotify developer dashboard](https://developer.spotify.com/dashboard) with the redirect URI
   `http://127.0.0.1:8898/callback`. Then `cp config.example.json config.json` and fill in your client ID.
2. Link the config and log in:
   ```sh
   ln -s "$PWD/qml" ~/.config/quickshell/aria
   ln -s "$PWD/bin/aria-auth" ~/.local/bin/aria-auth
   aria-auth login          # PKCE in your browser; the token is kept in ~/.local/state/aria
   ```
3. Colours: Aria reads `qml/Colors.qml`, which defines `surface`, `text`, `textDim`, `primary`, `outline` and `accentText`.
   With Noctalia, render `noctalia-colors-template.qml` to `~/.config/quickshell/aria/Colors.qml` as a user template.
   Otherwise, write that file by hand.
4. Hyprland example (Lua config):
   ```lua
   local ARIA = { class = "^org\\.quickshell$", title = "^Aria$" }
   hl.window_rule({ name = "aria", match = ARIA, workspace = "special:music", float = true, size = "1180 760", center = true })
   hl.window_rule({ name = "spotify-engine", match = { class = "^[Ss]potify$" }, workspace = "special:spotify silent" })
   hl.bind("SUPER + N", hl.dsp.exec_cmd("qs -c aria ipc call aria toggle"))
   hl.on("hyprland.start", function() hl.exec_cmd("qs -c aria"); hl.exec_cmd("spotify-launcher") end)
   ```
   IPC commands:
   - `qs -c aria ipc call aria toggle`: show or hide Aria
   - `qs -c aria ipc call aria lyrics`: open or close the fullscreen lyrics view

## Credits and licence

The lyrics animation is derived from **Spicy Lyrics** by Spikerko, which is AGPL-3.0. Aria reuses its spring model, animation curves,
gradient, glow, blur and opacity values. Lyrics come from LRCLIB.
Aria is licensed under the **GNU AGPL-3.0**; see `LICENSE`.
