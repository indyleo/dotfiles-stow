import QtQuick
import Quickshell.Services.Pipewire

// Native Pipewire audio control. Reads/writes default sink/source directly.
Item {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property PwNode source: Pipewire.defaultAudioSource

	PwObjectTracker { objects: [root.sink, root.source] }

	readonly property bool sinkReady: !!(sink && sink.ready && sink.audio)
	readonly property bool sourceReady: !!(source && source.ready && source.audio)

	readonly property real volume: sinkReady ? sink.audio.volume : 0
	readonly property bool muted: sinkReady ? sink.audio.muted : true
	readonly property int volumePct: Math.round(volume * 100)

	readonly property real micVolume: sourceReady ? source.audio.volume : 0
	readonly property bool micMuted: sourceReady ? source.audio.muted : true
	readonly property int micVolumePct: Math.round(micVolume * 100)

	readonly property real step: root.stepSize
	property real stepSize: 0.05   // configurable: e.g. set to 0.02 for finer 2% steps

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