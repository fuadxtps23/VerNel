import QtQuick

// Small circular toggle used in popup headers (do-not-disturb).
Rectangle {
	id: root

	property bool checked: false
	signal clicked

	width: 30
	height: 30
	radius: width / 2
	color: ma.containsMouse
		? Config.cardBackgroundHover
		: (root.checked ? Config.toggleOn : Config.cardBackground)
	border.width: 1
	border.color: root.checked ? Config.toggleOn : Config.accent

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Text {
		anchors.centerIn: parent
		text: "󰂚"
		color: root.checked ? Config.background : Config.text
		font { family: Config.fontFamily; pixelSize: 13; bold: true }
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: {
			root.checked = !root.checked
			root.clicked()
		}
	}
}