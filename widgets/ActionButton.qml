import QtQuick

// A small pill action button for notification action rows (Pair, Accept,
// Open, Copy, ...). Hover brightens it.
Rectangle {
	id: root

	property string text: ""
	property string icon: ""
	signal clicked()
	readonly property bool hovered: ma.containsMouse

	height: 22
	implicitWidth: contentRow.implicitWidth + 20
	radius: 11
	color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground
	border { width: 1; color: Config.accent }

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Row {
		id: contentRow
		anchors.centerIn: parent
		spacing: 4

		Text {
			text: root.icon
			visible: root.icon.length > 0
			color: Config.text
			font { family: Config.fontFamily; pixelSize: 11 }
			verticalAlignment: Text.AlignVCenter
		}

		Text {
			text: root.text
			color: Config.text
			font { family: Config.fontFamily; pixelSize: 11 }
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: (mouse) => root.clicked()
	}
}