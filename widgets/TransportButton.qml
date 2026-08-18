import QtQuick

// Round transport button (previous / play-pause / next).
Rectangle {
	id: root

	property string icon: "󰐊"
	signal clicked

	width: 56
	height: 36
	radius: 18
	color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground
	border.width: 1
	border.color: root.enabled ? Config.accent : "transparent"
	opacity: root.enabled ? 1 : 0.4

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Text {
		anchors.centerIn: parent
		text: root.icon
		color: Config.primary
		font { family: Config.fontFamily; pixelSize: 15; bold: true }
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		enabled: root.enabled
		onClicked: root.clicked()
	}
}