import QtQuick
import Quickshell
import Quickshell.Io

// Tracks which screen the cursor is currently on by polling `hyprctl
// cursorpos` (cheap, non-intrusive) and stores the result in
// ShellState.pointerScreen. Used so toasts and popups only ever appear on
// the monitor the cursor is on.
Item {
	id: root

	Timer {
		interval: 400
		repeat: true
		running: true
		onTriggered: posProc.running = true
	}

	Process {
		id: posProc
		command: ["hyprctl", "cursorpos"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.updatePointer(text.trim())
		}
	}

	function updatePointer(str) {
		const parts = str.split(",").map(s => parseInt(s.trim(), 10))
		if (parts.length !== 2 || isNaN(parts[0]) || isNaN(parts[1])) return
		for (const s of Quickshell.screens) {
			if (parts[0] >= s.x && parts[0] < s.x + s.width
				&& parts[1] >= s.y && parts[1] < s.y + s.height) {
				ShellState.pointerScreen = s
				return
			}
		}
	}
}