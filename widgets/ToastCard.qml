import QtQuick
import Quickshell
import Quickshell.Widgets

// A single toast card. Slides in from the right, auto-hides after a few
// seconds, and can be dismissed by dragging or swiping it right. On dismissal
// the card collapses (height → 0) so the cards below glide up to fill the
// space and the host window resizes in sync (no clipping).
Rectangle {
	id: card

	property var host: null
	property var entry: null
	property var notification: null

	readonly property string imageSource: card.notification && card.notification.image
		? card.notification.image : ""

	// Avatar-sized images (profile pictures, etc.) go to the left thumbnail;
	// large images (screenshots, video thumbnails) render below the text with
	// the app icon used as the thumbnail instead.
	readonly property string thumbSource: {
		if (!card.notification) return ""
		if (!card.notification.image) return card.notification.appIcon || ""
		return Config.isBigImage(bigImage.sourceSize.width, bigImage.sourceSize.height)
			? (card.notification.appIcon || "")
			: card.notification.image
	}

	// 6-digit pairing code detection (KDE Connect pairing requests). If the
	// notification body/summary contains one, offer a one-click copy.
	readonly property string pairCode: {
		if (!card.notification) return ""
		const src = `${card.notification.body || ""}\n${card.notification.summary || ""}`
		const m = src.match(/\b\d{6}\b/)
		return m ? m[0] : ""
	}

	property real transX: 320
	property real fade: 0
	property real collapse: 0

	readonly property real baseH: body.implicitHeight + 16
	width: 300
	height: card.baseH * (1 - card.collapse)
	radius: Config.popupRadius
	// Semi-transparent at rest; more opaque while hovered (so the text stays
	// readable over busy wallpapers). Hover is read directly (not a bound
	// property) for the same staleness reason as the timer logic.
	readonly property bool isHovered: dragArea.containsMouse || card.buttonHover > 0
	color: card.isHovered ? Config.toastBackground : Config.popupBackground

	Behavior on color {
		ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
	}
	border { width: Config.popupBorderWidth; color: Config.popupBorder }
	clip: true

	transform: Translate {
		x: card.transX
	}
	opacity: card.fade

	Behavior on y {
		NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic }
	}

	Component.onCompleted: {
		inAnim.restart()
		card.startHideTimer()
	}

	ParallelAnimation {
		id: inAnim
		running: false
		NumberAnimation { target: card; property: "transX"; to: 0; duration: Config.animMedium; easing.type: Easing.OutCubic }
		NumberAnimation { target: card; property: "fade"; to: 1; duration: Config.animMedium; easing.type: Easing.OutCubic }
	}

	ParallelAnimation {
		id: outAnim
		running: false
		NumberAnimation { target: card; property: "transX"; to: 320; duration: Config.animMedium; easing.type: Easing.InCubic }
		NumberAnimation { target: card; property: "fade"; to: 0; duration: Config.animMedium; easing.type: Easing.InCubic }
		NumberAnimation { target: card; property: "collapse"; to: 1; duration: Config.animMedium; easing.type: Easing.InCubic }
		onFinished: {
			if (card.host) card.host.removeEntry(card)
		}
	}

	Timer {
		id: hideTimer
		interval: card.hideRemaining
		running: false
		onTriggered: card.dismiss()
	}

	// Auto-hide countdown with freeze-on-hover: while the cursor is over the
	// card the remaining time is held (paused), and it resumes from where it
	// was when the cursor leaves — NOT reset. Button hovers count too since
	// they sit on top of the swipe MouseArea. Hover is read SYNCHRONOUSLY
	// from the direct property inside the handlers (a bound `hovered` reads
	// stale inside a signal handler and pauses/resumes backwards).
	readonly property int hideTimeout: 5000
	property int hideRemaining: card.hideTimeout
	property real hideStartedAt: 0
	property bool hidePaused: false
	property int buttonHover: 0

	function onHoverChanged(h) {
		card.buttonHover += h ? 1 : -1
		if (card.buttonHover < 0) card.buttonHover = 0
		card.updateHideTimer()
	}

	function updateHideTimer() {
		if (card.dismissing) return
		if (dragArea.containsMouse || card.buttonHover > 0) card.pauseHideTimer()
		else card.resumeHideTimer()
	}

	function pauseHideTimer() {
		if (card.hidePaused) return
		card.hidePaused = true
		card.hideRemaining = Math.max(
			0, card.hideRemaining - (Date.now() - card.hideStartedAt))
		hideTimer.stop()
	}

	function resumeHideTimer() {
		if (!card.hidePaused) return
		card.hidePaused = false
		if (card.hideRemaining <= 0) { card.dismiss(); return }
		card.hideStartedAt = Date.now()
		hideTimer.interval = card.hideRemaining
		hideTimer.restart()
	}

	function startHideTimer() {
		card.hidePaused = false
		card.hideRemaining = card.hideTimeout
		card.hideStartedAt = Date.now()
		hideTimer.interval = card.hideRemaining
		hideTimer.restart()
		card.updateHideTimer()
	}

	property bool dismissing: false

	function dismiss() {
		if (card.dismissing) return
		card.dismissing = true
		hideTimer.stop()
		outAnim.restart()
	}

	function commitSwipe() {
		if (card.x > 120) card.dismiss()
		else backAnim.restart()
	}
	NumberAnimation {
		id: backAnim
		target: card
		property: "x"
		to: 0
		duration: Config.animMedium
		easing.type: Easing.OutCubic
	}

	// Click → open notification center. Drag / swipe right → dismiss.
	// Declared BEFORE the content so the action buttons (painted later) stay
	// clickable on top; non-interactive body items let events fall through.
	MouseArea {
		id: dragArea
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton
		drag.target: card
		drag.axis: Drag.XAxis
		drag.minimumX: 0
		drag.maximumX: 300
		onClicked: ShellState.openNotifications()
		onReleased: card.commitSwipe()
		onContainsMouseChanged: card.updateHideTimer()
		onWheel: {
			const dx = wheel.pixelDelta.x !== 0
				? wheel.pixelDelta.x
				: wheel.angleDelta.x / 120 * 10
			if (dx !== 0) {
				card.x = Math.max(0, Math.min(300, card.x + dx))
				settleTimer.restart()
			}
		}
	}

	Column {
		id: body
		anchors.fill: parent
		anchors.margins: 10
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
				visible: card.thumbSource.length > 0

				IconImage {
					anchors.fill: parent
					source: card.thumbSource
				}
			}

			Column {
				width: parent.width - (thumb.visible ? 48 : 0) - closeBtn.width - 8
				spacing: 1

				Text {
					text: card.notification ? (card.notification.appName || "Notification") : ""
					color: Config.secondary
					font { family: Config.fontFamily; pixelSize: 11; bold: true }
					elide: Text.ElideRight
					width: parent.width
					verticalAlignment: Text.AlignVCenter
				}

				Text {
					text: card.notification ? card.notification.summary : ""
					color: Config.text
					wrapMode: Text.Wrap
					font { family: Config.fontFamily; pixelSize: 12; bold: true }
					width: parent.width
					maximumLineCount: 1
					elide: Text.ElideRight
				}

				Text {
					text: card.notification ? card.notification.body : ""
					color: Config.secondary
					wrapMode: Text.Wrap
					font { family: Config.fontFamily; pixelSize: 11 }
					width: parent.width
					maximumLineCount: 2
					elide: Text.ElideRight
					visible: text.length > 0
				}
			}

			// Close (×) button: dismisses the toast immediately. Its hover
			// also keeps the auto-hide countdown frozen.
			Rectangle {
				id: closeBtn
				width: 18
				height: 18
				radius: 9
				color: closeMa.containsMouse ? Config.cardBackgroundHover : "transparent"

				Behavior on color {
					ColorAnimation { duration: Config.animShort; easing.type: Easing.OutCubic }
				}

				Text {
					anchors.centerIn: parent
					text: "✕"
					color: Config.secondary
					font { family: Config.fontFamily; pixelSize: 10 }
					verticalAlignment: Text.AlignVCenter
				}

				MouseArea {
					id: closeMa
					anchors.fill: parent
					hoverEnabled: true
					onClicked: card.dismiss()
					onContainsMouseChanged: card.onHoverChanged(containsMouse)
				}
			}
		}

		// Large body image (screenshots, video thumbnails, ...) shown below the
		// text only when the image is actually big rather than an avatar.
		Image {
			id: bigImage
			source: card.imageSource
			width: parent.width
			height: 140
			fillMode: Image.PreserveAspectFit
			visible: status === Image.Ready
				&& Config.isBigImage(bigImage.sourceSize.width, bigImage.sourceSize.height)
		}

		// Action buttons (Pair, Accept, Open, ...). Only shown when the
		// notification carries actions. The KDE Connect pairing code gets an
		// extra one-click "copy" button.
		Row {
			width: parent.width
			spacing: 6
			visible: (card.notification && card.notification.actions.length > 0)
				|| card.pairCode.length > 0

			Repeater {
				model: card.notification ? card.notification.actions : []

				delegate: ActionButton {
					required property var modelData
					text: modelData.text
					onHoveredChanged: card.onHoverChanged(hovered)
					onClicked: {
						modelData.invoke()
						card.dismiss()
					}
				}
			}

			ActionButton {
				icon: "󰅐"
				text: "Copy code"
				visible: card.pairCode.length > 0
				onHoveredChanged: card.onHoverChanged(hovered)
				onClicked: {
					Quickshell.clipboardText = card.pairCode
					card.dismiss()
				}
			}
		}
	}

	Timer {
		id: settleTimer
		interval: 300
		onTriggered: card.commitSwipe()
	}
}