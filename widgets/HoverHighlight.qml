import QtQuick

// Hover tracker for the bar's shared "morphing" highlight. It is invisible
// itself; when the module is hovered it reports its rect (within the bar
// host) to ShellState.barHover, and the single highlight rectangle in the
// bar animates between modules.
//
// The owning instance is stored in ShellState.barHoverTracker (a direct
// QObject reference, which survives property-var copying). Clearing is
// delayed by `clearDelay` so moving between modules (or away briefly) keeps
// the highlight visible while the cursor travels; the highlight then fades
// out from the last held position instead of collapsing.
Rectangle {
	id: root

	property bool active: false
	property Item host: null
	property int clearDelay: 100

	radius: 5
	color: Config.cardBackgroundHover
	visible: false

	function targetRect() {
		if (!root.host) return null
		const p = root.mapToItem(root.host, 0, 0)
		if (p === undefined || p === null) return null
		return { y: p.y, height: root.height }
	}

	onActiveChanged: {
		if (root.active) {
			clearTimer.stop()
			const r = root.targetRect()
			if (r) {
				ShellState.barHover = r
				ShellState.barHoverTracker = root
			}
		} else {
			clearTimer.restart()
		}
	}

	Timer {
		id: clearTimer
		interval: root.clearDelay
		onTriggered: {
			if (!root.active && ShellState.barHoverTracker === root) {
				ShellState.barHover = null
				ShellState.barHoverTracker = null
			}
		}
	}
}