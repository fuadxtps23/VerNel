import QtQuick

// A square quick-action button used in the quick settings grid.
Rectangle {
	id: root

	property string icon: "󰐥"
	property string label: ""
	signal clicked

	width: (parent.width - parent.spacing * 2) / 3
	height: 56
	radius: 12
	color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground
	border.width: 1
	border.color: ma.containsMouse ? Config.accent : "transparent"

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Column {
		anchors.centerIn: parent
		spacing: 4

		Text {
			text: root.icon
			color: Config.primary
			font { family: Config.fontFamily; pixelSize: 18 }
			anchors.horizontalCenter: parent.horizontalCenter
		}

		Text {
			text: root.label
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 10 }
			anchors.horizontalCenter: parent.horizontalCenter
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: root.clicked()
	}
}