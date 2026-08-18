import QtQuick

// A device row in the audio controls popup: icon + name, highlighted when it
// is the active default device. Clicking selects it.
Rectangle {
	id: root

	property string name: ""
	property string icon: "󰓃"
	property bool active: false
	signal clicked

	width: parent ? parent.width : 0
	height: 26
	radius: 7
	color: ma.containsMouse
		? Config.cardBackgroundHover
		: (root.active ? Config.cardBackground : "transparent")

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	Text {
		text: root.icon
		color: root.active ? Config.activeWorkspace : Config.primary
		font { family: Config.fontFamily; pixelSize: 12 }
		anchors.verticalCenter: parent.verticalCenter
		anchors.left: parent.left
		anchors.leftMargin: 8
	}

	Text {
		text: root.name
		color: root.active ? Config.text : Config.secondary
		font { family: Config.fontFamily; pixelSize: 11; bold: root.active }
		elide: Text.ElideRight
		anchors.verticalCenter: parent.verticalCenter
		anchors.left: parent.left
		anchors.leftMargin: 28
		anchors.right: parent.right
		anchors.rightMargin: 8
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: root.clicked()
	}
}