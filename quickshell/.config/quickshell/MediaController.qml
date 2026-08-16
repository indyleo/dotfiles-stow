import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

// Drop-in replacement for the mediactl/medianotify/playerctl pipeline.
//
// Everything here is DBus-signal-driven via Quickshell's built-in MPRIS
// service: no polling, no subprocess spawning, no bash. Track/playback
// changes reach this component the instant the player emits them, and
// `activePlayer` (and everything derived from it) is a plain QML property
// binding, so it re-evaluates automatically whenever any property it read
// (player list, playbackState, identity, ...) changes.
//
// Usage in shell.qml:
//   MediaController { id: media }
//   ... media.title / media.artist / media.isPlaying / media.playPause() ...
Item {
	id: root

	// Same two buckets mediactl used, same priority order:
	// browser playing > song playing > browser paused > song paused > none.
	readonly property var browserIdentities: ["firefox", "chromium", "chrome", "brave", "vivaldi", "zen", "edge"]
	readonly property var songIdentities: ["spotify", "subsonic", "feishin", "supersonic", "mpd", "mopidy", "elisa", "rhythmbox", "vlc"]

	function classify(p) {
		if (!p) return "none"
		const id = ((p.desktopEntry || "") + " " + (p.identity || "") + " " + (p.dbusName || "")).toLowerCase()
		for (let i = 0; i < browserIdentities.length; i++) if (id.includes(browserIdentities[i])) return "browser"
		for (let i = 0; i < songIdentities.length; i++) if (id.includes(songIdentities[i])) return "song"
		return "none"
	}

	// This is a genuine property binding (not a function called once), so
	// QML's dependency tracker re-runs it whenever anything it reads
	// changes: the player list itself, or any .identity/.playbackState it
	// touched on this pass. That's what makes the whole chain reactive
	// with zero timers.
	readonly property var activePlayer: {
		const list = Mpris.players.values
		let browserPlaying = null, songPlaying = null, browserPaused = null, songPaused = null
		for (let i = 0; i < list.length; i++) {
			const p = list[i]
			const type = classify(p)
			if (type === "none") continue
			if (p.playbackState === MprisPlaybackState.Playing) {
				if (type === "browser" && !browserPlaying) browserPlaying = p
				else if (type === "song" && !songPlaying) songPlaying = p
			} else if (p.playbackState === MprisPlaybackState.Paused) {
				if (type === "browser" && !browserPaused) browserPaused = p
				else if (type === "song" && !songPaused) songPaused = p
			}
		}
		return browserPlaying || songPlaying || browserPaused || songPaused || null
	}

	readonly property string activeType: classify(activePlayer)
	readonly property bool showMedia: activePlayer !== null
	readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
	readonly property string icon: isPlaying ? "\uf04c" : "\uf04b" // nf-fa-pause / nf-fa-play

	readonly property string title: activePlayer ? (activePlayer.trackTitle || "Unknown Title") : ""
	readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""
	readonly property string album: looksLikeArtPath(rawAlbum) ? "" : rawAlbum
	readonly property string rawAlbum: activePlayer ? (activePlayer.trackAlbum || "") : ""

	// Some MPRIS bridges (firefox-mpris in particular) leak the real art
	// path into the album field instead of populating trackArtUrl.
	// Recover it there if trackArtUrl came back empty.
	function looksLikeArtPath(val) {
		if (!val) return false
		return val.startsWith("file://") || /\.(png|jpe?g|gif|bmp|webp)$/i.test(val)
	}

	readonly property string rawArtUrl: {
		if (!activePlayer) return ""
		if (activePlayer.trackArtUrl) return activePlayer.trackArtUrl
		return looksLikeArtPath(rawAlbum) ? rawAlbum : ""
	}
	readonly property string artUrl: rawArtUrl === "" ? "" : (rawArtUrl.includes("://") ? rawArtUrl : "file://" + rawArtUrl)

	// Chromium/electron players write their thumbnail to a temp path that
	// can get rotated or deleted moments after trackArtUrl reports it.
	// Snapshot local (file://) art into a stable, per-track-keyed path so
	// the Image element in the bar/OSD isn't racing the source player.
	// Remote (http/https) URLs don't need this -- Qt's own network image
	// loader handles those directly.
	property string stableArtUrl: ""
	readonly property string displayArtUrl: artUrl.startsWith("file://") ? stableArtUrl : artUrl

	Process {
		id: artSnapshotProc
		property string pendingDest: ""
		onExited: (exitCode, exitStatus) => {
			if (exitCode === 0 && pendingDest !== "")
				root.stableArtUrl = "file://" + pendingDest
		}
	}
	onArtUrlChanged: {
		if (artUrl.startsWith("file://")) {
			const src = artUrl.substring("file://".length)
			const dot = src.lastIndexOf(".")
			const ext = dot >= 0 ? src.substring(dot) : ".img"
			const dest = "/tmp/qs-mediaosd-art-" + (activePlayer ? activePlayer.uniqueId : 0) + ext
			artSnapshotProc.pendingDest = dest
			artSnapshotProc.command = ["cp", "-f", src, dest]
			artSnapshotProc.running = false
			artSnapshotProc.running = true
		} else {
			stableArtUrl = artUrl
		}
	}

	// --- Progress -------------------------------------------------------
	readonly property real positionSec: activePlayer ? activePlayer.position : 0
	readonly property real lengthSec: activePlayer ? activePlayer.length : 0
	readonly property bool hasLength: activePlayer ? activePlayer.lengthSupported : false
	readonly property int progressPct: (activePlayer && hasLength && lengthSec > 0)
		? Math.max(0, Math.min(100, Math.round(positionSec / lengthSec * 100))) : -1
	readonly property string progressTime: (activePlayer && hasLength)
		? formatDuration(positionSec) + " / " + formatDuration(lengthSec) : ""

	function formatDuration(sec) {
		if (!isFinite(sec) || sec < 0) sec = 0
		const total = Math.floor(sec)
		const m = Math.floor(total / 60)
		const s = total % 60
		return m + ":" + (s < 10 ? "0" + s : s)
	}

	// MPRIS position rarely pushes updates on its own (see MprisPlayer
	// docs). Tick it manually, but only while a consumer actually cares
	// (bind `ticking` to e.g. mosdVisible) and only while playing.
	property bool ticking: false
	Timer {
		interval: 1000
		repeat: true
		running: root.ticking && root.isPlaying
		onTriggered: if (root.activePlayer) root.activePlayer.positionChanged()
	}

	// --- Controls ---------------------------------------------------------
	function playPause() { if (activePlayer && activePlayer.canTogglePlaying) activePlayer.togglePlaying() }
	function next()      { if (activePlayer && activePlayer.canGoNext) activePlayer.next() }
	function previous()  { if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous() }

	// --- "Now playing" popup trigger --------------------------------------
	// Fires on track change, resume/pause, or switching active players --
	// same triggers medianotify used to push over IPC, but derived
	// directly from the reactive properties above instead of a bash
	// daemon watching `playerctl -a -F`.
	signal nowPlaying()
	property string _lastKey: ""
	function _currentKey() {
		return activePlayer ? (activeType + "|" + title + "|" + artist + "|" + isPlaying) : ""
	}
	function _checkKey() {
		const key = _currentKey()
		if (key !== "" && key !== _lastKey) nowPlaying()
		_lastKey = key
	}
	onActivePlayerChanged: _checkKey()
	onTitleChanged: _checkKey()
	onArtistChanged: _checkKey()
	onIsPlayingChanged: _checkKey()
}
