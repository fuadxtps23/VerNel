import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// custom/swaync - notification bell backed by quickshell's native
// NotificationServer (no swaync). Left click opens the notification center,
// right click toggles do-not-disturb. `server` is injected from shell.qml.
Item {
	id: root

	width: Config.barWidth
	// Tighter than Config.iconHeight: the bell glyph carries a lot of
	// font-internal vertical whitespace, so a 20px box left too much empty
	// space above and below the icon.
	height: 15

	property var server: null
	property var screen: null
	property var host: null

	readonly property int notificationCount: ShellState.notificationHistory.length
	readonly property bool hasNotifications: root.notificationCount > 0

	readonly property string icon: {
		if (ShellState.dndEnabled)
			return root.hasNotifications ? "" : ""
		return root.hasNotifications ? "" : ""
	}

	HoverHighlight {
		anchors.fill: parent
		active: ma.containsMouse
		host: root.host
	}

	Text {
		anchors.centerIn: parent
		text: root.icon
		color: ShellState.dndEnabled ? Config.accent : Config.primary
		font {
			family: Config.fontFamily
			pixelSize: 13
			bold: true
		}
		Behavior on color {
			ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
		}
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		onClicked: {
			if (mouse.button === Qt.RightButton)
				ShellState.dndEnabled = !ShellState.dndEnabled
			else if (ShellState.notificationsOpen)
				ShellState.closeAll()
			else
				ShellState.openNotifications(root.screen)
		}
	}
}