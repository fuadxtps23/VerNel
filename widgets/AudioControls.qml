import QtQuick
import Quickshell.Services.Pipewire

// Audio controls popup: choose the output/input device from a collapsible
// dropdown, adjust volume with a slider, and toggle mute. Driven by the
// Pipewire module so it's reactive.
ShellPopup {
	id: root

	open: ShellState.audioControlsOpen

	// Keep the toast host in sync with the card's bottom edge so toasts can
	// slide below this panel while it's open (same as quick settings).
	Binding {
		target: ShellState
		property: "audioControlsBottom"
		value: root.cardBottom
	}

	property bool showOutput: false
	property bool showInput: false

	// ---- Header ----
	Row {
		width: parent.width
		spacing: 6

		Text {
			text: "Sound"
			color: Config.text
			font { family: Config.fontFamily; pixelSize: 14; bold: true }
			verticalAlignment: Text.AlignVCenter
		}
	}

	// ---- Output ----
	DropdownHeader {
		expanded: root.showOutput
		label: "OUTPUT"
		sublabel: root.defaultSinkNode
			? (root.defaultSinkNode.description || "Output") : "No device"
		onClicked: root.showOutput = !root.showOutput
	}

	ExpandableSection {
		expanded: root.showOutput

		Repeater {
			model: root.sinks

			delegate: DeviceRow {
				required property var modelData
				name: modelData.description || modelData.name
				icon: "󰓃"
				active: Pipewire.defaultAudioSink === modelData
				onClicked: Pipewire.preferredDefaultAudioSink = modelData
			}
		}
	}

	Row {
		width: parent.width
		spacing: 8
		visible: root.defaultSinkNode != null

		Text {
			text: "Mute"
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 11; bold: true }
			verticalAlignment: Text.AlignVCenter
			width: parent.width - 50
		}

		Switch {
			// Inverted: shows ON (enabled) when NOT muted.
			checked: root.defaultSinkNode ? !root.defaultSinkNode.audio.muted : true
			onToggled: {
				if (root.defaultSinkNode) root.defaultSinkNode.audio.muted = !checked
			}
		}
	}

	VolumeSlider {
		width: parent.width
		value: root.defaultSinkNode ? root.defaultSinkNode.audio.volume : 0
		onChanged: {
			if (root.defaultSinkNode) root.defaultSinkNode.audio.volume = value
		}
	}

	// Separator between the output and input sections.
	Item {
		width: parent.width
		height: 14

		Rectangle {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			height: 1
			color: Config.cardBackgroundHover
		}
	}

	// ---- Input ----
	DropdownHeader {
		expanded: root.showInput
		label: "INPUT"
		sublabel: root.defaultSourceNode
			? (root.defaultSourceNode.description || "Input") : "No device"
		onClicked: root.showInput = !root.showInput
	}

	ExpandableSection {
		expanded: root.showInput

		Repeater {
			model: root.sources

			delegate: DeviceRow {
				required property var modelData
				name: modelData.description || modelData.name
				icon: "󰍬"
				active: Pipewire.defaultAudioSource === modelData
				onClicked: Pipewire.preferredDefaultAudioSource = modelData
			}
		}
	}

	Row {
		width: parent.width
		spacing: 8
		visible: root.defaultSourceNode != null

		Text {
			text: "Mute"
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 11; bold: true }
			verticalAlignment: Text.AlignVCenter
			width: parent.width - 50
		}

		Switch {
			checked: root.defaultSourceNode ? !root.defaultSourceNode.audio.muted : true
			onToggled: {
				if (root.defaultSourceNode) root.defaultSourceNode.audio.muted = !checked
			}
		}
	}

	VolumeSlider {
		width: parent.width
		value: root.defaultSourceNode ? root.defaultSourceNode.audio.volume : 0
		onChanged: {
			if (root.defaultSourceNode) root.defaultSourceNode.audio.volume = value
		}
	}

	// ---- helpers ----
	readonly property var defaultSinkNode: Pipewire.defaultAudioSink
	readonly property var defaultSourceNode: Pipewire.defaultAudioSource

	readonly property var sinks: {
		const out = []
		for (const n of Pipewire.nodes.values) {
			if (root.isSinkNode(n)) out.push(n)
		}
		return out
	}

	readonly property var sources: {
		const out = []
		for (const n of Pipewire.nodes.values) {
			if (root.isSourceNode(n)) out.push(n)
		}
		return out
	}

	function isSinkNode(n) {
		return !!n && !!(n.type & PwNodeType.AudioSink)
			&& !(n.type & PwNodeType.Stream)
	}

	function isSourceNode(n) {
		return !!n && !!(n.type & PwNodeType.AudioSource)
			&& !(n.type & PwNodeType.Stream)
	}
}