import QtQuick

// Horizontal volume slider: drag or scroll to set a 0..1 value. `value` stays
// bound to the source while `dragValue` temporarily overrides it during a
// drag so the binding is never broken.
Item {
	id: root

	property real value: 0
	property real dragValue: -1
	signal changed(real value)

	readonly property real shownValue: root.dragValue >= 0 ? root.dragValue : root.value

	height: 22

	function clamp(v) {
		return Math.max(0, Math.min(1, v))
	}

	Rectangle {
		id: track
		anchors.verticalCenter: parent.verticalCenter
		height: 6
		width: parent.width
		radius: height / 2
		color: Config.cardBackgroundHover

		Rectangle {
			id: fill
			height: parent.height
			radius: height / 2
			color: Config.primary
			width: track.width * root.shownValue

			Behavior on width {
				NumberAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
			}
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onPressed: {
			root.dragValue = root.clamp(mouse.x / width)
			root.changed(root.dragValue)
		}
		onPositionChanged: {
			if (ma.pressed) {
				root.dragValue = root.clamp(mouse.x / width)
				root.changed(root.dragValue)
			}
		}
		onReleased: root.dragValue = -1
		onWheel: {
			const d = wheel.angleDelta.y > 0 ? 0.05 : -0.05
			root.changed(root.clamp(root.value + d))
		}
	}
}