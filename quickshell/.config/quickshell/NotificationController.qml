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
		history.unshift(snapshot)
		if (history.length > root.historyLimit) history.length = root.historyLimit
		root.historyChanged()
	}

	function clearHistory() { root.history = [] }

	function removeHistory(index) {
		if (index < 0 || index >= root.history.length) return
		root.history = root.history.filter((_, i) => i !== index)
		root.historyChanged()
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
		const def = n.actions.find(a => a.identifier === "default") || n.actions[0]
		def.invoke()
	}

	function hasProgress(n) {
		return n.hints && n.hints.value !== undefined && !isNaN(n.hints.value)
	}
}
