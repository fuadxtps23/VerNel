import QtQuick
import Quickshell

// clock - "{:%I:%M %p}" (e.g. 10:30 AM), rotated 90°. Left click opens the
// calendar popup.
Item {
	id: root

	width: Config.barWidth
	height: label.height

	property var screen: null
	property var host: null
	readonly property string time: Qt.formatDateTime(clock.date, "h:mm AP")

	SystemClock {
		id: clock
		precision: SystemClock.Seconds
	}

	HoverHighlight {
		anchors.fill: parent
		active: ma.containsMouse
		host: root.host
	}

	RotatedText {
		id: label
		anchors.centerIn: parent
		text: root.time
		color: Config.primary
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		onClicked: {
			if (ShellState.calendarOpen) ShellState.closeAll()
			else ShellState.openCalendar(root.screen)
		}
	}
}