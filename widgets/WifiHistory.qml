import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Saved-wifi manager that appears to the LEFT of the quick settings card.
// Lists every saved (known) wifi connection, lets you forget them or add a
// new SSID manually. Uses nmcli directly (NetworkManager fronts the user's
// iwd backend, and nmcli is the reliable way to enumerate saved profiles).
PanelWindow {
	id: root

	required property var modelData
	screen: root.modelData

	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	aboveWindows: true
	focusable: true

	width: Config.popupWidth

	// Positioned immediately left of the quick settings card.
	anchors { top: true; right: true }
	margins {
		top: Config.barMarginTop
		right: Config.barWidth + Config.barMarginRight + 8
			+ Config.popupWidth + 12
	}

	readonly property bool effectiveOpen: ShellState.wifiHistoryOpen
		&& ShellState.popupScreen != null
		&& root.modelData && ShellState.popupScreen
		&& root.modelData.name === ShellState.popupScreen.name

	// Decoupled from effectiveOpen so the card can animate out (upwards)
	// before the window actually unmaps.
	property bool shown: false
	visible: root.shown
	height: card.height

	property var savedNetworks: []
	property bool showAdd: false
	property int addSecurityIndex: 0
	property string addSsid: ""
	property string addPw: ""
	property bool addPwVisible: false
	property string addError: ""
	property string removingName: ""

	onEffectiveOpenChanged: {
		if (root.effectiveOpen) {
			root.refresh()
			root.shown = true
			card.y = -card.height - 12
			card.opacity = 0
			openAnim.restart()
			card.forceActiveFocus()
		} else if (root.shown) {
			closeAnim.restart()
		}
	}

	// Slides down from the top when opening, back up to the top on close.
	ParallelAnimation {
		id: openAnim
		NumberAnimation {
			target: card
			property: "y"
			to: 0
			duration: Config.animMedium
			easing.type: Easing.OutCubic
		}
		NumberAnimation {
			target: card
			property: "opacity"
			to: 1
			duration: Config.animMedium
			easing.type: Easing.OutCubic
		}
	}

	ParallelAnimation {
		id: closeAnim
		NumberAnimation {
			target: card
			property: "y"
			to: -card.height - 12
			duration: Config.animMedium
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: card
			property: "opacity"
			to: 0
			duration: Config.animMedium
			easing.type: Easing.InCubic
		}
		onStopped: root.shown = false
	}

	// ---- card ----
	Rectangle {
		id: card
		width: root.width
		height: body.implicitHeight + 24
		radius: Config.popupRadius
		color: Config.popupBackground
		border { width: Config.popupBorderWidth; color: Config.popupBorder }
		clip: true

		// ESC closes this widget (and only this one).
		Keys.onEscapePressed: ShellState.wifiHistoryOpen = false

		Column {
			id: body
			anchors { top: parent.top; left: parent.left; right: parent.right }
			anchors.margins: 12
			spacing: 8

			// Header
			Item {
				width: parent.width
				height: 20

				Text {
					text: "Saved Wi-Fi"
					color: Config.text
					font { family: Config.fontFamily; pixelSize: 13; bold: true }
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
				}

				Text {
					text: "󰅖"
					color: Config.secondary
					font { family: Config.fontFamily; pixelSize: 13 }
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						onClicked: ShellState.wifiHistoryOpen = false
					}
				}
			}

			// Add-SSID toggle
			Text {
				text: root.showAdd ? "󰁨 Cancel" : "󰐕 Add SSID"
				color: root.showAdd ? Config.secondary : Config.primary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						root.showAdd = !root.showAdd
						root.addError = ""
						if (root.showAdd) addFocusTimer.start()
					}
				}
			}

			// Add form
			Item {
				width: parent.width
				height: root.showAdd ? addForm.height : 0
				visible: root.showAdd

				Column {
					id: addForm
					width: parent.width
					spacing: 6

					TextField {
						id: addSsidField
						width: parent.width
						height: 24
						placeholderText: "SSID name"
						placeholderTextColor: Config.secondary
						color: Config.text
						font { family: Config.fontFamily; pixelSize: 11 }
						selectByMouse: true
						background: Rectangle {
							radius: 5
							color: Config.cardBackgroundHover
							border.width: 1
							border.color: Config.toggleOff
						}
						onTextChanged: root.addSsid = text
					}

					ComboBox {
						id: secCombo
						width: parent.width
						height: 26
						model: ["Open", "WPA/WPA2"]
						currentIndex: root.addSecurityIndex
						onActivated: root.addSecurityIndex = currentIndex
						font { family: Config.fontFamily; pixelSize: 11 }
						background: Rectangle {
							radius: 5
							color: Config.cardBackgroundHover
							border.width: 1
							border.color: Config.toggleOff
						}
						contentItem: Text {
							text: secCombo.displayText
							color: Config.text
							font: secCombo.font
							leftPadding: 8
							verticalAlignment: Text.AlignVCenter
						}
						indicator: Text {
							text: "󰄉"
							color: Config.secondary
							font { family: Config.fontFamily; pixelSize: 10 }
							anchors.right: parent.right
							anchors.rightMargin: 6
							anchors.verticalCenter: parent.verticalCenter
						}
						delegate: ItemDelegate {
							width: secCombo.width
							height: 24
							background: Rectangle {
								color: highlighted ? Config.cardBackgroundHover : Config.background
							}
							contentItem: Text {
								text: modelData
								color: Config.text
								font: secCombo.font
								leftPadding: 8
								verticalAlignment: Text.AlignVCenter
							}
						}
						popup: Popup {
							y: secCombo.height + 2
							width: secCombo.width
							implicitHeight: contentItem.implicitHeight
							padding: 0
							background: Rectangle {
								color: Config.background
								radius: 6
								border.width: 1
								border.color: Config.toggleOff
							}
							contentItem: ListView {
								clip: true
								implicitHeight: contentHeight
								model: secCombo.popup.visible ? secCombo.delegateModel : null
								currentIndex: secCombo.highlightedIndex
							}
						}
					}

					// Password field + eye toggle (hidden for open networks)
					Item {
						width: parent.width
						height: 24
						visible: root.addSecurityIndex !== 0

						TextField {
							id: addPwField
							height: 24
							anchors.left: parent.left
							anchors.right: addPwEye.left
							anchors.rightMargin: 4
							placeholderText: "Password"
							placeholderTextColor: Config.secondary
							color: Config.text
							font { family: Config.fontFamily; pixelSize: 11 }
							selectByMouse: true
							echoMode: root.addPwVisible ? TextInput.Normal : TextInput.Password
							background: Rectangle {
								radius: 5
								color: Config.cardBackgroundHover
								border.width: 1
								border.color: Config.toggleOff
							}
							onTextChanged: root.addPw = text
						}

						Text {
							id: addPwEye
							text: root.addPwVisible ? "󰏿" : "󰏾"
							color: Config.secondary
							font { family: Config.fontFamily; pixelSize: 12 }
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							MouseArea {
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: root.addPwVisible = !root.addPwVisible
							}
						}
					}

					Text {
						width: parent.width
						text: root.addError
						color: Config.critical
						font { family: Config.fontFamily; pixelSize: 11 }
						visible: root.addError.length > 0
					}

					Row {
						width: parent.width
						spacing: 12

						Text {
							text: "Add"
							color: Config.primary
							font { family: Config.fontFamily; pixelSize: 11; bold: true }
							MouseArea {
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: root.doAdd()
							}
						}

						Text {
							text: "Cancel"
							color: Config.secondary
							font { family: Config.fontFamily; pixelSize: 11 }
							MouseArea {
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: {
									root.showAdd = false
									root.addError = ""
								}
							}
						}
					}
				}
			}

			// Separator
			Rectangle {
				width: parent.width
				height: 1
				color: Config.toggleOff
			}

			Text {
				text: `${root.savedNetworks.length} saved network${root.savedNetworks.length === 1 ? "" : "s"}`
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
			}

			// Saved network list
			Flickable {
				width: parent.width
				height: Math.min(listCol.implicitHeight, 190)
				contentHeight: listCol.implicitHeight
				clip: true
				interactive: contentHeight > height

				Column {
					id: listCol
					width: parent.width
					spacing: 4

					Repeater {
						model: root.savedNetworks

delegate: Item {
						id: brow
						required property string modelData
						width: listCol.width
						height: 26

						Rectangle {
							anchors.fill: parent
							radius: 7
							color: hma.containsMouse ? Config.cardBackgroundHover : "transparent"
							Behavior on color {
								ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
							}
						}

						Text {
							text: "󰖩"
							color: Config.primary
							font { family: Config.fontFamily; pixelSize: 12 }
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 10
						}

						Text {
							text: modelData
							color: Config.text
							font { family: Config.fontFamily; pixelSize: 12 }
							elide: Text.ElideRight
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 30
							anchors.right: parent.right
							anchors.rightMargin: 62
						}

						// Must stack above hma (full-row hover) or it eats the click.
						Text {
							z: 2
							text: "Forget"
							color: Config.critical
							font { family: Config.fontFamily; pixelSize: 11; bold: true }
							anchors.verticalCenter: parent.verticalCenter
							anchors.right: parent.right
							anchors.rightMargin: 10
							MouseArea {
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: Qt.PointingHandCursor
								onClicked: {
									if (root.removeNetwork(modelData))
										removeAnim.restart()
								}
							}
						}

						MouseArea {
							id: hma
							anchors.fill: parent
							hoverEnabled: true
						}

						// Slide the row left + collapse, then delete + refresh.
						ParallelAnimation {
							id: removeAnim
							NumberAnimation {
								target: brow
								property: "x"
								to: -(brow.width + 24)
								duration: Config.animMedium
								easing.type: Easing.OutCubic
							}
							NumberAnimation {
								target: brow
								property: "opacity"
								to: 0
								duration: Config.animMedium
								easing.type: Easing.OutCubic
							}
							NumberAnimation {
								target: brow
								property: "height"
								to: 0
								duration: Config.animMedium
								easing.type: Easing.OutCubic
							}
							onStopped: root.finishForget()
						}
					}
					}
				}
			}

			Text {
				width: parent.width
				text: "No saved networks"
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11 }
				horizontalAlignment: Text.AlignHCenter
				visible: root.savedNetworks.length === 0
			}
		}
	}

	// ---- data ----
	Process {
		id: listProc
		command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
		running: false
		stdout: StdioCollector {
			onStreamFinished: root.parseSaved(text)
		}
	}

	function parseSaved(raw) {
		const out = []
		for (const line of raw.split("\n")) {
			if (!line) continue
			const i = line.lastIndexOf(":")
			if (i <= 0) continue
			const name = line.slice(0, i)
			const type = line.slice(i + 1)
			if (type === "802-11-wireless" || type === "wifi") out.push(name)
		}
		root.savedNetworks = out
	}

	function refresh() {
		listProc.running = true
	}

	// Shell-quote for single quotes.
	function shq(s) {
		return "'" + s.replace(/'/g, "'\\''") + "'"
	}

	// Returns false if another removal is already in progress.
	function removeNetwork(netname) {
		if (root.removingName) return false
		root.removingName = netname
		return true
	}

	function finishForget() {
		const name = root.removingName
		if (!name) return
		root.removingName = ""
		Quickshell.execDetached(["/bin/sh", "-c",
			`nmcli connection delete ${root.shq(name)}`])
		refreshDelay.start()
	}

	function doAdd() {
		const ssid = root.addSsid.trim()
		if (!ssid) { root.addError = "Enter an SSID"; return }
		let cmd = `nmcli connection add type wifi con-name ${root.shq(ssid)} ssid ${root.shq(ssid)}`
		if (root.addSecurityIndex !== 0) {
			const pw = root.addPw
			if (!pw) { root.addError = "Enter a password"; return }
			cmd += ` wifi-sec.key-mgmt wpa-psk wifi-sec.psk ${root.shq(pw)}`
		}
		Quickshell.execDetached(["/bin/sh", "-c", cmd])
		root.addError = ""
		root.showAdd = false
		root.addSsid = ""
		root.addPw = ""
		root.addSecurityIndex = 0
		// Give nmcli a moment before re-listing.
		refreshDelay.start()
	}

	Timer {
		id: refreshDelay
		interval: 800
		onTriggered: root.refresh()
	}

	Timer {
		id: addFocusTimer
		interval: 120
		onTriggered: addSsidField.forceActiveFocus()
	}
}