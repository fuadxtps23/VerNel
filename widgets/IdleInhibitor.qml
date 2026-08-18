import QtQuick
import Quickshell
import Quickshell.Io

// Idle-inhibitor quick action: keeps a `systemd-inhibit` process running so
// hypridle won't lock the screen, until the user disables it again. The
// button shows a filled/checked style while the inhibitor is active.
Rectangle {
	id: root

	property bool active: false

	width: (parent.width - parent.spacing * 2) / 3
	height: 56
	radius: 12
	color: ma.containsMouse
		? Config.cardBackgroundHover
		: (root.active ? Config.toggleOn : Config.cardBackground)
	border.width: 1
	border.color: root.active ? Config.toggleOn : "transparent"

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Column {
		anchors.centerIn: parent
		spacing: 4

		Text {
			text: "󰛐"
			color: root.active ? Config.background : Config.primary
			font { family: Config.fontFamily; pixelSize: 18 }
			anchors.horizontalCenter: parent.horizontalCenter
		}

		Text {
			text: "Inhibit"
			color: root.active ? Config.background : Config.secondary
			font { family: Config.fontFamily; pixelSize: 10 }
			anchors.horizontalCenter: parent.horizontalCenter
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: {
			// Optimistic: flip the visual immediately so the button feels
			// instant; the real check on next open confirms the state.
			root.active = !root.active
			if (root.active)
				Quickshell.execDetached(["systemd-inhibit", "--what=idle", "--mode=block", "/bin/sh", "-c", "sleep infinity"])
			else
				Quickshell.execDetached(["pkill", "-f", "systemd-inhibit.*idle"])
		}
	}

	// Track whether an inhibitor is currently running.
	Process {
		id: proc
		command: ["pgrep", "-f", "systemd-inhibit.*idle"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.active = text.trim().length > 0
		}
	}

	// Refresh when the quick settings popup opens (signal-driven, so it always
	// applies even while the window is otherwise unmapped).
	Connections {
		target: ShellState
		function onQuickSettingsOpenChanged() {
			if (ShellState.quickSettingsOpen) proc.running = true
		}
	}
}