import QtQuick
import Quickshell.Services.Pipewire

// pulseaudio#microphone - default source volume, rotated 90°.
// Muted shows the source-muted icon.
Item {
	id: root

	width: Config.barWidth
	height: label.height

	property var screen: null
	property var host: null
	property bool highlightEnabled: true
	readonly property bool hovered: ma.containsMouse

	PwObjectTracker {
		objects: [ Pipewire.defaultAudioSource ]
	}

	readonly property var node: Pipewire.defaultAudioSource

	readonly property string text: {
		if (!root.node) return ""
		if (root.node.audio.muted) return ""
		return ` ${Math.round(root.node.audio.volume * 100)}%`
	}

	HoverHighlight {
		anchors.fill: parent
		active: root.highlightEnabled && ma.containsMouse
		host: root.host
	}

	RotatedText {
		id: label
		anchors.centerIn: parent
		text: root.text
		color: Config.primary
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		onClicked: {
			if (mouse.button === Qt.RightButton) {
				if (root.node) root.node.audio.muted = !root.node.audio.muted
			} else if (ShellState.audioControlsOpen) {
				ShellState.closeAll()
			} else {
				ShellState.openAudioControls(root.screen)
			}
		}
		onWheel: {
			if (!root.node) return
			const delta = wheel.angleDelta.y > 0 ? 0.01 : -0.01
			root.node.audio.volume = Math.max(0, Math.min(1, root.node.audio.volume + delta))
		}
	}
}