import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

// A single notification entry in the notification center. Swipe left/right
// past the threshold (or right-click) to dismiss it.
Rectangle {
	id: root

	property var notification: null

	// 6-digit pairing code detection (KDE Connect pairing requests). If the
	// notification body/summary contains one, offer a one-click copy.
	readonly property string pairCode: {
		if (!root.notification) return ""
		const src = `${root.notification.body || ""}\n${root.notification.summary || ""}`
		const m = src.match(/\b\d{6}\b/)
		return m ? m[0] : ""
	}

	readonly property string imageSource: root.notification && root.notification.image
		? root.notification.image : ""

	readonly property string thumbSource: {
		if (!root.notification) return ""
		if (!root.notification.image) return root.notification.appIcon || ""
		return Config.isBigImage(bigImage.sourceSize.width, bigImage.sourceSize.height)
			? (root.notification.appIcon || "")
			: root.notification.image
	}

	width: parent ? parent.width : 0
	// Animated display height: grows from 0 on creation (so the panel morphs
	// open as a notification appears) and shrinks to 0 on dismissal (so it
	// morphs shut). The parent Column's implicit size follows this each frame.
	property real naturalHeight: col.implicitHeight + 16
	property real animHeight: 0
	height: root.animHeight
	radius: 10
	color: ma.containsMouse ? Config.cardBackgroundHover : Config.cardBackground
	clip: true

	Behavior on animHeight {
		NumberAnimation { duration: Config.animMedium; easing.type: Easing.InOutCubic }
	}
	onNaturalHeightChanged: root.animHeight = root.naturalHeight

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}

	// Swipe left/right to dismiss; right-click also dismisses. Releasing past
	// the threshold slides the card out, otherwise it springs back. Declared
	// BEFORE the content so the action buttons (painted later) stay clickable.
	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton
		drag.target: root
		drag.axis: Drag.XAxis
		drag.minimumX: -root.width
		drag.maximumX: root.width
		onReleased: root.commitSwipe()
		onClicked: {
			if (mouse.button === Qt.RightButton) root.dismiss()
		}
	}

	Column {
		id: col
		anchors.fill: parent
		anchors.margins: 8
		spacing: 4

		Row {
			width: parent.width
			spacing: 8

			// Left thumbnail: notification image if avatar-sized, else app icon.
			ClippingRectangle {
				id: thumb
				width: 40
				height: 40
				radius: 20
				color: Config.cardBackgroundHover
				visible: root.thumbSource.length > 0

				IconImage {
					anchors.fill: parent
					source: root.thumbSource
				}
			}

			Column {
				width: parent.width - (thumb.visible ? 48 : 0)
				spacing: 2

				Text {
					text: root.notification ? (root.notification.appName || "") : ""
					color: Config.secondary
					font { family: Config.fontFamily; pixelSize: 11; bold: true }
					width: parent.width
					elide: Text.ElideRight
				}

				Text {
					text: root.notification ? root.notification.summary : ""
					color: Config.text
					wrapMode: Text.WordWrap
					font { family: Config.fontFamily; pixelSize: 13; bold: true }
					width: parent.width
				}

				Text {
					text: root.notification ? root.notification.body : ""
					color: Config.secondary
					wrapMode: Text.WordWrap
					font { family: Config.fontFamily; pixelSize: 12 }
					width: parent.width
					visible: text.length > 0
				}
			}
		}

		// Large body image (screenshots, video thumbnails, ...) shown below the
		// text only when the image is actually big rather than an avatar.
		Image {
			id: bigImage
			source: root.imageSource
			width: parent.width
			height: 160
			fillMode: Image.PreserveAspectFit
			visible: status === Image.Ready
				&& Config.isBigImage(bigImage.sourceSize.width, bigImage.sourceSize.height)
		}

		Row {
			width: parent.width
			spacing: 6
			visible: (root.notification && root.notification.actions.length > 0)
				|| root.pairCode.length > 0

			Repeater {
				model: root.notification ? root.notification.actions : []

				delegate: ActionButton {
					required property var modelData
					text: modelData.text
					onClicked: modelData.invoke()
				}
			}

			ActionButton {
				icon: "󰅐"
				text: "Copy code"
				visible: root.pairCode.length > 0
				onClicked: Quickshell.clipboardText = root.pairCode
			}
		}
	}

	function dismiss() {
		if (root.notification && root.notification.id !== undefined)
			ShellState.dismissHistory(root.notification.id)
	}

	// Slide the card out to the right (used by "clear all from app").
	function slideOut() {
		slideOutX.to = root.width + 20
		slideOutAnim.restart()
	}

	function commitSwipe() {
		if (Math.abs(root.x) < 60) { backAnim.restart(); return }
		slideOutX.to = root.x < 0 ? -root.width - 20 : root.width + 20
		slideOutAnim.restart()
	}

	NumberAnimation {
		id: backAnim
		target: root
		property: "x"
		to: 0
		duration: Config.animMedium
		easing.type: Easing.OutCubic
	}

	ParallelAnimation {
		id: slideOutAnim
		running: false
		NumberAnimation {
			id: slideOutX
			target: root
			property: "x"
			duration: Config.animMedium
			easing.type: Easing.InCubic
		}
		NumberAnimation {
			target: root
			property: "opacity"
			to: 0
			duration: Config.animMedium
		}
		// Shrink the card while it slides away so the panel morphs shut.
		NumberAnimation {
			target: root
			property: "animHeight"
			to: 0
			duration: Config.animMedium
			easing.type: Easing.InCubic
		}
		onFinished: root.dismiss()
	}
}