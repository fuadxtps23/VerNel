import QtQuick
import Quickshell

// Calendar popup: month grid with the full current day/date/month/year, plus
// navigation across months and years. Opens by clicking the clock.
ShellPopup {
	id: root

	open: ShellState.calendarOpen

	// Keep the toast host below this card too (same as quick settings /
	// audio controls), so toasts never overlap the panel.
	Binding {
		target: ShellState
		property: "calendarBottom"
		value: root.cardBottom
	}

	// Shown month (0-11) and year, reset to today whenever the panel opens.
	property int year: 0
	property int month: 0

	readonly property var today: {
		const d = new Date()
		return { year: d.getFullYear(), month: d.getMonth(), day: d.getDate() }
	}

	readonly property int firstWeekday: new Date(root.year, root.month, 1).getDay()
	readonly property int daysInMonth: new Date(root.year, root.month + 1, 0).getDate()
	readonly property int daysInPrev: new Date(root.year, root.month, 0).getDate()

	// 42-cell grid (6 weeks) so the card height never jumps between months.
	readonly property string monthLabel: {
		const names = ["January", "February", "March", "April", "May", "June",
			"July", "August", "September", "October", "November", "December"]
		return `${names[root.month]} ${root.year}`
	}

	readonly property string todayLabel:
		"Today · " + Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")

	onOpenChanged: {
		if (root.open) {
			const d = new Date()
			root.year = d.getFullYear()
			root.month = d.getMonth()
		}
	}

	function cellDay(i) {
		const d = i - root.firstWeekday + 1
		if (d >= 1 && d <= root.daysInMonth) return d
		if (d < 1) return root.daysInPrev + d
		return d - root.daysInMonth
	}

	function inMonth(i) {
		const d = i - root.firstWeekday + 1
		return d >= 1 && d <= root.daysInMonth
	}

	function isToday(i) {
		return root.inMonth(i)
			&& root.month === root.today.month
			&& root.year === root.today.year
			&& root.cellDay(i) === root.today.day
	}

	function prevMonth() {
		root.month--
		if (root.month < 0) { root.month = 11; root.year-- }
	}
	function nextMonth() {
		root.month++
		if (root.month > 11) { root.month = 0; root.year++ }
	}
	function prevYear() { root.year-- }
	function nextYear() { root.year++ }

	// ---- Header: month/year label with month+year navigation ----
	Item {
		width: parent.width
		height: 26

		Row {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			spacing: 4
			NavButton { glyph: "«"; action: root.prevYear }
			NavButton { glyph: "‹"; action: root.prevMonth }
		}

		Row {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: 4
			NavButton { glyph: "›"; action: root.nextMonth }
			NavButton { glyph: "»"; action: root.nextYear }
		}

		Text {
			anchors.centerIn: parent
			text: root.monthLabel
			color: Config.text
			font { family: Config.fontFamily; pixelSize: 14; bold: true }
		}
	}

	// ---- Sub-line: full today's date ----
	Text {
		width: parent.width
		text: root.todayLabel
		color: Config.secondary
		font { family: Config.fontFamily; pixelSize: 11 }
		horizontalAlignment: Text.AlignHCenter
	}

	// ---- Weekday header ----
	Grid {
		id: weekdayRow
		width: parent.width
		columns: 7
		spacing: 2

		Repeater {
			model: ["S", "M", "T", "W", "T", "F", "S"]

			delegate: Text {
				required property string modelData
				width: root.cellW
				height: 18
				text: modelData
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter
			}
		}
	}

	// ---- Day grid (6x7) ----
	Grid {
		id: grid
		width: parent.width
		columns: 7
		spacing: 2

		Repeater {
			model: 42

			delegate: Rectangle {
				required property int index
				width: root.cellW
				height: 30
				radius: 15
				color: root.isToday(index) ? Config.accent : "transparent"

				Text {
					anchors.centerIn: parent
					text: root.cellDay(index)
					color: root.isToday(index)
						? Config.background
						: root.inMonth(index)
							? Config.text
							: Config.withAlpha(Config.secondary, 0.45)
					font { family: Config.fontFamily; pixelSize: 12 }
				}
			}
		}
	}

	// Per-column width that accounts for the grid's column spacing so the 7
	// columns exactly fill the card width.
	readonly property real cellW: (grid.width - grid.spacing * (7 - 1)) / 7
}