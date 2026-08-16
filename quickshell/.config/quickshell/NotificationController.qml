import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Registers this shell as the system's org.freedesktop.Notifications
// provider -- a drop-in replacement for mako. Uninstall/disable mako
// (systemctl --user disable --now mako.service, or remove it from your
// Hyprland/dwm autostart) before running this, since only one process
// can own the DBus notification name at a time.
//
// Mirrors your mako `config` 1:1 where it can:
//   max-history=20        -> historyLimit
//   sort=-time             -> history is newest-first (unshift on close)
//   anchor=top-right        -> popup PanelWindow in shell.qml anchors {top;right}
//   icons=1 / markup=1      -> imageSupported/bodyMarkupSupported below
//   [urgency=...] colors    -> restyled to the qs cal* palette in shell.qml
//                                instead (this controller stays theme-agnostic,
//                                same as Audio/BrightnessController)
//   on-button-left=dismiss / -right=dismiss-all / -middle=invoke-default-action
//                            -> wired up in the popup delegate's MouseArea
//   (no default-timeout set) -> popups persist until dismissed unless the
//                                sending app supplies its own expire-timeout
//
// Usage in shell.qml:
//   NotificationController { id: notifs }
//   ... Repeater { model: notifs.popups } / notifs.history / notifs.dismissAll() ...
Item {
	id: root

	// --- mako `max-history=20` -----------------------------------
	readonly property int historyLimit: 20

	// Plain-object snapshots of past notifications, newest first
	// (mirrors mako's `sort=-time`). In-memory only -- clears on
	// shell restart, same as mako's history.
	property var history: []

	function pushHistory(n, reason) {
		const snapshot = {
			appName: n.appName,
			summary: n.summary,
			body: n.body,
			appIcon: n.appIcon,
			image: n.image,
			urgency: n.urgency,
			time: Date.now(),
			closeReason: reason
		}
		history.unshift(snapshot)
		if (history.length > root.historyLimit) history.length = root.historyLimit
		root.historyChanged()
	}

	function clearHistory() { root.history = [] }

	// --- Server ----------------------------------------------------
	// trackedNotifications (aliased below as `popups`) already IS the
	// live popup stack -- no separate queue to maintain.
	NotificationServer {
		id: server

		// icons=1 / markup=1 in the mako config
		imageSupported: true
		bodyMarkupSupported: true
		bodyImagesSupported: true
		actionsSupported: true
		actionIconsSupported: false
		persistenceSupported: true
		keepOnReload: true

		onNotification: notification => {
			notification.tracked = true
			// Capture a snapshot for history the instant this closes,
			// since the Notification object gets destroyed right after
			// (per Notification.closed's docs) once handlers return.
			notification.closed.connect(reason => root.pushHistory(notification, reason))
		}
	}

	readonly property alias popups: server.trackedNotifications

	// --- mako `on-button-right=dismiss-all` -------------------------
	function dismissAll() {
		const list = server.trackedNotifications.values.slice()
		list.forEach(n => n.dismiss())
	}

	// --- mako `on-button-middle=invoke-default-action` ---------------
	// The spec convention is an action with identifier "default"; fall
	// back to the first action if the sender didn't label one.
	function invokeDefaultAction(n) {
		if (!n.actions || n.actions.length === 0) return
		const def = n.actions.find(a => a.identifier === "default") || n.actions[0]
		def.invoke()
	}

	// True when a sender attaches a "value" hint (0-100) -- the same
	// convention mako's progress bar reads (e.g. volume/brightness bridges).
	// Styling (progress-color etc.) lives in shell.qml with the rest of
	// the cal* palette, same as Audio/BrightnessController not knowing
	// about colors either.
	function hasProgress(n) {
		return n.hints && n.hints.value !== undefined && !isNaN(n.hints.value)
	}
}
