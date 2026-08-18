import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// pulseaudio#1 - default sink volume "{icon} {volume}%", rotated 90°.
Item {
	id: root

	width: Config.barWidth
	height: label.height

	property var screen: null
	property var host: null
	property bool highlightEnabled: true
	readonly property bool hovered: ma.containsMouse

	PwObjectTracker {
		objects: [ Pipewire.defaultAudioSink ]
	}

	readonly property var node: Pipewire.defaultAudioSink

	readonly property string text: {
		if (!root.node) return ""
		if (root.node.audio.muted) return "󰸈"
		const v = root.node.audio.volume
		const icon = v <= 0.3 ? "" : (v <= 0.7 ? "" : "")
		return `${icon} ${Math.round(v * 100)}%`
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
			if (mouse.button === Qt.RightButton)
				Quickshell.execDetached(["pavucontrol"])
			else if (ShellState.audioControlsOpen)
				ShellState.closeAll()
			else
				ShellState.openAudioControls(root.screen)
		}
		onWheel: {
			if (!root.node) return
			// Normal scroll ±5%, shift+scroll ±1%.
			const step = (wheel.modifiers & Qt.ShiftModifier) ? 0.01 : 0.05
			const delta = wheel.angleDelta.y > 0 ? step : -step
			root.node.audio.volume = Math.max(0, Math.min(1, root.node.audio.volume + delta))
		}
	}
}