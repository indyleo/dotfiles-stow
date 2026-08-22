import QtQuick

// A minimal click/drag volume slider. Kept as its own component since it's
// used both by AudioSwitcher (per-device volume) and AudioMixer (per-app
// volume) - built with plain Rectangle+MouseArea rather than
// QtQuick.Controls to match every other picker in this shell.
Item {
	id: root

	property real value: 0.0        // current value, 0.0 - maxValue
	property real maxValue: 1.0     // pipewire allows >1.0 ("overdrive"); callers can raise this
	property bool muted: false

	// Defaults sourced from Theme.qml; still overridable per-instance
	property color trackColor: Theme.buttonBg
	property color fillColor: Theme.accent
	property color mutedFillColor: Theme.border

	// Emitted continuously while dragging/clicking, not just on release,
	// so the caller can bind it straight to a live property (e.g.
	// node.audio.volume) for immediate feedback.
	signal moved(real newValue)

	implicitHeight: 16
	clip: true   // guarantees the fill bar/handle can never paint past this component's own bounds

	// Single source of truth for the fill ratio, guarded against NaN/Infinity
	// (e.g. a transient undefined volume value while a node's .audio hasn't
	// populated yet) which could otherwise produce a nonsensical width.
	readonly property real ratio: {
		var v = root.value, m = root.maxValue
		if (!isFinite(v) || !isFinite(m) || m <= 0) return 0
		return Math.max(0, Math.min(1, v / m))
	}

	Rectangle {
		id: track
		anchors.verticalCenter: parent.verticalCenter
		width: parent.width
		height: 6
		radius: 3
		color: root.trackColor

		Rectangle {
			height: parent.height
			radius: 3
			width: track.width * root.ratio
			color: root.muted ? root.mutedFillColor : root.fillColor
		}
	}

	Rectangle {
		id: handle
		width: 14; height: 14; radius: 7
		color: root.muted ? root.mutedFillColor : root.fillColor
		border.width: 2; border.color: "#282828"
		anchors.verticalCenter: parent.verticalCenter
		x: Math.max(0, Math.min(root.width - width, (track.width * root.ratio) - width / 2))
	}

	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		onPressed: (mouse) => updateFromX(mouse.x)
		onPositionChanged: (mouse) => { if (pressed) updateFromX(mouse.x) }

		function updateFromX(x) {
			var ratio = Math.max(0, Math.min(1, x / root.width))
			root.moved(ratio * root.maxValue)
		}
	}
}