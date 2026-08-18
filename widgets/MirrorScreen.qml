import QtQuick
import Quickshell
import Quickshell.Io

// Mirror-screen quick action: mirrors the laptop's eDP-1 onto a connected HDMI
// display (or stops mirroring). Icon/state:
//   󰞊  no HDMI connected - greyed out, not clickable
//   󰄘  HDMI connected, not mirroring - click to start duplicating
//   󰄙  mirroring - highlighted (like IdleInhibitor), click to stop
// State is read from `hyprctl -j monitors` (HDMI-A-1 present + its `mirrorOf`).
Rectangle {
	id: root

	property bool hdmiConnected: false
	property bool mirrorActive: false

	width: (parent.width - parent.spacing * 2) / 3
	height: 56
	radius: 12
	color: ma.containsMouse
		? Config.cardBackgroundHover
		: root.mirrorActive ? Config.toggleOn
		: root.hdmiConnected ? Config.cardBackground
		: Config.withAlpha(Config.text, 0.04)
	border.width: 1
	border.color: root.mirrorActive ? Config.toggleOn : "transparent"

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Column {
		anchors.centerIn: parent
		spacing: 4

		Text {
			text: root.mirrorActive ? "󰄙"
				: root.hdmiConnected ? "󰄘"
				: "󰞊"
			color: root.mirrorActive ? Config.background
				: root.hdmiConnected ? Config.primary
				: Config.withAlpha(Config.secondary, 0.4)
			font { family: Config.fontFamily; pixelSize: 18 }
			anchors.horizontalCenter: parent.horizontalCenter
		}

		Text {
			text: "Mirror"
			color: root.mirrorActive ? Config.background
				: root.hdmiConnected ? Config.secondary
				: Config.withAlpha(Config.secondary, 0.4)
			font { family: Config.fontFamily; pixelSize: 10 }
			anchors.horizontalCenter: parent.horizontalCenter
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: {
			if (!root.hdmiConnected) return
			if (root.mirrorActive)
				Quickshell.execDetached(["hyprctl", "reload"])
			else
				Quickshell.execDetached(["hyprctl", "eval",
					'hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })'])
			statusTimer.restart()
		}
	}

	// Re-check state shortly after a command runs (Hyprland applies async).
	Timer {
		id: statusTimer
		interval: 800
		onTriggered: proc.running = true
	}

	// Parse `hyprctl -j monitors all`: the HDMI output VANISHES from the active
	// list while mirroring (it's a slave), so we must read `all` to see it. In
	// `all`, a connected-but-not-mirroring HDMI has `mirrorOf: "none"`; while
	// mirroring it carries the source's id/name; a physically unplugged monitor
	// shows up `disabled: true`.
	function refreshStatus(data) {
		try {
			const mons = JSON.parse(data)
			let hdmi = null
			for (const m of mons) {
				if (m.name === "HDMI-A-1") { hdmi = m; break }
			}
			root.hdmiConnected = hdmi !== null && !hdmi.disabled
			root.mirrorActive = hdmi !== null && hdmi.mirrorOf !== "none"
		} catch (e) {}
	}

	Process {
		id: proc
		command: ["hyprctl", "-j", "monitors", "all"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.refreshStatus(text)
		}
	}

	// Refresh whenever the quick settings popup opens.
	Connections {
		target: ShellState
		function onQuickSettingsOpenChanged() {
			if (ShellState.quickSettingsOpen) proc.running = true
		}
	}
}
