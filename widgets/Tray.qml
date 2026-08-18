import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// tray - vertically stacked system tray icons (icon-size 20, spacing 4).
// Left click activates (or opens the menu for `onlyMenu` items like Discord),
// middle click secondary-activates, right click opens the item's context menu
// via QsMenuAnchor (anchored to the icon so it appears to the left of the bar).
Item {
	id: root

	width: Config.barWidth
	height: Math.max(1, column.implicitHeight)

	Column {
		id: column
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: 4

		Repeater {
			model: SystemTray.items

			delegate: Item {
				id: item
				required property var modelData
				width: 20
				height: 20

				IconImage {
					anchors.centerIn: parent
					implicitSize: 20
					source: modelData.icon
				}

				// Hosts the item's DBus context menu. Anchored to this icon so
				// the menu opens just left of the bar, top-aligned with it.
				QsMenuAnchor {
					id: menuAnchor
					menu: modelData.menu
					anchor {
						item: item
						edges: Edges.Top | Edges.Left
						gravity: Edges.Bottom | Edges.Left
						margins.left: 6
					}
				}

				MouseArea {
					anchors.fill: parent
					acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
					onClicked: (mouse) => {
						if (mouse.button === Qt.RightButton) {
							if (modelData.hasMenu) {
								menuAnchor.anchor.updateAnchor()
								menuAnchor.open()
							}
						} else if (mouse.button === Qt.MiddleButton) {
							modelData.secondaryActivate()
						} else if (modelData.onlyMenu && modelData.hasMenu) {
							menuAnchor.anchor.updateAnchor()
							menuAnchor.open()
						} else {
							modelData.activate()
						}
					}
				}
			}
		}
	}
}
