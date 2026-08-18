import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

// Notification center popup: notifications grouped by app, a do-not-disturb
// toggle and a clear-all button. `server` is injected from shell.qml.
ShellPopup {
	id: root

	open: ShellState.notificationsOpen
	property var server: null

	// Clear animation: the list slides to the right and fades before the
	// history is actually emptied.
	property real listTransX: 0
	property real listFade: 1

	// ---- Header ----
	Row {
		width: parent.width
		spacing: 6

		Text {
			text: "Notifications"
			color: Config.text
			font {
				family: Config.fontFamily
				pixelSize: 14
				bold: true
			}
			verticalAlignment: Text.AlignVCenter
			width: parent.width - parent.spacing * 2 - 88
		}

		ToggleButton {
			checked: ShellState.dndEnabled
			onClicked: ShellState.dndEnabled = !ShellState.dndEnabled
		}

		ClearButton {
			onClicked: root.slideOutClear()
		}
	}

	// ---- List ----
	Flickable {
		width: parent.width
		height: Math.min(listColumn.implicitHeight, Config.popupMaxHeight)
		contentHeight: listColumn.implicitHeight
		clip: true
		interactive: contentHeight > height
		ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

		Column {
			id: listColumn
			width: parent.width
			spacing: 8
			transform: Translate { x: root.listTransX }
			opacity: root.listFade

			// Grouped by app
			Repeater {
				model: root.groups

				delegate: Item {
					required property var modelData
					width: listColumn.width
					height: groupCol.implicitHeight

					Column {
						id: groupCol
						width: parent.width
						spacing: 6

						Row {
							width: parent.width
							spacing: 6

							IconImage {
								width: 18
								height: 18
								source: modelData.appIcon
							}

							Text {
								text: modelData.appName
								color: Config.secondary
								font { family: Config.fontFamily; pixelSize: 12; bold: true }
								verticalAlignment: Text.AlignVCenter
								elide: Text.ElideRight
								width: parent.width - 18 - parent.spacing - 66
							}

							// Dismiss every notification from this app: slide the cards out to the
							// right first, then remove them.
							Item {
								width: 60
								height: 18

								Text {
									text: "× clear"
									color: Config.secondary
									font { family: Config.fontFamily; pixelSize: 10; bold: true }
									opacity: clearBtn.containsMouse ? 1 : 0.5
									anchors.centerIn: parent

									Behavior on opacity {
										NumberAnimation { duration: Config.animShort }
									}
								}

								MouseArea {
									id: clearBtn
									anchors.fill: parent
									hoverEnabled: true
									onClicked: {
										for (let i = 0; i < groupItemsRepeater.count; i++) {
											const card = groupItemsRepeater.itemAt(i)
											if (card) card.slideOut()
										}
									}
								}
							}
						}

						Repeater {
							id: groupItemsRepeater
							model: modelData.items

							delegate: NotificationCard {
								notification: modelData
								width: parent.width
							}
						}
					}
				}
			}

			Text {
				visible: root.groups.length === 0
				text: "No notifications"
				color: Config.accent
				font { family: Config.fontFamily; pixelSize: 12 }
				horizontalAlignment: Text.AlignHCenter
				width: parent.width
				padding: 20
			}
		}
	}

	// ---- helpers ----
	property var groups: root.buildGroups()

	function slideOutClear() {
		if (root.groups.length === 0) { ShellState.clearHistory(); return }
		clearAnim.restart()
	}

	ParallelAnimation {
		id: clearAnim
		running: false
		NumberAnimation { target: root; property: "listTransX"; to: 320; duration: Config.animMedium; easing.type: Easing.InCubic }
		NumberAnimation { target: root; property: "listFade"; to: 0; duration: Config.animMedium; easing.type: Easing.InCubic }
		onFinished: {
			ShellState.clearHistory()
			root.listTransX = 0
			root.listFade = 1
		}
	}

	function buildGroups() {
		const map = {}
		for (const h of ShellState.notificationHistory) {
			const key = h.appName || "Unknown"
			if (!map[key]) map[key] = { appName: key, appIcon: h.appIcon, items: [] }
			map[key].items.push(h)
		}
		return Object.values(map)
	}
}