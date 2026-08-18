import QtQuick

// Animated macOS-style switch.
Item {
	id: root

	property bool checked: false
	signal toggled(bool checked)

	width: 42
	height: 24

	Rectangle {
		id: track
		anchors.fill: parent
		radius: height / 2
		color: root.checked ? Config.toggleOn : Config.toggleOff

		Behavior on color {
			ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
		}

		Rectangle {
			id: knob
			width: parent.height - 4
			height: parent.height - 4
			radius: width / 2
			color: "#ffffff"
			x: root.checked ? parent.width - width - 2 : 2
			y: 2

			Behavior on x {
				NumberAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
			}
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		onClicked: {
			root.checked = !root.checked
			root.toggled(root.checked)
		}
	}
}