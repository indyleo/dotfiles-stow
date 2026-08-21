import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

// MPRIS media controller. Reacts to DBus signals, no polling.
Item {
	id: root

	readonly property var browserIdentities: ["firefox", "chromium", "chrome", "brave", "vivaldi", "zen", "edge"]
	readonly property var songIdentities: ["spotify", "subsonic", "feishin", "supersonic", "mpd", "mopidy", "elisa", "rhythmbox", "vlc"]

	function classify(p) {
		if (!p) return "none"
		const id = ((p.desktopEntry || "") + " " + (p.identity || "") + " " + (p.dbusName || "")).toLowerCase()
		for (let i = 0; i < browserIdentities.length; i++) if (id.includes(browserIdentities[i])) return "browser"
		for (let i = 0; i < songIdentities.length; i++) if (id.includes(songIdentities[i])) return "song"
		return "none"
	}

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
	readonly property string icon: isPlaying ? "\uf04c" : "\uf04b"

	readonly property string title: activePlayer ? (activePlayer.trackTitle || "Unknown Title") : ""
	readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

	function looksLikeArtPath(val) {
		if (!val) return false
		return val.startsWith("file://") || /\.(png|jpe?g|gif|bmp|webp)$/i.test(val)
	}

	readonly property string rawAlbum: activePlayer ? (activePlayer.trackAlbum || "") : ""

	readonly property string album: {
		if (looksLikeArtPath(rawAlbum)) return ""
		const a = rawAlbum.trim()
		if (a === "" || a.toLowerCase().includes("unknown album")) return ""
		return rawAlbum
	}

	readonly property string rawArtUrl: {
		if (!activePlayer) return ""
		if (activePlayer.trackArtUrl) return activePlayer.trackArtUrl
		return looksLikeArtPath(rawAlbum) ? rawAlbum : ""
	}
	readonly property string artUrl: rawArtUrl === "" ? "" : (rawArtUrl.includes("://") ? rawArtUrl : "file://" + rawArtUrl)

	property string stableArtUrl: ""
	readonly property string displayArtUrl: artUrl.startsWith("file://") ? stableArtUrl : artUrl

	property var tempArtFiles: []
	property int _artRequestId: 0

	Process {
		id: artSnapshotProc
		property string pendingDest: ""
		property string pendingSrc: ""
		property int requestId: 0
		onExited: (exitCode, exitStatus) => {
			if (requestId !== root._artRequestId) return // superseded by a newer track change
			if (exitCode === 0 && pendingDest !== "") {
				root.stableArtUrl = "file://" + pendingDest
			} else {
				// Previously a failed copy just left stableArtUrl at
				// whatever it was before (stale art from a prior track, or
				// blank), with no warning at all.
				console.warn("[MediaController] Failed to copy artwork (exit " + exitCode + ") from", pendingSrc)
				root.stableArtUrl = ""
			}
		}
	}
	onArtUrlChanged: {
		if (artUrl.startsWith("file://")) {
			// Invalidate any pending copy
			++root._artRequestId
			const src = artUrl.substring("file://".length)
			const dot = src.lastIndexOf(".")
			const ext = dot >= 0 ? src.substring(dot) : ".img"
			const dest = "/tmp/qs-mediaosd-art-" + (activePlayer ? activePlayer.uniqueId : 0) + ext

			// The same player reuses the same destination filename across
			// track changes, so pushing unconditionally on every change let
			// duplicate entries for the same still-active file pile up in
			// tempArtFiles. That meant the eviction below (which removes
			// whatever's oldest in the list) could end up deleting the
			// active player's *current* artwork file just because an older
			// duplicate entry for that same path happened to be oldest.
			// De-duplicate by moving this path to the end instead.
			const idx = tempArtFiles.indexOf(dest)
			if (idx !== -1) tempArtFiles.splice(idx, 1)
			tempArtFiles.push(dest)

			// Cleanup old files (keep max 10), but never delete the path
			// we're about to write to.
			while (tempArtFiles.length > 10) {
				const oldest = tempArtFiles.shift()
				if (oldest === dest) continue
				cleanupProc.command = ["rm", "-f", oldest]
				cleanupProc.running = false
				cleanupProc.running = true
			}

			artSnapshotProc.pendingDest = dest
			artSnapshotProc.pendingSrc = src
			artSnapshotProc.requestId = root._artRequestId
			artSnapshotProc.command = ["cp", "-f", src, dest]
			artSnapshotProc.running = false
			artSnapshotProc.running = true
		} else {
			stableArtUrl = artUrl
		}
	}

	Process {
		id: cleanupProc
	}

	property int positionUpdateCounter: 0
	readonly property real positionSec: {
		positionUpdateCounter // dummy dependency to force reevaluation
		return activePlayer ? activePlayer.position : 0
	}
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

	property bool ticking: false
	Timer {
		interval: 1000
		repeat: true
		running: root.ticking && root.isPlaying
		onTriggered: {
			if (root.activePlayer && root.isPlaying)
				root.positionUpdateCounter++
		}
	}

	function playPause() { if (activePlayer && activePlayer.canTogglePlaying) activePlayer.togglePlaying() }
	function next()      { if (activePlayer && activePlayer.canGoNext) activePlayer.next() }
	function previous()  { if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous() }
	function seekForward() {
		if (activePlayer && activePlayer.canSeek) activePlayer.seek(5)
	}
	function seekBackward() {
		if (activePlayer && activePlayer.canSeek) activePlayer.seek(-5)
	}

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