import QtQuick
import Quickshell
import Quickshell.Wayland

// OSD overlay at the bottom center of the screen under the cursor. Shows:
//   - keyboard lock (caps/num) + touchpad: glyph + label + ON/OFF
//   - brightness:                icon + percentage + meter bar
//   - volume:                    icon + percentage + meter bar
// Driven by ShellState.osd* (from OsdMonitor); slide-in/out comes from a
// Hyprland layer rule on the "osd" namespace. The box morphs its width between
// the lock layout and the wider brightness/volume layouts. Purely a display:
// the whole window is click-through (0×0 input mask).
PanelWindow {
	id: root

	required property var modelData

	// Dedicated namespace so hyprland.lua can give this window its own
	// animation (the generic "quickshell" rule forces slide-right on the bar
	// and the popups).
	WlrLayershell.namespace: "osd"
	WlrLayershell.layer: WlrLayer.Overlay

	// 0×0 → empty input region → all clicks pass through.
	mask: emptyRegion

	screen: root.modelData
	height: 58
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	focusable: false

	anchors { bottom: true; left: true; right: true }
	margins { bottom: 24 }

	// Only the screen the cursor was on when the OSD was triggered shows it.
	visible: ShellState.osdVisible
		&& (ShellState.osdScreen == null
			|| (ShellState.osdScreen && root.modelData
				&& ShellState.osdScreen.name === root.modelData.name))

	Region { id: emptyRegion }

	readonly property int boxWidth: ShellState.osdType === "lock"
		|| ShellState.osdType === "touchpad" ? 180 : 230

	readonly property string touchpadIcon: ShellState.osdOn ? "󰟸" : "󰤳"

	readonly property string volumeIcon: {
		if (ShellState.osdMuted) return "󰸈"
		const v = ShellState.osdPercent
		return v <= 30 ? "󰕿" : (v <= 70 ? "󰖀" : "󰕾")
	}

	Rectangle {
		id: box
		anchors.centerIn: parent
		width: root.boxWidth
		height: 56
		radius: 14
		color: Config.popupBackground
		border { width: Config.popupBorderWidth; color: Config.popupBorder }

		Behavior on width {
			NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
		}

		// ---- keyboard lock / touchpad ----
		Row {
			visible: ShellState.osdType === "lock" || ShellState.osdType === "touchpad"
			anchors.centerIn: parent
			spacing: 12

			Text {
				text: ShellState.osdType === "touchpad" ? root.touchpadIcon : "󰌾"
				anchors.verticalCenter: parent.verticalCenter
				color: ShellState.osdOn ? Config.primary : Config.secondary
				font { family: Config.fontFamily; pixelSize: 24; bold: true }
			}

			Column {
				spacing: 2
				anchors.verticalCenter: parent.verticalCenter

				Text {
					text: ShellState.osdLabel
					color: Config.text
					font { family: Config.fontFamily; pixelSize: 13; bold: true }
				}

				Text {
					text: ShellState.osdOn ? "ON" : "OFF"
					color: ShellState.osdOn ? Config.primary : Config.secondary
					font { family: Config.fontFamily; pixelSize: 12; bold: true }
				}
			}
		}

		// ---- brightness / volume (shared meter layout) ----
		Row {
			visible: ShellState.osdType === "brightness" || ShellState.osdType === "volume"
			anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
			spacing: 12

			Text {
				id: iconText
				text: ShellState.osdType === "volume" ? root.volumeIcon : "󰃟"
				anchors.verticalCenter: parent.verticalCenter
				color: ShellState.osdType === "volume" && ShellState.osdMuted
					? Config.secondary : Config.primary
				font { family: Config.fontFamily; pixelSize: 22; bold: true }
			}

			Column {
				spacing: 4
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - parent.spacing - iconText.width

				Text {
					text: `${ShellState.osdPercent}%`
					color: Config.text
					font { family: Config.fontFamily; pixelSize: 13; bold: true }
				}

				Rectangle {
					width: parent.width
					height: 6
					radius: 3
					color: Config.toggleOff

					Rectangle {
						width: parent.width * ShellState.osdPercent / 100
						height: parent.height
						radius: 3
						color: Config.primary

						Behavior on width {
							NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
						}
					}
				}
			}
		}
	}
}