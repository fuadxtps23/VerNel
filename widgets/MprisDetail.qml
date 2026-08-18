import QtQuick
import Quickshell.Services.Mpris

// Mpris detail popup: album art, track info, progress bar and transport
// controls for the currently selected player.
ShellPopup {
	id: root

	open: ShellState.mprisDetailOpen
	centerVertical: true

	// The player shown here follows the bar's selection: prefer the playing one.
	readonly property var player: {
		let fallback = null
		for (const candidate of Mpris.players.values) {
			if (!candidate.isPlaying && !candidate.trackTitle) continue
			if (candidate.isPlaying) return candidate
			if (fallback === null) fallback = candidate
		}
		return fallback
	}

	// ---- Art + info ----
	Row {
		width: parent.width
		spacing: 10

		Item {
			width: 96
			height: 96

			Image {
				id: art
				anchors.fill: parent
				source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
				fillMode: Image.PreserveAspectCrop
				clip: true
				visible: status === Image.Ready
			}

			Rectangle {
				anchors.fill: parent
				radius: 8
				color: Config.cardBackground
				visible: art.status !== Image.Ready

				Text {
					anchors.centerIn: parent
					text: "󰋋"
					color: Config.accent
					font { family: Config.fontFamily; pixelSize: 30 }
				}
			}
		}

		Column {
			width: parent.width - 96 - parent.spacing
			spacing: 4
			anchors.verticalCenter: parent.verticalCenter

			Text {
				text: root.player ? (root.player.trackTitle || "No track") : "Nothing playing"
				color: Config.text
				wrapMode: Text.Wrap
				font { family: Config.fontFamily; pixelSize: 14; bold: true }
				width: parent.width
			}

			Text {
				text: root.player ? (root.player.trackArtist || "Unknown artist") : ""
				color: Config.secondary
				wrapMode: Text.Wrap
				font { family: Config.fontFamily; pixelSize: 12 }
				width: parent.width
			}

			Text {
				text: root.player ? (root.player.trackAlbum || "") : ""
				color: Config.accent
				wrapMode: Text.Wrap
				font { family: Config.fontFamily; pixelSize: 11 }
				width: parent.width
				visible: text.length > 0
			}
		}
	}

	// ---- Progress ----
	Item {
		width: parent.width
		height: 6

		Rectangle {
			id: progressBg
			anchors.fill: parent
			radius: height / 2
			color: Config.cardBackgroundHover
		}

		Rectangle {
			id: progressFg
			height: parent.height
			radius: height / 2
			color: Config.primary
			width: progressBg.width * root.progress
		}
	}

	Row {
		width: parent.width
		spacing: 2

		Text {
			text: root.formatTime(root.currentPos)
			color: Config.accent
			font { family: Config.fontFamily; pixelSize: 10 }
			width: parent.width / 2
		}

		Text {
			text: root.formatTime(root.trackLength)
			color: Config.accent
			font { family: Config.fontFamily; pixelSize: 10 }
			horizontalAlignment: Text.AlignRight
			width: parent.width / 2
		}
	}

	// ---- Controls ----
	Row {
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: 6

		TransportButton { icon: "󰒮"; enabled: root.player && root.player.canGoPrevious; onClicked: root.player.previous() }
		TransportButton { icon: root.player && root.player.isPlaying ? "󰏤" : "󰐊"; enabled: root.player && root.player.canTogglePlaying; onClicked: root.player.togglePlaying(); width: 64 }
		TransportButton { icon: "󰒭"; enabled: root.player && root.player.canGoNext; onClicked: root.player.next() }
	}

	// MPRIS doesn't push position updates, and player.position only changes
	// reactively on non-linear seeks. `tick` re-reads it on an interval so the
	// time labels and progress bar keep moving (reading position always returns
	// the current value even without a signal).
	property real tick: 0
	Timer {
		interval: 500
		running: root.player != null && root.player.isPlaying
		repeat: true
		onTriggered: {
			root.tick += 1
			const len = root.player ? root.player.length : 0
			const pos = root.player ? root.player.position : 0
			if (len > pos) root.confirmedLength = len
		}
	}

	// Some players (notably firefox) send metadata without mpris:length when a
	// track starts, so quickshell reports the *current position* as the length
	// until they re-send the metadata (which used to require a manual
	// pause/resume). Only accept a length that clearly exceeds the position,
	// remember the last confirmed one, and reset it on track changes so the
	// max duration never follows the current duration.
	property real confirmedLength: 0

	Connections {
		target: root.player
		function onTrackChanged() { root.confirmedLength = 0 }
	}

	readonly property real currentPos: {
		root.tick
		return root.player ? root.player.position : 0
	}

	readonly property real trackLength: {
		root.tick
		if (!root.player) return 0
		const len = root.player.length
		const pos = root.player.position
		return len > pos ? len : root.confirmedLength
	}

	readonly property real progress: {
		root.tick
		return root.trackLength > 0
			? Math.max(0, Math.min(1, root.currentPos / root.trackLength))
			: 0
	}

	// position/length are in seconds, not milliseconds.
	function formatTime(s) {
		if (!isFinite(s) || s <= 0) return "0:00"
		const total = Math.floor(s)
		const m = Math.floor(total / 60)
		const sec = total % 60
		return `${m}:${sec.toString().padStart(2, "0")}`
	}
}