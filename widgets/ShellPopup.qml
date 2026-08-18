import QtQuick
import Quickshell

// Animated popup window. While open it expands to fill the whole screen and
// catches clicks outside the card (which sits at the right edge) so clicking
// anywhere else dismisses it. The card slides down + fades in on open and
// slides up + fades out on close.
//
// - `open` is the "requested" state (bound by the instance to a ShellState
//   flag). The window only actually shows when its own screen matches
//   ShellState.popupScreen, so the same popup never appears on both monitors.
// - `centerVertical` positions the card vertically centered on the screen
//   instead of at the top (used for the mpris detail box).
PanelWindow {
	id: root

	required property var modelData

	property bool open: false
	property bool centerVertical: false
	property int popupWidth: Config.popupWidth
	property int topMargin: Config.barMarginTop
	property int rightMargin: Config.barWidth + Config.barMarginRight + 8
	property int padding: 12

	default property alias content: body.data

	screen: root.modelData
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	aboveWindows: true
	// Allow the popup to receive keyboard input (needed for the wifi password
	// field); keyboard focus is granted when the user clicks inside it.
	focusable: true

	anchors { top: true; bottom: true; left: true; right: true }

	readonly property bool effectiveOpen: root.open
		&& (ShellState.popupScreen == null
			|| (root.modelData && ShellState.popupScreen
				&& root.modelData.name === ShellState.popupScreen.name))

	readonly property real screenW: root.screen ? root.screen.width : 0
	readonly property real screenH: root.screen ? root.screen.height : 0
	readonly property real cardX: Math.max(0, root.screenW - root.rightMargin - root.popupWidth)
	readonly property real cardY: root.centerVertical
		? Math.max(0, Math.round(root.screenH - card.height) / 2)
		: root.topMargin
	// Bottom edge of the card in screen coordinates (used by the toast host
	// to sit below the panel). Exposed here because the `card` id is private
	// to this component — subclasses can't reference it directly.
	readonly property real cardBottom: root.cardY + card.height

	visible: root.effectiveOpen
	implicitWidth: root.effectiveOpen ? root.screenW : root.popupWidth
	implicitHeight: root.effectiveOpen ? root.screenH : body.implicitHeight + root.padding * 2

	// Slide the card in from the right edge of the screen when the popup
	// opens (explicit animation — the window is unmapped while closed, so
	// a plain Behavior on a bound value wouldn't be visible).
	onEffectiveOpenChanged: {
		if (root.effectiveOpen) {
			card.slideX = root.rightMargin + root.popupWidth + 8
			card.fade = 0
			openAnim.restart()
			// Grab keyboard focus so ESC / password typing work without the
			// user having to click first.
			card.forceActiveFocus()
		} else {
			card.slideX = 0
			card.fade = 1
		}
	}

	// Fullscreen click-catcher behind the card.
	MouseArea {
		id: outside
		anchors.fill: parent
		visible: root.effectiveOpen
		onClicked: ShellState.closeAll()
	}

	// Swallow clicks on the card's empty background so they don't fall
	// through to the fullscreen `outside` catcher and close the panel.
		Rectangle {
			id: card
			width: root.popupWidth
			height: body.implicitHeight + root.padding * 2
			x: root.cardX
			y: root.cardY
			radius: Config.popupRadius
			color: Config.popupBackground
			border { width: Config.popupBorderWidth; color: Config.popupBorder }
			clip: true

			// NOTE: no Behavior on height here on purpose. The card height is
			// bound to `body.implicitHeight`, which already changes smoothly
			// while a dropdown section animates its height — an extra Behavior
			// would chase that moving target and visibly lag behind it.
			// Instant content changes (notifications appearing/clearing) are
			// animated at the source instead (NotificationCard animHeight).

		MouseArea {
			anchors.fill: parent
		}

		// ESC anywhere in any popup closes it (key events bubble up from the
		// focused password fields etc.).
		Keys.onEscapePressed: ShellState.closeAll()

		property real slideX: 0
		property real fade: 1

		opacity: card.fade
		transform: Translate {
			x: card.slideX
		}

		ParallelAnimation {
			id: openAnim
			running: false
			NumberAnimation {
				target: card
				property: "slideX"
				to: 0
				duration: Config.animMedium
				easing.type: Easing.OutCubic
			}
			NumberAnimation {
				target: card
				property: "fade"
				to: 1
				duration: Config.animMedium
				easing.type: Easing.OutCubic
			}
		}

		Column {
			id: body
			anchors {
				top: parent.top
				left: parent.left
				right: parent.right
			}
			anchors.margins: root.padding
			spacing: 8
		}
	}
}