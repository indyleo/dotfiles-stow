import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Layouts
import QtCore

Item {
	id: root

	property bool active: false
	property var history: []
	property var pinned: []
	property var snippets: []

	// Maximum number of image entries (history + pinned) before old ones are removed.
	// Only unpinned history images are removed automatically.
	property int maxImages: 25

	property string fontFamily: "sans-serif"
	property int fontSize: 14

	// UI state
	property string searchText: ""
	property string activeTab: "history"   // "history" | "snippets"
	property string previewImagePath: ""   // set to open the full-size image viewer
	property string previewHtmlContent: "" // set to open the rich-text viewer

	readonly property string cacheDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "") + "/.cache/quickshell-clipboard"
	readonly property string historyFile: cacheDir + "/history.json"
	readonly property string pinnedFile: cacheDir + "/pinned.json"
	readonly property string snippetsFile: cacheDir + "/snippets.json"
	readonly property string imageDir: cacheDir + "/images"

	// ------------------------------------------------------------
	// Synchronous file handling – prevents data loss on reload
	// ------------------------------------------------------------

	FileView {
		id: historyFileObj
		path: root.historyFile
	}

	FileView {
		id: pinnedFileObj
		path: root.pinnedFile
	}

	FileView {
		id: snippetsFileObj
		path: root.snippetsFile
	}

	readonly property var filteredEntries: {
		var all = root.pinned.concat(root.history)
		if (root.searchText === "") return all
		var q = root.searchText.toLowerCase()
		return all.filter(function(c) {
			if (c.type === "image") {
				return c.imagePath && c.imagePath.split("/").pop().toLowerCase().includes(q)
			}
			return c.content && c.content.toLowerCase().includes(q)
		})
	}

	function loadHistory() {
		try {
			var parsed = JSON.parse(historyFileObj.text())
			history = Array.isArray(parsed) ? parsed : []
			console.log("[Clipboard] History loaded:", history.length)
		} catch (e) {
			console.warn("[Clipboard] Failed to parse history:", e)
			history = []
			saveHistory()
		}
	}

	function loadPinned() {
		try {
			var parsed = JSON.parse(pinnedFileObj.text())
			pinned = Array.isArray(parsed) ? parsed : []
		} catch (e) {
			console.warn("[Clipboard] Failed to parse pinned:", e)
			pinned = []
			savePinned()
		}
	}

	function loadSnippets() {
		try {
			var parsed = JSON.parse(snippetsFileObj.text())
			snippets = Array.isArray(parsed) ? parsed : []
		} catch (e) {
			snippets = []
		}
	}

	// Batched/debounced saving: every save*() call used to write straight
	// to disk immediately. Rapid-fire changes (e.g. several addClip() calls
	// in quick succession, or dragging through pin toggles) each triggered
	// their own full FileView write. These now just mark what's dirty and
	// (re)start a short timer; the actual write happens once, after
	// changes settle for 500ms, coalescing bursts into a single write.
	property bool _historyDirty: false
	property bool _pinnedDirty: false
	property bool _snippetsDirty: false

	Timer {
		id: saveDebounceTimer
		interval: 500
		repeat: false
		onTriggered: {
			if (root._historyDirty) { root._writeHistory(); root._historyDirty = false }
			if (root._pinnedDirty) { root._writePinned(); root._pinnedDirty = false }
			if (root._snippetsDirty) { root._writeSnippets(); root._snippetsDirty = false }
		}
	}

	function _writeHistory() {
		historyFileObj.setText(JSON.stringify(history, null, 2))
		console.log("[Clipboard] History saved, entries:", history.length)
	}

	function _writePinned() {
		pinnedFileObj.setText(JSON.stringify(pinned, null, 2))
	}

	function _writeSnippets() {
		snippetsFileObj.setText(JSON.stringify(snippets, null, 2))
	}

	function saveHistory() {
		root._historyDirty = true
		saveDebounceTimer.restart()
	}

	function savePinned() {
		root._pinnedDirty = true
		saveDebounceTimer.restart()
	}

	function saveSnippets() {
		root._snippetsDirty = true
		saveDebounceTimer.restart()
	}

	// ------------------------------------------------------------
	// Image limit enforcement
	// ------------------------------------------------------------

	function enforceImageLimit() {
		if (root.maxImages <= 0) return

		// Count all images (history + pinned)
		var imageCount = 0
		for (var i = 0; i < history.length; i++)
		if (history[i].type === "image") imageCount++
		for (var j = 0; j < pinned.length; j++)
		if (pinned[j].type === "image") imageCount++

		var excess = imageCount - root.maxImages
		if (excess <= 0) return

		// Remove oldest unpinned images from history (from the end)
		for (var k = history.length - 1; k >= 0 && excess > 0; k--) {
			if (history[k].type === "image") {
				var removed = history[k]
				history.splice(k, 1)
				deleteImageIfUnreferenced(removed.imagePath)
				excess--
			}
		}
		saveHistory()
	}

	// ------------------------------------------------------------
	// Clipboard monitoring
	// ------------------------------------------------------------

	Process {
		id: clipboardWatch

		command: [
			"wl-paste", "--watch", "sh", "-c",
			"TYPES=$(wl-paste --list-types 2>/dev/null)\n" +
			"if printf '%s\\n' \"$TYPES\" | grep -q 'image/png'; then\n" +
			"    mkdir -p \"$1\"\n" +
			"    FILE=\"$1/clip_$(date +%s%N).png\"\n" +
			"    if wl-paste --type image/png > \"$FILE\" 2>/dev/null; then\n" +
			"        printf 'IMAGE|%s\\n' \"$FILE\"\n" +
			"    else\n" +
			"        rm -f \"$FILE\"\n" +
			"    fi\n" +
			"elif printf '%s\\n' \"$TYPES\" | grep -q 'text/html'; then\n" +
			"    PLAIN=$(wl-paste --no-newline 2>/dev/null | base64 -w0)\n" +
			"    HTML=$(wl-paste --type text/html --no-newline 2>/dev/null | base64 -w0)\n" +
			"    if [ -n \"$HTML\" ]; then\n" +
			"        printf 'HTML64|%s|%s\\n' \"$PLAIN\" \"$HTML\"\n" +
			"    fi\n" +
			"else\n" +
			"    DATA=$(wl-paste --no-newline 2>/dev/null | base64 -w0)\n" +
			"    if [ -n \"$DATA\" ]; then\n" +
			"        printf 'TEXT64|%s\\n' \"$DATA\"\n" +
			"    fi\n" +
			"fi",
			"clipboard-watch",   // $0
			imageDir             // $1
		]

		stdout: SplitParser {
			onRead: function(line) {
				var data = line.trim()
				console.log("[Clipboard] Watcher output:", data)

				if (data === "") return

				if (data.startsWith("TEXT64|")) {
					var encoded = data.substring(7)
					console.log("[Clipboard] Decoding base64, length:", encoded.length)

					decodeProc.command = [
						"sh", "-c",
						"printf '%s' \"$1\" | base64 -d",
						"decode",
						encoded
					]
					decodeProc.running = false
					decodeProc.running = true

				} else if (data.startsWith("HTML64|")) {
					var rest = data.substring(7)
					var sep = rest.indexOf("|")
					if (sep === -1) return
					htmlDecodeProc.pendingPlainB64 = rest.substring(0, sep)
					htmlDecodeProc.pendingHtmlB64 = rest.substring(sep + 1)
					htmlDecodeProc.stage = 1
					htmlDecodeProc.command = [
						"sh", "-c",
						"printf '%s' \"$1\" | base64 -d",
						"decode-html-plain",
						htmlDecodeProc.pendingPlainB64
					]
					htmlDecodeProc.running = false
					htmlDecodeProc.running = true

				} else if (data.startsWith("IMAGE|")) {
					var imagePath = data.substring(6)
					if (imagePath !== "")
					root.addClip("image", "", imagePath)
				}
			}
		}

		onStarted: {
			console.log("[Clipboard] watcher started")
		}

		onExited: function(code, status) {
			console.warn("[Clipboard] watcher exited:", code, status)
			restartClipboardTimer.start()
		}
	}

	Process {
		id: decodeProc

		stdout: StdioCollector {
			onStreamFinished: {
				if (text.length > 0) {
					console.log("[Clipboard] Decoded text:", text)
					root.addClip("text", text, "")
				} else {
					console.warn("[Clipboard] Decoded text is empty (process may have failed)")
				}
			}
		}

		onStarted: {
			console.log("[Clipboard] decodeProc started")
		}

		onExited: function(code, status) {
			console.log("[Clipboard] decodeProc exited with code", code, "status", status)
		}
	}

	Process {
		id: htmlDecodeProc
		property string pendingPlainB64: ""
		property string pendingHtmlB64: ""
		property string decodedPlain: ""
		property int stage: 0   // 0 = idle, 1 = decoding plain text, 2 = decoding HTML body

		stdout: StdioCollector {
			onStreamFinished: {
				if (htmlDecodeProc.stage === 1) {
					htmlDecodeProc.decodedPlain = text
					htmlDecodeProc.stage = 2
					htmlDecodeProc.command = [
						"sh", "-c",
						"printf '%s' \"$1\" | base64 -d",
						"decode-html-body",
						htmlDecodeProc.pendingHtmlB64
					]
					htmlDecodeProc.running = false
					htmlDecodeProc.running = true
				} else if (htmlDecodeProc.stage === 2) {
					if (text.length > 0) {
						root.addClip("html", htmlDecodeProc.decodedPlain, "", text)
					}
					htmlDecodeProc.stage = 0
				}
			}
		}
	}

	Timer {
		id: restartClipboardTimer
		interval: 1000
		repeat: false
		onTriggered: {
			if (!clipboardWatch.running)
			clipboardWatch.running = true
		}
	}

	// ------------------------------------------------------------
	// History management
	// ------------------------------------------------------------

	// Generalized equality for clip entries. Previously duplicate-check /
	// pin / unpin / remove logic used a ternary of
	// `type === "text" ? content-compare : imagePath-compare`, which
	// silently broke for any type other than "text" or "image": adding
	// "html" would have fallen into the imagePath branch, comparing
	// `undefined === undefined` (always true), treating every HTML clip as
	// a duplicate of every other one.
	function clipsEqual(a, b) {
		if (a.type !== b.type) return false
		if (a.type === "image") return a.imagePath === b.imagePath
		// text and html both key off their plain-text "content" field
		return a.content === b.content
	}

	function addClip(type, content, imagePath, htmlContent) {
		console.log("[Clipboard] addClip called:", type, content ? content.substring(0,30) : "", imagePath)

		if ((type === "text" || type === "html") && (!content || content.length === 0)) {
			console.log("[Clipboard] Ignoring empty text")
			return
		}

		var candidate = { type: type, content: content, imagePath: imagePath, htmlContent: htmlContent || "" }

		// Avoid duplicates
		for (var i = 0; i < history.length; i++) {
			if (root.clipsEqual(history[i], candidate)) {
				console.log("[Clipboard] Duplicate, ignoring")
				return
			}
		}

		if (isPinned(candidate)) {
			console.log("[Clipboard] Already pinned, ignoring")
			return
		}

		// Create new entry and reassign history (so QML signals fire)
		var entry = {
			type: type,
			content: content,
			imagePath: imagePath,
			htmlContent: htmlContent || "",
			timestamp: Date.now()
		}

		history = [entry, ...history].slice(0, 150)

		// Enforce image limit (saves history as well)
		enforceImageLimit()
		console.log("[Clipboard] Added to history, total:", history.length)
	}

	function togglePin(clip) {
		var idx = -1
		for (var i = 0; i < pinned.length; i++) {
			if (root.clipsEqual(pinned[i], clip)) {
				idx = i
				break
			}
		}

		if (idx >= 0) {
			// Remove from pinned and add back to history
			var removed = pinned[idx]
			pinned = pinned.filter((_, i) => i !== idx)
			history = [removed, ...history].slice(0, 150)
		} else {
			// Add to pinned and remove from history
			pinned = [clip, ...pinned]
			history = history.filter(h => !root.clipsEqual(h, clip))
		}
		saveHistory()
		savePinned()
	}

	Process {
		id: deleteFileProc
		function run(cmd) { command = cmd; running = false; running = true }
	}

	// Deletes an image file from disk, but only if it's no longer
	// referenced by any remaining history/pinned entry.
	function deleteImageIfUnreferenced(imagePath) {
		if (!imagePath) return
		var stillReferenced = history.some(h => h.type === "image" && h.imagePath === imagePath) ||
		pinned.some(p => p.type === "image" && p.imagePath === imagePath)
		if (!stillReferenced)
		deleteFileProc.run(["rm", "-f", imagePath])
	}

	function removeClip(clip) {
		if (isPinned(clip)) {
			pinned = pinned.filter(p => !root.clipsEqual(p, clip))
		}
		history = history.filter(h => !root.clipsEqual(h, clip))
		saveHistory()
		savePinned()

		if (clip.type === "image")
		deleteImageIfUnreferenced(clip.imagePath)
	}

	function pasteClip(clip) {
		if (clip.type === "text") {
			copyProc.command = ["wl-copy", "--", clip.content]
		} else if (clip.type === "html") {
			// Use the plain‑text version (content) and strip any leftover HTML tags.
			var plain = clip.content || ""
			// Remove any HTML tags, just in case the plain text was not captured cleanly.
			plain = plain.replace(/<[^>]*>/g, "")
			copyProc.command = ["wl-copy", "--", plain]
		} else if (clip.type === "image") {
			copyProc.command = ["sh", "-c", "wl-copy --type image/png < \"$1\"", "clipboard-copy", clip.imagePath]
		}
		copyProc.running = false
		copyProc.running = true
	}

	function isPinned(clip) {
		for (var i = 0; i < pinned.length; i++) {
			if (root.clipsEqual(pinned[i], clip))
			return true
		}
		return false
	}

	// ------------------------------------------------------------
	// Snippets — named, user-saved reusable text/html, independent of
	// clipboard history (won't get evicted by the 150-entry cap or the
	// image limit, and survive until explicitly deleted).
	// ------------------------------------------------------------

	function addSnippet(name, content, htmlContent) {
		if (!name || name.trim() === "" || !content) return
		snippets = [{ name: name.trim(), content: content, htmlContent: htmlContent || "" }, ...snippets]
		saveSnippets()
	}

	function removeSnippet(snippet) {
		snippets = snippets.filter(s => s.name !== snippet.name || s.content !== snippet.content)
		saveSnippets()
	}

	function pasteSnippet(snippet) {
		if (snippet.htmlContent) {
			// If you want to keep rich‑text pasting for snippets, leave this as is.
			// To force plain text, use: copyProc.command = ["wl-copy", "--", snippet.content]
		} else {
			copyProc.command = ["wl-copy", "--", snippet.content]
		}
		copyProc.running = false
		copyProc.running = true
	}

	property var pendingSnippetContent: null   // {content, htmlContent} staged from "save as snippet"; consumed by the New Snippet row

	Process {
		id: copyProc
		onExited: function(code, status) {
			if (code !== 0)
			console.warn("[Clipboard] wl-copy failed:", code, status)
		}
	}

	// ------------------------------------------------------------
	// Overlay UI (uses fixed font and pixel size)
	// ------------------------------------------------------------

	PanelWindow {
		id: clipboardWindow
		screen: Quickshell.screens[0]
		visible: root.active
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

		onVisibleChanged: {
			if (visible) {
				root.searchText = ""
				searchInput.text = ""
				newSnippetNameInput.text = ""
				root.pendingSnippetContent = null
			}
		}

		anchors { top: true; right: true; bottom: true }
		margins.top: 42; margins.right: 12; margins.bottom: 12
		implicitWidth: 380

		Rectangle {
			anchors.fill: parent
			radius: 13
			color: "#282828"
			border.width: 2
			border.color: "#504945"

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 8
				spacing: 8

				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					Rectangle {
						Layout.preferredHeight: 26
						Layout.preferredWidth: clipHeaderText.implicitWidth + 20
						radius: 13
						color: "#3c3836"

						Text {
							id: clipHeaderText
							anchors.centerIn: parent
							text: " Clipboard"
							color: "#d5c4a1"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 13
							font.bold: true
						}
					}

					Item { Layout.fillWidth: true }

					Rectangle {
						Layout.preferredHeight: 26
						Layout.preferredWidth: clearText.implicitWidth + 20
						radius: 13
						color: "#3c3836"
						visible: root.activeTab === "history"

						Text {
							id: clearText
							anchors.centerIn: parent
							text: "Clear"
							color: "#fb4934"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 13
							font.bold: true
						}

						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							hoverEnabled: true
							onClicked: {
								var cleared = root.history
								root.history = []
								root.saveHistory()
								for (var i = 0; i < cleared.length; i++) {
									if (cleared[i].type === "image")
									root.deleteImageIfUnreferenced(cleared[i].imagePath)
								}
							}
							onEntered: {
								parent.color = "#7c6f64"
								parent.border.color = "#fe8019"
							}
							onExited: {
								parent.color = "#504945"
								parent.border.color = "#7c6f64"
							}

						}
					}
				}

				// Tabs
				RowLayout {
					Layout.fillWidth: true
					spacing: 6

					Rectangle {
						Layout.fillWidth: true
						Layout.preferredHeight: 26
						radius: 8
						color: root.activeTab === "history" ? "#504945" : "#3c3836"
						border.width: root.activeTab === "history" ? 1 : 0
						border.color: "#fabd2f"
						Text {
							anchors.centerIn: parent
							text: "History"
							color: "#ebdbb2"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 12
							font.bold: root.activeTab === "history"
						}
						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							hoverEnabled: true
							onClicked: {
								root.activeTab = "history"
								root.searchText = ""
								searchInput.text = ""
							}
							onEntered: {
								parent.color = "#7c6f64"
							}
							onExited: {
								parent.color = "#504945"
							}
						}
					}
					Rectangle {
						Layout.fillWidth: true
						Layout.preferredHeight: 26
						radius: 8
						color: root.activeTab === "snippets" ? "#504945" : "#3c3836"
						border.width: root.activeTab === "snippets" ? 1 : 0
						border.color: "#fabd2f"
						Text {
							anchors.centerIn: parent
							text: "Snippets" + (root.snippets.length > 0 ? " (" + root.snippets.length + ")" : "")
							color: "#ebdbb2"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 12
							font.bold: root.activeTab === "snippets"
						}
						MouseArea {
							anchors.fill: parent
							cursorShape: Qt.PointingHandCursor
							hoverEnabled: true
							onClicked: {
								root.activeTab = "snippets"
								root.searchText = ""
								searchInput.text = ""
								newSnippetNameInput.text = ""
							}
							onEntered: {
								parent.color = "#7c6f64"
							}
							onExited: {
								parent.color = "#504945"
							}
						}
					}
				}

				// Search / filter bar
				Rectangle {
					Layout.fillWidth: true
					Layout.preferredHeight: 30
					radius: 10
					color: "#3c3836"
					border.width: 1
					border.color: searchInput.activeFocus ? "#fabd2f" : "#504945"

					RowLayout {
						anchors.fill: parent
						anchors.leftMargin: 8
						anchors.rightMargin: 8
						spacing: 6
						Text { text: ""; color: "#7c6f64"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
						TextInput {
							id: searchInput
							Layout.fillWidth: true
							text: root.searchText
							onTextEdited: root.searchText = text
							color: "#ebdbb2"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 13
							clip: true
						}
						Text {
							visible: root.searchText !== ""
							text: "✕"
							color: "#7c6f64"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 11
							MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { root.searchText = ""; searchInput.text = "" } }
						}
					}
				}

				Rectangle { Layout.fillWidth: true; height: 1; color: "#504945" }

				ListView {
					Layout.fillWidth: true
					Layout.fillHeight: true
					visible: root.activeTab === "history"
					clip: true
					spacing: 6
					model: root.filteredEntries

					Text {
						visible: root.filteredEntries.length === 0
						anchors.centerIn: parent
						text: root.searchText !== "" ? "No matches" : "No clipboard items"
						color: "#bdae93"
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 13
					}

					delegate: Rectangle {
						required property var modelData
						width: ListView.view.width
						height: clipRow.implicitHeight + 12
						radius: 13
						color: "#3c3836"

						RowLayout {
							id: clipRow
							anchors.fill: parent
							anchors.margins: 8
							spacing: 8

							Item {
								visible: modelData.type === "image"
								Layout.preferredWidth: 32
								Layout.preferredHeight: 32
								Layout.alignment: Qt.AlignVCenter

								Rectangle {
									anchors.fill: parent
									radius: 6
									color: "#282828"
								}

								Image {
									id: thumb
									anchors.fill: parent
									source: modelData.type === "image" && modelData.imagePath
									? "file://" + modelData.imagePath : ""
									fillMode: Image.PreserveAspectCrop
									asynchronous: true
									cache: false
								}

								Text {
									anchors.centerIn: parent
									visible: thumb.status !== Image.Ready
									text: ""
									color: "#bdae93"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 13
								}

								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: root.pasteClip(modelData)
									onDoubleClicked: root.previewImagePath = modelData.imagePath
								}
							}

							ColumnLayout {
								Layout.fillWidth: true
								spacing: 2

								Text {
									Layout.fillWidth: true
									text: {
										if (modelData.type === "text" || modelData.type === "html")
										return modelData.content !== undefined ? modelData.content.substring(0, 60) : ""
										if (modelData.type === "image")
										return "Image: " + (modelData.imagePath !== undefined ? modelData.imagePath.split("/").pop() : "")
										return ""
									}
									color: "#ebdbb2"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 13
									font.bold: false
									horizontalAlignment: Text.AlignHCenter
									wrapMode: Text.Wrap
									elide: Text.ElideRight
									maximumLineCount: 3
								}
							}

							// Preview Button (rich text only - images preview via double-click)
							Text {
								visible: modelData.type === "html"
								text: "\uf06e"
								color: "#83a598"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								Layout.alignment: Qt.AlignVCenter
								MouseArea {
									anchors.fill: parent
									anchors.margins: -4
									cursorShape: Qt.PointingHandCursor
									onClicked: root.previewHtmlContent = modelData.htmlContent
								}
							}

							// Save as Snippet Button (text/html only)
							Text {
								visible: modelData.type === "text" || modelData.type === "html"
								text: "\uf0c7"
								color: "#b8bb26"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								Layout.alignment: Qt.AlignVCenter
								MouseArea {
									anchors.fill: parent
									anchors.margins: -4
									cursorShape: Qt.PointingHandCursor
									onClicked: {
										root.pendingSnippetContent = { content: modelData.content, htmlContent: modelData.htmlContent || "" }
										root.activeTab = "snippets"
									}
								}
							}

							// Pin Button
							Text {
								text: root.isPinned(modelData) ? "" : ""
								color: root.isPinned(modelData) ? "#fabd2f" : "#7c6f64"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								Layout.alignment: Qt.AlignVCenter
								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: root.togglePin(modelData)
								}
							}

							// Paste Button
							Text {
								text: ""
								color: "#83a598"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								Layout.alignment: Qt.AlignVCenter
								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: root.pasteClip(modelData)
								}
							}

							// Delete Button
							Text {
								text: "✕"
								color: "#fb4934"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 13
								Layout.alignment: Qt.AlignVCenter
								MouseArea {
									anchors.fill: parent
									cursorShape: Qt.PointingHandCursor
									onClicked: root.removeClip(modelData)
								}
							}
						}

						MouseArea {
							anchors.fill: parent
							z: -1
							acceptedButtons: Qt.LeftButton
							cursorShape: Qt.PointingHandCursor
							onClicked: root.pasteClip(modelData)
						}
					}
				}

				// ------------------------------------------------------------
				// Snippets tab
				// ------------------------------------------------------------

				ColumnLayout {
					Layout.fillWidth: true
					Layout.fillHeight: true
					visible: root.activeTab === "snippets"
					spacing: 8

					Rectangle {
						Layout.fillWidth: true
						Layout.preferredHeight: newSnippetCol.implicitHeight + 16
						radius: 10
						color: "#3c3836"
						border.width: 1
						border.color: "#504945"

						ColumnLayout {
							id: newSnippetCol
							anchors.fill: parent
							anchors.margins: 8
							spacing: 6

							Text {
								text: root.pendingSnippetContent
								? "Naming: " + (root.pendingSnippetContent.content || "").substring(0, 40)
								: "Save a clip as snippet first (\uf0c7 icon in History)"
								color: root.pendingSnippetContent ? "#ebdbb2" : "#7c6f64"
								font.family: "JetBrainsMono Nerd Font"
								font.pixelSize: 12
								wrapMode: Text.Wrap
								Layout.fillWidth: true
							}

							RowLayout {
								Layout.fillWidth: true
								spacing: 6
								visible: root.pendingSnippetContent !== null

								Rectangle {
									Layout.fillWidth: true
									Layout.preferredHeight: 28
									radius: 8
									color: "#282828"
									border.width: 1
									border.color: newSnippetNameInput.activeFocus ? "#fabd2f" : "#504945"
									TextInput {
										id: newSnippetNameInput
										anchors.fill: parent
										anchors.leftMargin: 8
										anchors.rightMargin: 8
										verticalAlignment: TextInput.AlignVCenter
										color: "#ebdbb2"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 13
										Keys.onReturnPressed: addSnippetBtn.trigger()
									}
								}

								Rectangle {
									id: addSnippetBtn
									Layout.preferredWidth: 60
									Layout.preferredHeight: 28
									radius: 8
									color: "#b8bb26"
									function trigger() {
										if (newSnippetNameInput.text.trim() === "" || !root.pendingSnippetContent) return
										root.addSnippet(newSnippetNameInput.text, root.pendingSnippetContent.content, root.pendingSnippetContent.htmlContent)
										newSnippetNameInput.text = ""
										root.pendingSnippetContent = null
									}
									Text { anchors.centerIn: parent; text: "Add"; color: "#282828"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true }
									MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addSnippetBtn.trigger() }
								}
							}
						}
					}

					ListView {
						Layout.fillWidth: true
						Layout.fillHeight: true
						clip: true
						spacing: 6
						model: root.searchText === "" ? root.snippets : root.snippets.filter(function(s) {
							return s.name.toLowerCase().includes(root.searchText.toLowerCase()) ||
							(s.content && s.content.toLowerCase().includes(root.searchText.toLowerCase()))
						})

						Text {
							visible: root.snippets.length === 0
							anchors.centerIn: parent
							text: "No snippets saved yet"
							color: "#bdae93"
							font.family: "JetBrainsMono Nerd Font"
							font.pixelSize: 13
						}

						delegate: Rectangle {
							id: snippetDelegate
							required property var modelData
							width: ListView.view.width
							height: 52
							radius: 10
							color: "#3c3836"
							border.width: 1
							border.color: "#504945"

							MouseArea {
								anchors.fill: parent
								z: -1
								cursorShape: Qt.PointingHandCursor
								onClicked: root.pasteSnippet(snippetDelegate.modelData)
							}

							RowLayout {
								anchors.fill: parent
								anchors.margins: 8
								spacing: 8

								ColumnLayout {
									Layout.fillWidth: true
									spacing: 0
									Text {
										text: snippetDelegate.modelData.name
										color: "#fabd2f"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 13
										font.bold: true
										elide: Text.ElideRight
										Layout.fillWidth: true
									}
									Text {
										text: (snippetDelegate.modelData.content || "").substring(0, 50)
										color: "#bdae93"
										font.family: "JetBrainsMono Nerd Font"
										font.pixelSize: 11
										elide: Text.ElideRight
										Layout.fillWidth: true
									}
								}

								Text {
									text: "✕"
									color: "#fb4934"
									font.family: "JetBrainsMono Nerd Font"
									font.pixelSize: 13
									Layout.alignment: Qt.AlignVCenter
									MouseArea {
										anchors.fill: parent
										anchors.margins: -4
										cursorShape: Qt.PointingHandCursor
										onClicked: root.removeSnippet(snippetDelegate.modelData)
									}
								}
							}
						}
					}
				}
			}
		}
	}

	// ------------------------------------------------------------
	// Full-size preview overlays (image / rich text)
	// ------------------------------------------------------------

	PanelWindow {
		id: previewWindow
		screen: Quickshell.screens[0]
		visible: root.previewImagePath !== "" || root.previewHtmlContent !== ""
		color: "transparent"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.layer: WlrLayer.Overlay
		anchors { top: true; bottom: true; left: true; right: true }

		function close() {
			root.previewImagePath = ""
			root.previewHtmlContent = ""
		}

		MouseArea {
			anchors.fill: parent
			onClicked: previewWindow.close()
		}

		Rectangle {
			width: Math.min(parent.width - 80, 900)
			height: Math.min(parent.height - 80, 700)
			anchors.centerIn: parent
			radius: 16
			color: "#282828"
			border.width: 2
			border.color: "#504945"

			// Swallow clicks so clicking the content itself doesn't close the preview
			MouseArea { anchors.fill: parent; onClicked: {} }

			ColumnLayout {
				anchors.fill: parent
				anchors.margins: 12
				spacing: 8

				RowLayout {
					Layout.fillWidth: true
					Text {
						text: root.previewImagePath !== "" ? "Image Preview" : "Rich Text Preview"
						color: "#ebdbb2"
						font.family: "JetBrainsMono Nerd Font"
						font.pixelSize: 15
						font.bold: true
						Layout.fillWidth: true
					}
					Rectangle {
						Layout.preferredWidth: 28
						Layout.preferredHeight: 28
						radius: 14
						color: "#3c3836"
						Text { anchors.centerIn: parent; text: "✕"; color: "#fb4934"; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: previewWindow.close() }
					}
				}

				Image {
					visible: root.previewImagePath !== ""
					Layout.fillWidth: true
					Layout.fillHeight: true
					source: root.previewImagePath !== "" ? "file://" + root.previewImagePath : ""
					fillMode: Image.PreserveAspectFit
					asynchronous: true
					cache: false
				}

				Flickable {
					visible: root.previewHtmlContent !== ""
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					contentWidth: width
					contentHeight: htmlPreviewText.implicitHeight
					Text {
						id: htmlPreviewText
						width: parent.width
						text: root.previewHtmlContent
						textFormat: Text.RichText
						wrapMode: Text.Wrap
						color: "#ebdbb2"
						font.family: root.fontFamily
						font.pixelSize: 14
					}
				}
			}
		}
	}

	// ------------------------------------------------------------
	// Startup
	// ------------------------------------------------------------

	Process {
		id: shellProc
		onExited: {
			// Directory should now exist, so loading and saving are safe
			loadHistory()
			loadPinned()
			loadSnippets()
			enforceImageLimit()          // cleanup if previous run exceeded the limit
			clipboardWatch.running = true
		}
	}

	Component.onCompleted: {
		shellProc.command = ["mkdir", "-p", cacheDir, imageDir]
		shellProc.running = true
	}
}
