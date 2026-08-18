import QtQuick

// A collapsible section header: chevron + label + current value. Clicking it
// emits `clicked` so the owner can expand/collapse the section below.
Rectangle {
	id: root

	property bool expanded: false
	property string label: ""
	property string sublabel: ""
	signal clicked

	width: parent ? parent.width : 0
	height: 30
	radius: 7
	color: ma.containsMouse ? Config.cardBackgroundHover : "transparent"

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Text {
		text: "󰁔"
		color: root.expanded ? Config.activeWorkspace : Config.secondary
		rotation: root.expanded ? 90 : 0
		font { family: Config.fontFamily; pixelSize: 11; bold: true }
		anchors.verticalCenter: parent.verticalCenter
		anchors.left: parent.left
		anchors.leftMargin: 8
		Behavior on rotation {
			NumberAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
		}
	}

	Text {
		text: root.label
		color: Config.accent
		font { family: Config.fontFamily; pixelSize: 10; bold: true }
		anchors.verticalCenter: parent.verticalCenter
		anchors.left: parent.left
		anchors.leftMargin: 24
	}

	Text {
		text: root.sublabel
		color: Config.secondary
		elide: Text.ElideRight
		font { family: Config.fontFamily; pixelSize: 11 }
		anchors.verticalCenter: parent.verticalCenter
		anchors.right: parent.right
		anchors.rightMargin: 8
		anchors.left: parent.left
		anchors.leftMargin: 60
		horizontalAlignment: Text.AlignRight
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: root.clicked()
	}
}