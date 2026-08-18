import QtQuick
import Quickshell
import Quickshell.Hyprland

// ext/workspaces - shows workspace numbers 1..N where N grows to include any
// workspace that is created (so switching to a brand-new workspace 6 shows it
// instead of being capped at 5). Active workspace is bright, inactive are
// dim. Smooth color transitions + hover glow.
//
// A single full-widget MouseArea handles everything: click a number to switch
// to that workspace, scroll to move to the next/previous workspace, hover to
// highlight. (Nested MouseAreas can't share events reliably here, so the
// clicked/hovered number is computed from the cursor's y position instead.)
Item {
	id: root

	width: Config.barWidth
	height: Math.max(1, column.implicitHeight)

	// Row pitch = row height + column spacing, used to map cursor y to a
	// workspace index (see the MouseArea below).
	readonly property real rowPitch: 16 + 2

	property int hoverIndex: -1

	// Only real workspaces are shown (empty ones are destroyed by Hyprland,
	// so switching to a new one adds it here automatically). If more than 5
	// exist, a sliding window of 5 follows the focused workspace so the active
	// number stays visible.
	readonly property var workspaceList: {
		const all = []
		for (const w of Hyprland.workspaces.values) {
			if (w.id >= 1) all.push(w)
		}
		all.sort((a, b) => a.id - b.id)

		if (all.length <= 5) return all

		const focus = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : all[0].id
		let idx = all.findIndex(w => w.id === focus)
		if (idx < 0) idx = 0
		const start = Math.min(Math.max(0, idx - 2), all.length - 5)
		return all.slice(start, start + 5)
	}

	Column {
		id: column
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: 2

		Repeater {
			model: root.workspaceList

			delegate: Item {
				required property var modelData
				required property int index
				width: Config.barWidth
				height: 16

				Text {
					anchors.centerIn: parent
					text: modelData.id
					color: modelData.active
						? Config.accent
						: (root.hoverIndex === index ? Config.secondary : Config.activeWorkspace)
					font {
						family: Config.fontFamily
						pixelSize: Config.pixelSize
						bold: true
					}
					opacity: modelData.active ? 1 : 0.7

					Behavior on color {
						ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
					}
					Behavior on opacity {
						NumberAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
					}
				}
			}
		}
	}

	// Switch via `hyprctl eval`. Hyprland >= 0.55 runs a Lua config where
	// the legacy `workspace` dispatcher doesn't exist; the Lua API needs a
	// dispatcher created with hl.dsp.focus({...}) and executed with
	// hl.dispatch(...). (quickshell's own socket-based Hyprland.dispatch is
	// also incompatible with 0.56's IPC, so we shell out instead.)
	// Hyprland's `workspaces` animation makes the switch smooth.
	function switchTo(expr) {
		Quickshell.execDetached(["hyprctl", "eval", expr])
	}

	// Mouse-initiated switch (click/scroll). Hyprland's
	// `warp_on_change_workspace` warps the cursor to the target workspace's
	// last focused window on ANY switch — we don't want that when switching
	// with the mouse, so after the switch the cursor is moved back to where it
	// was. The pre-switch position is captured from `hyprctl cursorpos` (mapToGlobal
	// returns local coords for layer surfaces, which is wrong). Keyboard-initiated
	// switches (mainMod + number) are left untouched and still warp.
	function mouseSwitch(expr) {
		Quickshell.execDetached(["bash", "-c",
			`POS=$(hyprctl cursorpos) ; hyprctl eval '${expr}' ; sleep 0.15 ; hyprctl eval "hl.dispatch(hl.dsp.cursor.move({ x = \${POS%,*}, y = \${POS#*,} }))"`])
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton

		function hoverIndexAt(y) {
			const i = Math.floor(y / root.rowPitch)
			return (i >= 0 && i < root.workspaceList.length) ? i : -1
		}

		onEntered: root.hoverIndex = hoverIndexAt(mouse.y)
		onPositionChanged: root.hoverIndex = hoverIndexAt(mouse.y)
		onExited: root.hoverIndex = -1

		onWheel: {
			const rel = wheel.angleDelta.y > 0 ? "e-1" : "e+1"
			root.mouseSwitch(`hl.dispatch(hl.dsp.focus({ workspace = "${rel}" }))`)
		}

		onClicked: {
			const i = hoverIndexAt(mouse.y)
			if (i >= 0)
				root.mouseSwitch(
					`hl.dispatch(hl.dsp.focus({ workspace = ${root.workspaceList[i].id} }))`)
		}
	}
}
