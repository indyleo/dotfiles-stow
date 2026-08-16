import QtQuick
import Quickshell.Services.Pipewire

// Drop-in replacement for the wpctl-based volume/mic OSD path.
//
// Reading is a property binding (Pipewire pushes changes over its socket
// connection the instant anything - this shell, pavucontrol, a hardware
// key handled elsewhere - changes the default sink/source), and writing
// is a property assignment, not a subprocess. There's no "raw read"
// process to spawn after a change and nothing to poll: volume/mute state
// is live for as long as the node is tracked.
//
// Usage in shell.qml:
//   AudioController { id: audio }
//   ... audio.volumePct / audio.muted / audio.volUp() ...
Item {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property PwNode source: Pipewire.defaultAudioSource

	// Binding sink/source here is required: PwNode.audio's properties are
	// invalid (unreadable/unwritable) until the node is tracked this way.
	PwObjectTracker { objects: [root.sink, root.source] }

	readonly property bool sinkReady: !!(sink && sink.ready && sink.audio)
	readonly property bool sourceReady: !!(source && source.ready && source.audio)

	readonly property real volume: sinkReady ? sink.audio.volume : 0
	readonly property bool muted: sinkReady ? sink.audio.muted : true
	readonly property int volumePct: Math.round(volume * 100)

	readonly property real micVolume: sourceReady ? source.audio.volume : 0
	readonly property bool micMuted: sourceReady ? source.audio.muted : true
	readonly property int micVolumePct: Math.round(micVolume * 100)

	// Matches the old wpctl invocations: 5% steps, raise capped at 100%
	// (the old "-l 1.0" flag), lower/toggle uncapped/untouched otherwise.
	readonly property real step: 0.05

	// Each function returns the resulting percent (or -1 if no sink/source
	// is available yet) so the caller can pop the OSD immediately, with no
	// read-back round trip needed.
	function volUp(): int {
		if (!sinkReady) return -1
		sink.audio.muted = false
		sink.audio.volume = Math.min(1.0, sink.audio.volume + step)
		return Math.round(sink.audio.volume * 100)
	}
	function volDown(): int {
		if (!sinkReady) return -1
		sink.audio.volume = Math.max(0.0, sink.audio.volume - step)
		return Math.round(sink.audio.volume * 100)
	}
	function volToggle(): int {
		if (!sinkReady) return -1
		sink.audio.muted = !sink.audio.muted
		return Math.round(sink.audio.volume * 100)
	}

	function micUp(): int {
		if (!sourceReady) return -1
		source.audio.muted = false
		source.audio.volume = Math.min(1.0, source.audio.volume + step)
		return Math.round(source.audio.volume * 100)
	}
	function micDown(): int {
		if (!sourceReady) return -1
		source.audio.volume = Math.max(0.0, source.audio.volume - step)
		return Math.round(source.audio.volume * 100)
	}
	function micToggle(): int {
		if (!sourceReady) return -1
		source.audio.muted = !source.audio.muted
		return Math.round(source.audio.volume * 100)
	}

	// --- Bar pill icon/text -----------------------------------------------
	// Codepoints verified byte-for-byte against sysstats' vvolume() /
	// mmicrophone() (thanks for sharing that file) -- these are not
	// guesses. Reimplementing the tiers here means `sysstats volume` /
	// `sysstats microphone` don't need to be spawned at all anymore, for
	// the OSD or the bar pill: icon/text are plain reactive properties
	// derived from the same volume/mute state above, so they update in
	// the same instant, with the same zero-subprocess cost.
	readonly property string volIcon: (muted || volumePct === 0) ? "󰝟"
		: volumePct === 100 ? "󰶬"
		: volumePct >= 75   ? "󰕾"
		: volumePct >= 25   ? "󰖀"
		: "󰕿"
	readonly property string volText: (muted || volumePct === 0) ? "Muted" : volumePct + "%"

	readonly property string micIcon: (!micMuted && micVolumePct > 0) ? "" : ""
	readonly property string micText: (!micMuted && micVolumePct > 0) ? micVolumePct + "%" : "Muted"

	signal volChanged()
	signal micChanged()
	onVolumeChanged: volChanged()
	onMutedChanged: volChanged()
	onMicVolumeChanged: micChanged()
	onMicMutedChanged: micChanged()
}
