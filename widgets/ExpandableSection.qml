import QtQuick

// A collapsible section that smoothly animates its height and fades its
// content in/out instead of snapping on `visible`. Because the animated
// height feeds the parent Column's implicit size frame-by-frame, the
// surrounding popup card morphs smoothly too.
Item {
	id: root

	default property alias content: body.data
	property bool expanded: false
	property bool enabled: true
	width: parent ? parent.width : 0

	readonly property real targetHeight: root.expanded && root.enabled
		? body.implicitHeight : 0

	// Animated display height. Kept visible while animating so the collapse
	// plays out, but hidden once fully closed so no dead spacing remains
	// between the rows above and below.
	property real animHeight: 0
	visible: (root.expanded && root.enabled) || root.animHeight > 1
	height: root.animHeight
	implicitHeight: root.animHeight
	clip: true
	opacity: root.expanded && root.enabled ? 1 : 0

	Behavior on animHeight {
		NumberAnimation { duration: Config.animDropdown; easing.type: Easing.InOutCubic }
	}
	Behavior on opacity {
		NumberAnimation { duration: Config.animDropdown; easing.type: Easing.OutCubic }
	}

	onTargetHeightChanged: root.animHeight = root.targetHeight

	Column {
		id: body
		width: parent.width
		spacing: 4
	}
}
