import QtQuick
import Quickshell
import Quickshell.Io

// sway/language - shows the active keyboard layout code (e.g. "US").
// The original waybar module targets sway; this uses the Hyprland equivalent.
Item {
	id: root

	width: Config.barWidth
	height: Config.iconHeight

	property string layout: ""

	readonly property string display: {
		const m = root.layout.match(/\(([^)]+)\)/)
		return m ? m[1] : root.layout.split(" ")[0]
	}

	Process {
		id: proc
		command: ["hyprctl", "devices", "-j"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const obj = JSON.parse(text.trim())
					for (const kb of obj.keyboards) {
						if (kb.active_keymap) {
							root.layout = kb.active_keymap
							break
						}
					}
				} catch (e) {}
			}
		}
	}

	Timer {
		interval: 1000
		running: true
		repeat: true
		onTriggered: proc.running = true
	}

	Text {
		anchors.centerIn: parent
		text: root.display
		color: Config.primary
		font {
			family: Config.fontFamily
			pixelSize: Config.pixelSize
			bold: true
		}
	}

	MouseArea {
		anchors.fill: parent
		onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"])
	}
}