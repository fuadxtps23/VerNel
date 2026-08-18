import QtQuick
import Quickshell
import Quickshell.Widgets

// Transient notification toasts. One host window per screen holds a stack of
// up to 3 cards; new notifications slide in at the bottom and older ones shift
// up as cards are dismissed. Only the host on the monitor the cursor is on is
// visible, and toasts hide while the notification center is open.
PanelWindow {
	id: root

	required property var modelData

	screen: root.modelData
	implicitWidth: 300
	implicitHeight: col.implicitHeight
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	aboveWindows: true

	anchors { top: true; right: true }
	margins {
		top: root.toastTop
		right: Config.barWidth + Config.barMarginRight + 8
	}

	// Sits below whichever panel is open (quick settings, audio controls or the
	// calendar), otherwise at the top under the bar. Animates so toasts slide
	// between positions.
	property real toastTop: ShellState.quickSettingsOpen
		&& ShellState.quickSettingsBottom > 0
		? ShellState.quickSettingsBottom + 8
		: ShellState.audioControlsOpen && ShellState.audioControlsBottom > 0
			? ShellState.audioControlsBottom + 8
			: ShellState.calendarOpen && ShellState.calendarBottom > 0
				? ShellState.calendarBottom + 8
				: Config.barMarginTop
	Behavior on toastTop {
		NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
	}

	property var entries: []

	visible: root.entries.length > 0
		&& !ShellState.notificationsOpen
		&& (ShellState.pointerScreen == null
			|| (root.modelData && ShellState.pointerScreen
				&& root.modelData.name === ShellState.pointerScreen.name))

	Component {
		id: cardComponent

		ToastCard {
			host: root
			width: 300
		}
	}

	// New notification arrives → add a card.
	Connections {
		target: ShellState
		function onLastNotificationChanged() {
			root.push(ShellState.lastNotification)
		}
		function onToastClearTickChanged() {
			// Clear button → slide every card out to the right.
			for (const e of root.entries) {
				if (e.card) e.card.dismiss()
			}
		}
	}

	// Cards are created dynamically (no Repeater) so adding a card never
	// re-creates the existing ones: the new card simply slides in below.
	function push(n) {
		if (!n) return
		for (const e of root.entries) {
			if (e.notification === n) return
		}
		if (root.entries.length >= 3) {
			const oldest = root.entries[0]
			if (oldest.card) oldest.card.dismiss()
		}
		const entry = { notification: n, time: Date.now() }
		root.entries = root.entries.concat([entry])
		const card = cardComponent.createObject(col, { entry: entry, notification: n })
		entry.card = card
	}

	function removeEntry(card) {
		const idx = root.entries.findIndex(e => e.card === card)
		if (idx >= 0) root.entries = root.entries.filter((_, i) => i !== idx)
		if (card) card.destroy()
	}

	Column {
		id: col
		width: parent.width
		spacing: 6
	}
}