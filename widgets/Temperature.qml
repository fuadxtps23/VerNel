import QtQuick
import Quickshell
import Quickshell.Io

// temperature - "{temperatureC}°C {icon}", rotated 90°. Reads the hottest
// hwmon temp sensor; turns red at the critical threshold (82°C).
Item {
	id: root

	width: Config.barWidth
	height: label.height

	property int tempMilli: 0
	property var host: null
	readonly property int tempC: Math.round(root.tempMilli / 1000)
	readonly property bool critical: root.tempC >= 82

	Process {
		id: proc
		command: ["/bin/sh", "-c", "cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | sort -n | tail -1"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				const v = parseInt(text.trim(), 10)
				if (!isNaN(v)) root.tempMilli = v
			}
		}
	}

	Timer {
		interval: 10000
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
		text: `${root.tempC}°C 󰈸`
		color: root.critical ? Config.critical : Config.primary
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
	}
}