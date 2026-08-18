import QtQuick

// Small square icon button used for month/year navigation in the calendar.
Rectangle {
	id: root

	required property string glyph
	required property var action

	width: 26
	height: 26
	radius: 8
	color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Text {
		anchors.centerIn: parent
		text: root.glyph
		color: Config.primary
		font { family: Config.fontFamily; pixelSize: 14; bold: true }
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		// Pass the click modifiers along so callers can react to shift, etc.
		onClicked: (mouse) => root.action(mouse.modifiers)
	}
}