import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

// macOS-style quick settings: network, bluetooth, ethernet, night light and
// the control buttons previously in the swaync panel (power/lock/etc).
// Each row has a chevron that expands its details section below it.
ShellPopup {
	id: root

	open: ShellState.quickSettingsOpen

	// Keep the toast host in sync with the card's bottom edge so toasts can
	// slide below the panel while it's open.
	Binding {
		target: ShellState
		property: "quickSettingsBottom"
		value: root.cardBottom
	}

	// ESC closes the panel from anywhere inside it (keyboard focus is granted
	// on open; the wifi password field bubbles the key up to the card).
	Keys.onEscapePressed: ShellState.closeAll()

	property bool wifiExpanded: false
	property bool bluetoothExpanded: false
	property bool ethernetExpanded: false
	property bool nightlightExpanded: false
	property int nightTemp: 5300
	property bool nightlightOn: false

	// ---- Network ----
	ToggleRow {
		icon: "󰖩"
		label: "Wi-Fi"
		sublabel: {
			if (!root.wifiEnabled) return "Off"
			return root.wifiSsid ? root.wifiSsid : "Not connected"
		}
		checked: root.wifiEnabled
		expandable: true
		expanded: root.wifiExpanded
		onToggled: {
			Networking.wifiEnabled = checked
			if (!checked) {
				root.wifiPromptSsid = ""
				root.wifiError = ""
				root.wifiConnecting = null
			} else {
				root.refreshWifi()
			}
		}
		onExpandToggled: root.wifiExpanded = expanded
	}

	ExpandableSection {
		expanded: root.wifiExpanded
		enabled: root.wifiEnabled

		// Section header: title + history (saved networks) + manual scan.
		Item {
			width: parent.width
			height: 18

			Text {
				text: "Available networks"
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				anchors.left: parent.left
				anchors.leftMargin: 4
				anchors.verticalCenter: parent.verticalCenter
			}

			Row {
				anchors.right: parent.right
				anchors.rightMargin: 4
				anchors.verticalCenter: parent.verticalCenter
				spacing: 12

				Text {
					text: "󰅂"
					color: ShellState.wifiHistoryOpen ? Config.activeWorkspace : Config.primary
					font { family: Config.fontFamily; pixelSize: 12 }
					rotation: ShellState.wifiHistoryOpen ? 180 : 0
					transformOrigin: Item.Center
					Behavior on rotation {
						NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
					}
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						onClicked: ShellState.wifiHistoryOpen = !ShellState.wifiHistoryOpen
					}
				}

				Text {
					text: "󰑐"
					color: root.wifiConnecting ? Config.secondary : Config.primary
					font { family: Config.fontFamily; pixelSize: 12 }
					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						onClicked: root.refreshWifi(true)
					}
				}
			}
		}

		Flickable {
			width: parent.width
			height: Math.min(wifiList.implicitHeight, 110)
			contentHeight: wifiList.implicitHeight
			clip: true
			interactive: contentHeight > height

			Column {
				id: wifiList
				width: parent.width
				spacing: 4

				Repeater {
					model: root.wifiNetworks

					delegate: Item {
						required property var modelData
						id: wrow
						width: wifiList.width
						height: 28

						readonly property bool isConnecting: root.wifiConnecting === modelData

						Rectangle {
							anchors.fill: parent
							radius: 7
							color: wma.containsMouse ? Config.cardBackgroundHover : "transparent"

							Behavior on color {
								ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
							}
						}

						Text {
							text: root.signalIcon(modelData.signalStrength)
							color: modelData.connected ? Config.activeWorkspace : Config.primary
							font { family: Config.fontFamily; pixelSize: 12 }
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 10
						}

						Text {
							text: modelData.name
							color: modelData.connected ? Config.activeWorkspace : Config.text
							font { family: Config.fontFamily; pixelSize: 12; bold: modelData.connected }
							elide: Text.ElideRight
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 28
							anchors.right: parent.right
							anchors.rightMargin: 84
						}

						// Right-side action button. Needs to stack above the
						// full-row wma MouseArea or it swallows the click.
						Text {
							z: 2
							text: wrow.isConnecting ? "Connecting…"
								: modelData.connected ? "Disconnect" : "Connect"
							color: modelData.connected ? Config.critical
								: wrow.isConnecting ? Config.secondary : Config.primary
							font { family: Config.fontFamily; pixelSize: 11; bold: !wrow.isConnecting }
							elide: Text.ElideRight
							anchors.verticalCenter: parent.verticalCenter
							anchors.right: parent.right
							anchors.rightMargin: 8
							width: 72
							horizontalAlignment: Text.AlignRight

							MouseArea {
								anchors.fill: parent
								hoverEnabled: true
								cursorShape: wrow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
								onClicked: {
									if (wrow.isConnecting) return
									if (modelData.connected) root.disconnectWifi(modelData)
									else root.connectWifi(modelData)
								}
							}
						}

						MouseArea {
							id: wma
							anchors.fill: parent
							hoverEnabled: true
							onClicked: root.connectWifi(modelData)
						}
					}
				}
			}
		}

		// Inline password prompt for networks that need one.
		Item {
			id: wifiPrompt
			width: parent.width
			height: 30
			visible: root.wifiPromptSsid.length > 0

			// Give the field keyboard focus the moment the prompt shows, so
			// typing goes into it instead of the focused app/window.
			onVisibleChanged: {
				if (visible) {
					root.focusPrompt()
				}
			}

			Rectangle {
				anchors.fill: parent
				radius: 7
				color: Config.cardBackground
			}

			TextField {
				id: wifiPw
				height: 22
				anchors.left: parent.left
				anchors.leftMargin: 8
				anchors.right: wifiPwEye.left
				anchors.rightMargin: 4
				anchors.verticalCenter: parent.verticalCenter
				echoMode: root.pwVisible ? TextInput.Normal : TextInput.Password
				placeholderText: root.wifiPromptSsid
					? `Password for ${root.wifiPromptSsid}` : ""
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
				onAccepted: root.doWifiConnect(wifiPw.text)
			}

			Text {
				id: wifiPwEye
				text: root.pwVisible ? "󰏿" : "󰏾"
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 12 }
				anchors.right: wifiPwConnect.left
				anchors.rightMargin: 6
				anchors.verticalCenter: parent.verticalCenter
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: root.pwVisible = !root.pwVisible
				}
			}

			Text {
				id: wifiPwConnect
				text: "Connect"
				color: Config.primary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				anchors.verticalCenter: parent.verticalCenter
				anchors.right: wifiPwCancel.left
				anchors.rightMargin: 8
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: root.doWifiConnect(wifiPw.text)
				}
			}

			Text {
				id: wifiPwCancel
				text: "Cancel"
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11 }
				anchors.verticalCenter: parent.verticalCenter
				anchors.right: parent.right
				anchors.rightMargin: 8
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						root.wifiPromptSsid = ""
						root.wifiError = ""
					}
				}
			}
		}

		// Wrong-password / connection-failure warning.
		Text {
			width: parent.width
			text: root.wifiError
			color: Config.critical
			font { family: Config.fontFamily; pixelSize: 11 }
			wrapMode: Text.WordWrap
			horizontalAlignment: Text.AlignHCenter
			padding: 4
			visible: root.wifiError.length > 0
		}
	}

	// ---- Ethernet ----
	ToggleRow {
		icon: "󰈀"
		label: "Ethernet"
		sublabel: root.ethernetConnected
			? (root.ethernetIpv4 || "Connected") : "Disconnected"
		checked: root.ethernetConnected
		enabled: root.ethernetConnected
		opacity: root.ethernetConnected ? 1 : 0.45
		expandable: true
		expanded: root.ethernetExpanded
		onExpandToggled: root.ethernetExpanded = expanded
	}

	ExpandableSection {
		expanded: root.ethernetExpanded

		Repeater {
			model: root.wiredDevices

			delegate: Item {
				required property var modelData
				width: parent.width
				height: 44

				Text {
					text: modelData.connected ? "󰛳" : "󰛲"
					color: modelData.connected ? Config.activeWorkspace : Config.accent
					font { family: Config.fontFamily; pixelSize: 12 }
					anchors.verticalCenter: parent.verticalCenter
					anchors.left: parent.left
					anchors.leftMargin: 14
				}

				Text {
					text: modelData.name || "Ethernet"
					color: modelData.connected ? Config.text : Config.accent
					font { family: Config.fontFamily; pixelSize: 12; bold: modelData.connected }
					elide: Text.ElideRight
					anchors.verticalCenter: parent.verticalCenter
					anchors.left: parent.left
					anchors.leftMargin: 34
					anchors.right: parent.right
					anchors.rightMargin: 150
				}

				// MAC address on the right, IPv4 directly underneath it.
				Text {
					id: ethMac
					text: modelData.address || "—"
					color: Config.secondary
					font { family: Config.fontFamily; pixelSize: 11 }
					elide: Text.ElideRight
					anchors.right: parent.right
					anchors.top: parent.top
					anchors.topMargin: 8
					anchors.rightMargin: 10
				}

				Text {
					text: modelData.connected
						? (root.ethernetIpv4 || "No IP") : "Disconnected"
					color: Config.secondary
					font { family: Config.fontFamily; pixelSize: 11 }
					elide: Text.ElideRight
					anchors.right: parent.right
					anchors.top: ethMac.bottom
					anchors.topMargin: 2
					anchors.rightMargin: 10
				}
			}
		}

		Text {
			text: "No wired connection"
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 11 }
			width: parent.width
			padding: 6
			visible: root.wiredDevices.length === 0
		}
	}

	// ---- Bluetooth ----
	ToggleRow {
		icon: "󰂯"
		label: "Bluetooth"
		sublabel: root.bluetoothBlocked
			? "Blocked"
			: (root.bluetoothOn
				? (root.btInRange.length > 0
					? `${root.btInRange.length} device${root.btInRange.length === 1 ? "" : "s"}`
					: (root.btScanning ? "Scanning…" : "No devices"))
				: "Off")
		checked: root.bluetoothOn
		expandable: true
		expanded: root.bluetoothExpanded
		onToggled: {
			if (Bluetooth.defaultAdapter)
				Bluetooth.defaultAdapter.enabled = checked
			if (checked) {
				btPollTimer.start()
				// Delay the first scan so BlueZ's auto-reconnect to the last
				// device can settle (scanning during it makes the link drop).
				btScanDelay.start()
			} else {
				root.stopBtScan()
			}
		}
		onExpandToggled: root.bluetoothExpanded = expanded
	}

	ExpandableSection {
		expanded: root.bluetoothExpanded
		enabled: root.bluetoothOn

		// Section header: title + rescan button.
		Item {
			width: parent.width
			height: 18

			Text {
				text: "Nearby devices"
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				anchors.left: parent.left
				anchors.leftMargin: 4
				anchors.verticalCenter: parent.verticalCenter
			}

			Text {
				text: "󰑐"
				color: root.btConnecting ? Config.secondary : Config.primary
				font { family: Config.fontFamily; pixelSize: 12 }
				anchors.right: parent.right
				anchors.rightMargin: 4
				anchors.verticalCenter: parent.verticalCenter
				MouseArea {
					anchors.fill: parent
					hoverEnabled: true
					onClicked: root.refreshBluetooth()
				}
			}
		}

		Flickable {
			width: parent.width
			height: Math.min(btList.implicitHeight, 110)
			contentHeight: btList.implicitHeight
			clip: true
			interactive: contentHeight > height

			Column {
				id: btList
				width: parent.width
				spacing: 4

				Repeater {
					model: root.btInRange

					delegate: Item {
						required property var modelData
						id: brow
						width: btList.width
						height: 28

						readonly property bool isConnecting: root.btConnecting === modelData

						Rectangle {
							anchors.fill: parent
							radius: 7
							color: bma.containsMouse ? Config.cardBackgroundHover : "transparent"

							Behavior on color {
								ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
							}
						}

						Text {
							text: modelData.connected ? "󰂱" : "󰂯"
							color: modelData.connected ? Config.activeWorkspace : Config.primary
							font { family: Config.fontFamily; pixelSize: 12 }
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 10
						}

						Text {
							text: modelData.name || modelData.deviceName || modelData.address
							color: modelData.connected ? Config.activeWorkspace : Config.text
							font { family: Config.fontFamily; pixelSize: 12; bold: modelData.connected }
							elide: Text.ElideRight
							anchors.verticalCenter: parent.verticalCenter
							anchors.left: parent.left
							anchors.leftMargin: 28
							anchors.right: parent.right
							anchors.rightMargin: 116
						}

						// Right-side action button.
						Row {
							anchors.right: parent.right
							anchors.rightMargin: 8
							anchors.verticalCenter: parent.verticalCenter
							spacing: 8

							Text {
								text: `${Math.round(modelData.battery)}%`
								color: Config.secondary
								font { family: Config.fontFamily; pixelSize: 11; bold: true }
								visible: modelData.connected && modelData.batteryAvailable
							}

							Text {
								text: brow.isConnecting
									? (modelData.bonded ? "Connecting…" : "Pairing…")
									: modelData.connected ? "Disconnect"
									: modelData.bonded || modelData.paired ? "Connect" : "Pair"
								color: modelData.connected ? Config.critical
									: brow.isConnecting ? Config.secondary : Config.primary
								font { family: Config.fontFamily; pixelSize: 11; bold: !brow.isConnecting }
								elide: Text.ElideRight
								horizontalAlignment: Text.AlignRight

								MouseArea {
									anchors.fill: parent
									hoverEnabled: true
									cursorShape: brow.isConnecting ? Qt.ArrowCursor : Qt.PointingHandCursor
									onClicked: root.btAction(modelData)
								}
							}
						}

						MouseArea {
							id: bma
							anchors.fill: parent
							hoverEnabled: true
							onClicked: root.btAction(modelData)
						}
					}
				}
			}
		}

		Text {
			width: parent.width
			text: root.btScanning ? "Scanning…" : "No devices nearby"
			color: Config.secondary
			font { family: Config.fontFamily; pixelSize: 11 }
			horizontalAlignment: Text.AlignHCenter
			padding: 6
			visible: root.btInRange.length === 0
		}
	}

	// ---- Night light ----
	ToggleRow {
		icon: ""
		label: "Night Light"
		sublabel: root.nightlightOn ? `${root.nightTemp}K` : "Off"
		checked: root.nightlightOn
		expandable: true
		expanded: root.nightlightExpanded
		onToggled: {
			// Optimistic: flip the switch state immediately so the row/slider
			// respond instantly; the pgrep re-check on next open confirms it.
			root.nightlightOn = checked
			if (checked) root.startNightlight()
			else root.stopNightlight()
		}
		onExpandToggled: root.nightlightExpanded = expanded
	}

	ExpandableSection {
		expanded: root.nightlightExpanded

		Row {
			width: parent.width
			spacing: 6

			Text {
				text: "Temperature"
				color: Config.secondary
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				width: parent.width / 2
			}

			Text {
				text: `${root.nightTemp}K`
				color: Config.activeWorkspace
				font { family: Config.fontFamily; pixelSize: 11; bold: true }
				horizontalAlignment: Text.AlignRight
				width: parent.width / 2
			}
		}

		VolumeSlider {
			width: parent.width
			value: (root.nightTemp - 2500) / 4000
			onChanged: {
				root.nightTemp = Math.round(2500 + value * 4000)
				nightTempTimer.restart()
			}
		}
	}

	// ---- Controls (moved from swaync panel) ----
	Grid {
		width: parent.width
		columns: 3
		spacing: 6
		columnSpacing: 6
		rowSpacing: 6

		QuickAction { icon: "󰐥"; label: "Power"; onClicked: { ShellState.closeAll(); Quickshell.execDetached(["/bin/sh", "-c", "$HOME/.config/hypr/scripts/Wlogout.sh"]) } }
		QuickAction { icon: "󰌾"; label: "Lock"; onClicked: { ShellState.closeAll(); Quickshell.execDetached(["hyprlock"]) } }
		QuickAction { icon: "󰖩"; label: "WIFI Panel"; onClicked: { ShellState.closeAll(); Quickshell.execDetached(["nm-connection-editor"]) } }
		MirrorScreen {}
		IdleInhibitor {}
		QuickAction { icon: "󰂯"; label: "BT Panel"; onClicked: { ShellState.closeAll(); Quickshell.execDetached(["blueman-manager"]) } }
	}

	// ---- helpers ----
	readonly property var wifiDevice: {
		for (const d of Networking.devices.values) {
			if (d.type === DeviceType.Wifi) return d
		}
		return null
	}

	readonly property bool wifiEnabled: Networking.wifiEnabled
	readonly property string wifiSsid: {
		for (const n of root.wifiNetworks) {
			if (n.connected) return n.name
		}
		return ""
	}

	property var wifiNetworks: []
	property string wifiPromptSsid: ""
	property var wifiConnecting: null
	property string wifiError: ""
	property bool pwVisible: false

	function updateWifiList() {
		if (!root.wifiDevice) { root.wifiNetworks = []; return }
		const arr = root.wifiDevice.networks.values.slice()
		arr.sort((a, b) => {
			if (a.connected !== b.connected) return a.connected ? -1 : 1
			return b.signalStrength - a.signalStrength
		})
		root.wifiNetworks = arr
	}

	// Trigger a fresh scan, then re-read the list. `force` re-requests a scan
	// even if one is already in progress (used by the manual refresh button).
	function refreshWifi(force) {
		const dev = root.wifiDevice
		if (dev && (force || !dev.scannerEnabled)) dev.scannerEnabled = true
		root.updateWifiList()
	}

	function findNetwork(ssid) {
		for (const n of root.wifiNetworks) {
			if (n.name === ssid) return n
		}
		return null
	}

	// Connect a network: saved or open ones connect directly, anything else
	// gets the inline password prompt. Manual connects re-enable autoconnect
	// (turned off by a manual disconnect).
	function connectWifi(net) {
		if (root.wifiConnecting) return
		if (net.connected || net.stateChanging) return
		root.wifiError = ""
		const dev = root.wifiDevice
		if (dev && !dev.autoconnect) dev.autoconnect = true
		if (net.known || net.security === WifiSecurityType.Open) {
			root.wifiConnecting = net
			net.connect()
			return
		}
		root.wifiPromptSsid = net.name
	}

	function disconnectWifi(net) {
		if (root.wifiConnecting) return
		// nmcli device disconnect deactivates the current connection and
		// stops NM from auto-connecting to anything else on this device
		// until a manual connect. Also flip the device flag via quickshell
		// as a fallback (Network.disconnect() no-ops on the iwd backend).
		const dev = root.wifiDevice
		if (dev) {
			if (dev.autoconnect) dev.autoconnect = false
			Quickshell.execDetached(["/bin/sh", "-c",
				`nmcli device disconnect ${dev.name}`])
		}
		root.updateWifiList()
	}

	function doWifiConnect(psk) {
		const net = root.findNetwork(root.wifiPromptSsid)
		if (!net) { root.wifiError = "Network no longer available"; return }
		root.wifiPromptSsid = ""
		root.wifiError = ""
		root.wifiConnecting = net
		net.connectWithPsk(psk)
	}

	function focusPrompt() {
		wifiPw.forceActiveFocus()
	}

	function failReasonText(reason) {
		switch (reason) {
			case ConnectionFailReason.WifiAuthTimeout:
				return "Wrong password"
			case ConnectionFailReason.NoSecrets:
				return "No password provided"
			case ConnectionFailReason.WifiNetworkLost:
				return "Network lost"
			case ConnectionFailReason.WifiClientFailed:
				return "Connection failed"
			default:
				return "Connection failed"
		}
	}

	// Tracks the in-flight wifi connect so we can detect success/failure.
	Connections {
		target: root.wifiConnecting

		function onConnectionFailed(reason) {
			const net = root.wifiConnecting
			root.wifiConnecting = null
			root.updateWifiList()
			// A known network with no stored password: fall back to asking
			// for the password instead of just failing.
			if (reason === ConnectionFailReason.NoSecrets && net) {
				root.wifiError = ""
				root.wifiPromptSsid = net.name
				return
			}
			root.wifiError = root.failReasonText(reason)
		}

		function onConnectedChanged() {
			if (root.wifiConnecting && root.wifiConnecting.connected) {
				root.wifiConnecting = null
				root.wifiError = ""
				root.updateWifiList()
			}
		}
	}

	readonly property bool ethernetConnected: {
		for (const d of Networking.devices.values) {
			if (d.type === DeviceType.Wired && d.connected) return true
		}
		return false
	}

	// Ethernet IPv4 is fetched via nmcli (quickshell's NetworkDevice.address
	// is the MAC address).
	property string ethernetIpv4: ""

	Process {
		id: ethIpProc
		command: []
		running: false
		stdout: StdioCollector {
			onStreamFinished: {
				const raw = text.trim()
				if (!raw) { root.ethernetIpv4 = ""; return }
				const slash = raw.indexOf('/')
				root.ethernetIpv4 = slash > 0 ? raw.slice(0, slash) : raw
			}
		}
	}

	function refreshEthernetIp() {
		const devs = root.wiredDevices
		if (!devs.length) { root.ethernetIpv4 = ""; return }
		ethIpProc.command = ["nmcli", "-g", "IP4.ADDRESS", "dev", "show", devs[0].name]
		ethIpProc.running = true
	}

	Timer {
		id: ethIpTimer
		interval: 3000
		repeat: true
		onTriggered: {
			if (ShellState.quickSettingsOpen) root.refreshEthernetIp()
		}
	}

	readonly property var wiredDevices: {
		const out = []
		for (const d of Networking.devices.values) {
			if (d.type === DeviceType.Wired) out.push(d)
		}
		return out
	}

	readonly property bool bluetoothOn: Bluetooth.defaultAdapter
		? Bluetooth.defaultAdapter.enabled
		: false

	readonly property bool bluetoothBlocked: Bluetooth.defaultAdapter
		? Bluetooth.defaultAdapter.state === BluetoothAdapterState.Blocked
		: false

	// Bluetooth discovery: only devices seen *since* the current scan started
	// (plus connected ones) are considered in range. Bonded devices that are
	// off (offline) stay hidden.
	property var btInRange: []
	property var btSnapshot: ({})
	property var btRecent: ({})
	property var btConnecting: null
	property bool btScanning: false

	function startBtScan() {
		const a = Bluetooth.defaultAdapter
		if (!a || !a.enabled || a.discovering) return
		root.btSnapshot = {}
		for (const d of Bluetooth.devices.values) {
			if (d.bonded) root.btSnapshot[d.address] = true
		}
		a.discovering = true
	}

	function stopBtScan() {
		const a = Bluetooth.defaultAdapter
		if (a && a.discovering) a.discovering = false
	}

	function refreshBluetooth() {
		root.stopBtScan()
		btRestartTimer.start()
	}

	function updateBtList() {
		const now = Date.now()
		const out = []
		for (const d of Bluetooth.devices.values) {
			if (d.connected) root.btRecent[d.address] = now + 10000
			// Connected, never-saved (just discovered), or recently connected
			// (grace period so a briefly dropped device doesn't flicker out).
			if (d.connected || !d.bonded || now < (root.btRecent[d.address] || 0))
				out.push(d)
		}
		root.btInRange = out
		root.btScanning = Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
	}

	function btAction(dev) {
		if (dev.connected) {
			dev.disconnect()
			return
		}
		root.connectBt(dev)
	}

	function connectBt(dev) {
		if (root.btConnecting) return
		// Scanning while connecting often makes the link drop; stop the scan
		// first so the connection can settle.
		root.stopBtScan()
		root.btConnecting = dev
		if (dev.bonded || dev.paired) dev.connect()
		else dev.pair()
	}

	Connections {
		target: root.btConnecting

		function onBondedChanged() {
			if (root.btConnecting && root.btConnecting.bonded
					&& !root.btConnecting.connected)
				root.btConnecting.connect()
		}

		function onConnectedChanged() {
			if (root.btConnecting && root.btConnecting.connected)
				root.btConnecting = null
		}
	}

	Process {
		id: nlProc
		command: ["pgrep", "-x", "hyprsunset"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: root.nightlightOn = text.trim().length > 0
		}
	}

	// hyprsunset is Hyprland's native night light (wlsunset is incompatible:
	// Hyprland doesn't implement its gamma-control protocol). We kill the
	// daemon to turn it off, so the pgrep check above stays accurate.
	function startNightlight() {
		Quickshell.execDetached(["/bin/sh", "-c",
			`if pgrep -x hyprsunset >/dev/null 2>&1; then hyprctl hyprsunset temperature ${root.nightTemp} >/dev/null 2>&1; else nohup hyprsunset --temperature ${root.nightTemp} >/dev/null 2>&1 & fi`])
	}

	function stopNightlight() {
		Quickshell.execDetached(["/bin/sh", "-c",
			"hyprctl hyprsunset identity >/dev/null 2>&1; pkill -x hyprsunset"])
	}

	Timer {
		id: nightTempTimer
		interval: 500
		onTriggered: {
			if (root.nightlightOn) root.startNightlight()
		}
	}

	function signalIcon(strength) {
		if (strength > 80) return "󰤨"
		if (strength > 60) return "󰤥"
		if (strength > 40) return "󰤢"
		if (strength > 20) return "󰤟"
		return "󰤯"
	}

	// Collapse every dropdown when the popup closes (otherwise the expanded
	// flags stay sticky and the section is stuck open on the next open).
	// Also re-check hyprsunset + refresh the scans once on open.
	// NOTE: does NOT rely on the signal parameter (broken in Qt 6 signal
	// handlers); reads the state directly instead.
	Connections {
		target: ShellState
		function onQuickSettingsOpenChanged() {
			const open = ShellState.quickSettingsOpen
			if (!open) {
				root.wifiExpanded = false
				root.bluetoothExpanded = false
				root.ethernetExpanded = false
				root.nightlightExpanded = false
				btPollTimer.stop()
				ethIpTimer.stop()
				root.stopBtScan()
				root.wifiPromptSsid = ""
				root.wifiError = ""
			} else {
				nlProc.running = true
				root.refreshWifi(true)
				root.updateWifiList()
				root.refreshEthernetIp()
				ethIpTimer.start()
				if (root.bluetoothOn) {
					btPollTimer.start()
					root.startBtScan()
				}
			}
		}
	}

	// Autoscan: rescan wifi every 5s while wifi is enabled, so newly found
	// networks (hotspots) appear even while the panel is closed.
	Timer {
		id: wifiRefreshTimer
		interval: 5000
		repeat: true
		running: true
		onTriggered: {
			if (root.wifiEnabled) root.refreshWifi(false)
		}
	}

	// Bluetooth has no change signal, so poll the model while the section is
	// open to pick up newly discovered devices.
	Timer {
		id: btPollTimer
		interval: 2000
		repeat: true
		onTriggered: {
			if (ShellState.quickSettingsOpen && root.bluetoothExpanded)
				root.updateBtList()
		}
	}

	// Restart a stopped discovery shortly after stopping it (BlueZ requires
	// a fresh StartDiscovery for a rescan).
	Timer {
		id: btRestartTimer
		interval: 250
		onTriggered: root.startBtScan()
	}

	// Delayed first scan after bluetooth is toggled on.
	Timer {
		id: btScanDelay
		interval: 2500
		onTriggered: root.startBtScan()
	}
}