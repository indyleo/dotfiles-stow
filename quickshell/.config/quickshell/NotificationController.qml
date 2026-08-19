import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon + history store.
Item {
	id: root

	readonly property int historyLimit: 25

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
		root.history = [snapshot, ...root.history]
		if (root.history.length > root.historyLimit)
			root.history = root.history.slice(0, root.historyLimit)
	}

	function clearHistory() { root.history = [] }

	function removeHistory(index) {
		if (index < 0 || index >= root.history.length) return
		root.history = root.history.filter((_, i) => i !== index)
	}

	NotificationServer {
		id: server

		imageSupported: true
		bodyMarkupSupported: true
		bodyImagesSupported: true
		actionsSupported: true
		actionIconsSupported: false
		persistenceSupported: true
		keepOnReload: true

		onNotification: notification => {
			notification.tracked = true
			notification.closed.connect(reason => root.pushHistory(notification, reason))
		}
	}

	readonly property alias popups: server.trackedNotifications

	function dismissAll() {
		const list = server.trackedNotifications.values.slice()
		list.forEach(n => n.dismiss())
	}

	function invokeDefaultAction(n) {
		if (!n.actions || n.actions.length === 0) return
		let def = null
		for (let i = 0; i < n.actions.length; i++) {
			if (n.actions[i].identifier === "default") {
				def = n.actions[i]
				break
			}
		}
		if (!def) def = n.actions[0]
		def.invoke()
	}

	function hasProgress(n) {
		return n.hints && n.hints.value !== undefined && !isNaN(n.hints.value)
	}
}
