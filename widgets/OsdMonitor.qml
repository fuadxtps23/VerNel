import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Drives the OSD overlay for four things:
//  - caps/num lock (Hyprland has no LED-change event, so poll `hyprctl -j
//    devices` and diff. Tracks every keyboard instead of just the "main" one,
//    since which device is "main" can shift around.)
//  - touchpad on/off (TouchPad.sh toggles `hl.device(... enabled)` and writes
//    its state to $XDG_RUNTIME_DIR/touchpad.status; we poll that file.)
//  - volume (react to Pipewire default-sink volume/mute changes)
//  - brightness (poll /sys/class/backlight/*/brightness)
// It sets ShellState.osd* and the 3s hide timer; Osd.qml renders it.
Item {
	id: root

	// ---- keyboard locks ----
	property var kbState: ({})
	property bool lockReady: false

	Process {
		id: lockProc
		command: ["hyprctl", "-j", "devices"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.parseLocks(text)
		}
	}

	Timer {
		interval: 200
		running: true
		repeat: true
		onTriggered: lockProc.running = true
	}

	function parseLocks(raw) {
		try {
			const obj = JSON.parse(raw.trim())
			for (const kb of obj.keyboards) {
				const prev = root.kbState[kb.name]
				const caps = !!kb.capsLock
				const num = !!kb.numLock
				if (!root.lockReady) {
					root.kbState[kb.name] = { caps, num }
					continue
				}
				if (prev && (prev.caps !== caps || prev.num !== num)) {
					root.kbState[kb.name] = { caps, num }
					if (prev.caps !== caps) root.showLock("CAPS LOCK", caps)
					if (prev.num !== num) root.showLock("NUM LOCK", num)
				} else if (!prev) {
					root.kbState[kb.name] = { caps, num }
				}
			}
			if (!root.lockReady) root.lockReady = true
		} catch (e) {}
	}

	function showLock(label, on) {
		ShellState.osdType = "lock"
		ShellState.osdLabel = label
		ShellState.osdOn = on
		ShellState.osdScreen = ShellState.pointerScreen
		ShellState.osdVisible = true
		hideTimer.restart()
	}

	// ---- touchpad ----
	property bool touchpadReady: false
	property bool lastTouchpad: true

	Process {
		id: touchpadProc
		command: ["/bin/sh", "-c",
			"F=${XDG_RUNTIME_DIR:-/tmp}/touchpad.status; if [ -f \"$F\" ]; then cat \"$F\"; else echo true; fi"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.parseTouchpad(text)
		}
	}

	Timer {
		interval: 200
		running: true
		repeat: true
		onTriggered: touchpadProc.running = true
	}

	function parseTouchpad(raw) {
		const on = raw.trim().toLowerCase() !== "false"
		if (!root.touchpadReady) {
			root.touchpadReady = true
			root.lastTouchpad = on
			return
		}
		if (on !== root.lastTouchpad) {
			root.lastTouchpad = on
			ShellState.osdType = "touchpad"
			ShellState.osdLabel = "TOUCHPAD"
			ShellState.osdOn = on
			ShellState.osdScreen = ShellState.pointerScreen
			ShellState.osdVisible = true
			hideTimer.restart()
		}
	}

	// ---- volume ----
	property bool volReady: false
	property real lastVol: -1
	property bool lastMuted: false

	readonly property var sink: Pipewire.defaultAudioSink

	// Bindings so we react to both the sink appearing/switching and its
	// volume/mute changing (avoids manually connecting signal handlers).
	Binding {
		target: root
		property: "sinkVolume"
		value: root.sink && root.sink.audio ? root.sink.audio.volume : -1
	}
	Binding {
		target: root
		property: "sinkMuted"
		value: root.sink && root.sink.audio ? root.sink.audio.muted : false
	}
	property real sinkVolume: -1
	property bool sinkMuted: false
	onSinkVolumeChanged: root.checkVolume()
	onSinkMutedChanged: root.checkVolume()

	function checkVolume() {
		if (root.sinkVolume < 0) return
		if (!root.volReady) {
			root.volReady = true
			root.lastVol = root.sinkVolume
			root.lastMuted = root.sinkMuted
			return
		}
		if (root.sinkVolume !== root.lastVol || root.sinkMuted !== root.lastMuted) {
			root.lastVol = root.sinkVolume
			root.lastMuted = root.sinkMuted
			ShellState.osdType = "volume"
			ShellState.osdPercent = Math.round(root.sinkVolume * 100)
			ShellState.osdMuted = root.sinkMuted
			ShellState.osdScreen = ShellState.pointerScreen
			ShellState.osdVisible = true
			hideTimer.restart()
		}
	}

	// ---- brightness ----
	property bool brightReady: false
	property int lastBrightness: -1

	Process {
		id: brightProc
		command: ["/bin/sh", "-c", "B=/sys/class/backlight/*; printf '%s %s' \"$(cat $B/brightness)\" \"$(cat $B/max_brightness)\""]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.parseBrightness(text)
		}
	}

	Timer {
		interval: 300
		running: true
		repeat: true
		onTriggered: brightProc.running = true
	}

	function parseBrightness(raw) {
		try {
			const parts = raw.trim().split(/\s+/).map(Number)
			if (parts.length < 2 || isNaN(parts[0]) || isNaN(parts[1]) || parts[1] <= 0) return
			const percent = Math.round(100 * parts[0] / parts[1])
			if (!root.brightReady) {
				root.brightReady = true
				root.lastBrightness = percent
				return
			}
			if (percent !== root.lastBrightness) {
				root.lastBrightness = percent
				ShellState.osdType = "brightness"
				ShellState.osdPercent = percent
				ShellState.osdScreen = ShellState.pointerScreen
				ShellState.osdVisible = true
				hideTimer.restart()
			}
		} catch (e) {}
	}

	// ---- common ----
	Timer {
		id: hideTimer
		interval: 2000
		onTriggered: ShellState.osdVisible = false
	}
}