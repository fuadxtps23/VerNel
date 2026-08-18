import QtQuick
import Quickshell

// custom/volume + pulseaudio#microphone combined into one module: a single
// highlight covers both so hovering either looks like one unit. Clicking
// opens the audio controls popup (input/output devices, sliders, mute).
Item {
	id: root

	property var screen: null
	property var host: null

	width: Config.barWidth
	height: column.implicitHeight

	HoverHighlight {
		anchors.fill: parent
		active: mic.hovered || vol.hovered || ShellState.audioControlsOpen
		host: root.host
	}

	Column {
		id: column
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: 4

		Microphone {
			id: mic
			screen: root.screen
			host: root.host
			highlightEnabled: false
		}

		Volume {
			id: vol
			screen: root.screen
			host: root.host
			highlightEnabled: false
		}
	}
}