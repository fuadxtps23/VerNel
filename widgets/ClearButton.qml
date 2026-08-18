import QtQuick

// "Clear all" button used in the notification center header.
Rectangle {
	id: root

	signal clicked

	width: 42
	height: 30
	radius: 15
	color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground
	border.width: 1
	border.color: Config.accent

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Text {
		anchors.centerIn: parent
		text: "Clear"
		color: Config.text
		font { family: Config.fontFamily; pixelSize: 11; bold: true }
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: root.clicked()
	}
}