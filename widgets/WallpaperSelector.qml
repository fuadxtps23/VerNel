import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper picker: a grid of thumbnails from ~/Pictures/wallpapers. Clicking
// one applies it via awww and regenerates the matugen color scheme (whose
// post_hook reloads quickshell, so the bar colors update immediately).
ShellPopup {
	id: root

	open: ShellState.wallpaperSelectorOpen

	// Keep the toast host below this card too.
	Binding {
		target: ShellState
		property: "wallpaperSelectorBottom"
		value: root.cardBottom
	}

	property string wallpaperDir: "$HOME/Pictures/wallpapers"
	property var images: []

	readonly property int gridW: Config.popupWidth - 24
	readonly property int gridCellW: 94
	readonly property int gridCellH: 62
	readonly property int gridColumns: Math.max(1, Math.floor((root.gridW + 4) / root.gridCellW))
	readonly property int gridHeight: Math.ceil(root.images.length / root.gridColumns) * root.gridCellH

	// ---- Wallpaper listing ----
	Process {
		id: listProc
		command: []
		running: false
		stdout: StdioCollector {
			onStreamFinished: {
				const out = []
				for (const line of text.split('\n')) {
					const p = line.trim()
					if (p.length) out.push(p)
				}
				root.images = out
			}
		}
	}

	function refresh() {
		listProc.command = ["/bin/sh", "-c",
			`find -L ${root.wallpaperDir} -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.webp' \\) -print | sort`]
		listProc.running = true
	}

	// Kill other wallpaper daemons (matching the old rofi script), make sure
	// awww-daemon is up, then set the image and regenerate matugen colors.
	function applyWallpaper(path) {
		if (!path) return
		ShellState.currentWallpaper = path
		ShellState.closeAll()
		Quickshell.execDetached(["/bin/sh", "-c",
			`pkill -x swaybg 2>/dev/null; pkill -x hyprpaper 2>/dev/null; pkill -x mpvpaper 2>/dev/null; if ! pgrep -x awww-daemon >/dev/null 2>&1; then awww-daemon >/dev/null 2>&1 & fi; awww img "${path}" --transition-type any --transition-fps 60 --transition-duration 2 --transition-bezier .43,1.19,1,.4; matugen --source-color-index 0 -t scheme-fidelity image "${path}"`])
	}

	function applyRandom() {
		if (!root.images.length) return
		root.applyWallpaper(root.images[Math.floor(Math.random() * root.images.length)])
	}

	Component.onCompleted: root.refresh()

	// Rescan on every open so newly added wallpapers show up.
	Connections {
		target: ShellState
		function onWallpaperSelectorOpenChanged() {
			if (ShellState.wallpaperSelectorOpen) root.refresh()
		}
	}

	// ---- Header ----
	Item {
		width: parent.width
		height: 22

		Text {
			text: "Wallpapers"
			color: Config.text
			font { family: Config.fontFamily; pixelSize: 12; bold: true }
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
		}

		// Random
		Text {
			text: "󰄶"
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 12 }
			anchors.right: refreshIcon.left
			anchors.rightMargin: 10
			anchors.verticalCenter: parent.verticalCenter
			MouseArea {
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.applyRandom()
			}
		}

		// Rescan
		Text {
			id: refreshIcon
			text: "󰑐"
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 12 }
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			MouseArea {
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.refresh()
			}
		}
	}

	// ---- Thumbnail grid ----
	GridView {
		id: grid
		width: parent.width
		height: Math.min(root.gridHeight, 420)
		cellWidth: root.gridCellW
		cellHeight: root.gridCellH
		clip: true
		interactive: contentHeight > height
		boundsBehavior: Flickable.StopAtBounds
		model: root.images

		delegate: Item {
			required property var modelData
			width: root.gridCellW
			height: root.gridCellH

			Rectangle {
				anchors { fill: parent; margins: 2 }
				radius: 8
				clip: true
				color: Config.cardBackground
				border.width: ma.containsMouse ? 2
					: (ShellState.currentWallpaper === modelData ? 2 : 0)
				border.color: ma.containsMouse ? Config.accent
					: (ShellState.currentWallpaper === modelData
						? Config.activeWorkspace : "transparent")

				Image {
					anchors.fill: parent
					source: "file://" + modelData
					sourceSize { width: 200; height: 130 }
					asynchronous: true
					fillMode: Image.PreserveAspectCrop
				}
			}

			MouseArea {
				id: ma
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.applyWallpaper(modelData)
			}
		}
	}

	Text {
		width: parent.width
		text: root.images.length ? "" : "No wallpapers found in ~/Pictures/wallpapers"
		color: Config.secondary
		font { family: Config.fontFamily; pixelSize: 11 }
		horizontalAlignment: Text.AlignHCenter
		padding: 8
		wrapMode: Text.WordWrap
	}
}
