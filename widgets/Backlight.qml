import QtQuick
import Quickshell
import Quickshell.Io

// backlight - "{icon} {percent}%", rotated 90°. Reads
// /sys/class/backlight/*/brightness + max_brightness every 2s.
Item {
	id: root

	width: Config.barWidth
	height: label.height

	property int brightness: 0
	property int maxBrightness: 1
	property var host: null

	readonly property int percent: root.maxBrightness > 0
		? Math.round(100 * root.brightness / root.maxBrightness)
		: 0

	readonly property string icons: ["", "", "", "󰃝", "󰃞", "󰃟", "󰃠"]
	readonly property string icon: {
		const level = Math.floor(root.percent / 100 * root.icons.length)
		return root.icons[Math.max(0, Math.min(root.icons.length - 1, level))]
	}

	Process {
		id: proc
		command: ["/bin/sh", "-c", "B=/sys/class/backlight/*; printf '%s %s' \"$(cat $B/brightness)\" \"$(cat $B/max_brightness)\""]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				const parts = text.trim().split(/\s+/).map(Number)
				if (parts.length >= 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
					root.brightness = parts[0]
					root.maxBrightness = parts[1]
				}
			}
		}
	}

	Timer {
		interval: 2000
		running: true
		repeat: true
		onTriggered: proc.running = true
	}

	HoverHighlight {
		anchors.fill: parent
		active: ma.containsMouse
		host: root.host
	}

	RotatedText {
		id: label
		anchors.centerIn: parent
		text: `${root.percent}% ${root.icon}`
		color: Config.primary
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onWheel: {
			const amount = wheel.angleDelta.y > 0 ? "5%+" : "5%-"
			Quickshell.execDetached(["brightnessctl", "set", amount])
		}
	}
}