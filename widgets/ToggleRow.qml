import QtQuick

// A quick-settings row: leading icon, label (+ sublabel), trailing switch.
Item {
	id: root

	property string icon: "󰖩"
	property string label: ""
	property string sublabel: ""
	property bool checked: false
	property bool expandable: false
	property bool expanded: false
	property bool enabled: true
	signal toggled(bool checked)
	signal expandToggled(bool expanded)

	width: parent ? parent.width : 0
	height: 40

	// Whole-row click toggles the dropdown (when expandable). Declared FIRST
	// so it stays underneath the switch/chevron and never steals their clicks.
	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton
		onClicked: {
			if (root.enabled && root.expandable) root.expandToggled(!root.expanded)
		}
	}

	Rectangle {
		anchors.fill: parent
		radius: 10
		color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground

		Behavior on color {
			ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
		}
	}

	Text {
		text: root.icon
		color: Config.primary
		font { family: Config.fontFamily; pixelSize: 17 }
		anchors.verticalCenter: parent.verticalCenter
		anchors.left: parent.left
		anchors.leftMargin: 12
	}

	Column {
		anchors.verticalCenter: parent.verticalCenter
		anchors.left: parent.left
		anchors.leftMargin: 42
		spacing: 2

		Text {
			text: root.label
			color: Config.text
			font { family: Config.fontFamily; pixelSize: 13; bold: true }
			elide: Text.ElideRight
			width: root.width - 42 - 54
		}

		Text {
			text: root.sublabel
			color: Config.accent
			font { family: Config.fontFamily; pixelSize: 11 }
			elide: Text.ElideRight
			width: root.width - 42 - 54
			visible: root.sublabel.length > 0
		}
	}

	Switch {
		checked: root.checked
		enabled: root.enabled
		anchors.verticalCenter: parent.verticalCenter
		anchors.right: parent.right
		anchors.rightMargin: root.expandable ? 30 : 8
		onToggled: root.toggled(checked)
	}

	// Dropdown chevron shown when `expandable`; clicking it toggles the
	// collapsible section below the row.
	Item {
		width: 20
		height: 20
		visible: root.expandable
		anchors.verticalCenter: parent.verticalCenter
		anchors.right: parent.right
		anchors.rightMargin: 6

		Text {
			anchors.centerIn: parent
			text: "󰁔"
			color: root.expanded ? Config.activeWorkspace : Config.secondary
			rotation: root.expanded ? 90 : 0
			font { family: Config.fontFamily; pixelSize: 12; bold: true }
			Behavior on rotation {
				NumberAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
			}
			Behavior on color {
				ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
			}
		}

		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
			onClicked: {
				if (root.enabled) root.expandToggled(!root.expanded)
			}
		}
	}
}