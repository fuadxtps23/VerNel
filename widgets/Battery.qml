import QtQuick
import Quickshell.Services.UPower

// battery - "{icon} {capacity}%", rotated 90°. Uses the UPower battery
// device; charging / plugged-in states get their own icons.
Item {
	id: root

	width: Config.barWidth
	height: label.height

	readonly property var battery: {
		for (const d of UPower.devices.values) {
			if (d.isLaptopBattery) return d
		}
		return null
	}

	readonly property string icons: ["", "", "", "", ""]

	readonly property int capacity: root.battery ? Math.round(root.battery.percentage * 100) : 0
	readonly property bool charging: root.battery
		? root.battery.state === UPowerDeviceState.Charging
			|| root.battery.state === UPowerDeviceState.PendingCharge
		: false
	readonly property bool critical: !root.charging && root.capacity <= 15

	readonly property string icon: {
		if (!root.battery) return ""
		if (root.charging) return "󰂄"
		const level = Math.max(0, Math.min(root.icons.length - 1, Math.round(root.capacity / 100 * (root.icons.length - 1))))
		return root.icons[level]
	}

	RotatedText {
		id: label
		anchors.centerIn: parent
		text: root.battery ? `${root.capacity}% ${root.icon}` : ""
		color: root.critical ? Config.critical : Config.primary
	}
}