import QtQuick
import Quickshell

// custom/orbit - opens the macOS-style quick settings panel on click.
// A "<" inside a round ball that rotates to ">" while the panel is open;
// clicking again (or outside) closes it.
Item {
	id: root

	property var screen: null
	property var host: null

	width: Config.barWidth
	height: Config.iconHeight

	HoverHighlight {
		anchors.fill: parent
		active: ma.containsMouse
		host: root.host
	}

	Rectangle {
		id: ball
		width: Config.iconHeight - 2
		height: Config.iconHeight - 2
		radius: width / 2
		anchors.centerIn: parent
		color: ma.containsMouse || ShellState.quickSettingsOpen
			? Config.cardBackgroundHover
			: "transparent"
		border.width: 1
		border.color: ShellState.quickSettingsOpen ? Config.primary : Config.accent

		Behavior on color {
			ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
		}
		Behavior on border.color {
			ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
		}

		Text {
			id: chevron
			anchors.centerIn: parent
			text: "<"
			color: ShellState.quickSettingsOpen ? Config.activeWorkspace : Config.primary
			rotation: ShellState.quickSettingsOpen ? 180 : 0
			transformOrigin: Item.Center
			font {
				family: Config.fontFamily
				pixelSize: 13
				bold: true
			}
			Behavior on color {
				ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
			}
			Behavior on rotation {
				NumberAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
			}
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: {
			if (ShellState.quickSettingsOpen) ShellState.closeAll()
			else ShellState.openQuickSettings(root.screen)
		}
	}
}