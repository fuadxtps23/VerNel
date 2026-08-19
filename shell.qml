//@ pragma UseQApplication
//@ pragma Env KVANTUM_THEME = matugen
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import "widgets"

// A 1:1 replica of the user's waybar, reimagined in quickshell: a vertical
// panel on the right edge, with macOS-style popups for notifications, quick
// settings, audio and mpris details. Uses quickshell's native notification
// daemon instead of swaync.
ShellRoot {
	id: root

	// ---- Native notification daemon (replaces swaync) ----
	NotificationServer {
		id: notificationServer
		actionsSupported: true
		bodySupported: true
		bodyMarkupSupported: true
		imageSupported: true
		onNotification: (notification) => {
			// Always claim/track the notification: an untracked notification
			// gets rendered by the server itself as a regular window instead
			// of our toast.
			notification.tracked = true
			if (notification.lastGeneration) return
			if (ShellState.dndEnabled) return
			ShellState.lastNotification = notification
			ShellState.addHistory(notification)
		}
	}

	// ---- Keybind IPC ----
	// Allows Hyprland binds (SUPER+N / SUPER+M / SUPER+SHIFT+W) to toggle the
	// panels:
	//   quickshell ipc -c ricegueh call ricegueh toggleNotifications
	//   quickshell ipc -c ricegueh call ricegueh toggleQuickSettings
	//   quickshell ipc -c ricegueh call ricegueh toggleWallpaperSelector
	IpcHandler {
		target: "ricegueh"
		function toggleNotifications(): void {
			if (ShellState.notificationsOpen) ShellState.closeAll()
			else ShellState.openNotifications(ShellState.pointerScreen)
		}
		function toggleQuickSettings(): void {
			if (ShellState.quickSettingsOpen) ShellState.closeAll()
			else ShellState.openQuickSettings(ShellState.pointerScreen)
		}
		function toggleMprisDetail(): void {
			if (ShellState.mprisDetailOpen) ShellState.closeAll()
			else ShellState.openMprisDetail(ShellState.pointerScreen)
		}
		function toggleAudioControls(): void {
			if (ShellState.audioControlsOpen) ShellState.closeAll()
			else ShellState.openAudioControls(ShellState.pointerScreen)
		}
		function toggleCalendar(): void {
			if (ShellState.calendarOpen) ShellState.closeAll()
			else ShellState.openCalendar(ShellState.pointerScreen)
		}
		function toggleWallpaperSelector(): void {
			if (ShellState.wallpaperSelectorOpen) ShellState.closeAll()
			else ShellState.openWallpaperSelector(ShellState.pointerScreen)
		}
		function reload(): void {
			Quickshell.reload(false)
		}
	}

	// If another notification daemon (e.g. xfce4-notifyd, which is activatable)
	// grabbed org.freedesktop.Notifications while quickshell wasn't running,
	// apps like Firefox would notify THAT daemon and show its windows instead
	// of our toasts. Killing it makes the server's watcher re-register the name.
	Component.onCompleted: {
		Quickshell.execDetached(["bash", "-c",
			"pkill -x xfce4-notifyd; pkill -x dunst; pkill -x mako; pkill -x swaync"])
	}

	// Tracks which screen the cursor is on (used to only show popups/toasts
	// on the monitor the cursor is currently on).
	PointerTracker {}

	// Polls caps/num lock state and drives the OSD overlay.
	OsdMonitor {}

	// Popup windows (one per screen; only the screen under the cursor shows).
	Variants {
		model: Quickshell.screens
		NotificationCenter { server: notificationServer }
	}
	Variants {
		model: Quickshell.screens
		QuickSettings {}
	}
	Variants {
		model: Quickshell.screens
		WifiHistory {}
	}
	Variants {
		model: Quickshell.screens
		AudioControls {}
	}
	Variants {
		model: Quickshell.screens
		Calendar {}
	}
	Variants {
		model: Quickshell.screens
		WallpaperSelector {}
	}
	Variants {
		model: Quickshell.screens
		MprisDetail {}
	}
	Variants {
		model: Quickshell.screens
		Osd {}
	}
	Variants {
		model: Quickshell.screens
		Toast {}
	}

	// ---- Main bar ----
	Variants {
		model: Quickshell.screens

		PanelWindow {
			required property var modelData
			screen: modelData
			aboveWindows: true

			anchors {
				top: true
				bottom: true
				right: true
			}

			margins {
				top: Config.barMarginTop
				bottom: Config.barMarginBottom
				right: Config.barMarginRight
			}

			color: "transparent"
			implicitWidth: Config.barWidth

			Rectangle {
				id: bar
				anchors.fill: parent
				radius: Config.barRadius
				color: Config.barBackground
				border {
					width: Config.barBorderWidth
					color: Config.primary
				}
				clip: true

				Item {
					id: modulesHost
					anchors.fill: parent

					// Shared morphing hover highlight: slides between modules
					// as the cursor moves from one icon to the next. While
					// fading out it holds its last rect (instead of collapsing
					// to the top), so a re-hover morphs from that position.
					Rectangle {
						id: hoverBar
						width: Config.barWidth - 6
						x: 3
						radius: 5
						color: Config.cardBackgroundHover
						z: 0

						readonly property var hoverTarget: ShellState.barHover
						property var lastHover: null

						onHoverTargetChanged: {
							if (hoverBar.hoverTarget) hoverBar.lastHover = hoverBar.hoverTarget
						}

						y: hoverBar.lastHover ? hoverBar.lastHover.y : 0
						height: hoverBar.lastHover ? hoverBar.lastHover.height : 0
						opacity: hoverBar.hoverTarget ? 1 : 0

						Behavior on y {
							NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
						}
						Behavior on height {
							NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
						}
						Behavior on opacity {
							NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
						}
					}

					// ---- modules-left: top group ----
					Column {
						id: topGroup
						anchors {
							top: parent.top
							left: parent.left
							right: parent.right
						}
						anchors.topMargin: Config.barPaddingV
						spacing: Config.moduleSpacing

						Swaync { screen: modelData; host: modulesHost }
						Clock { screen: modelData; host: modulesHost }
						VolumeGroup { screen: modelData; host: modulesHost }
						Orbit { screen: modelData; host: modulesHost }
						Tray {}
					}

					// ---- modules-center ----
					Mpris {
						anchors.centerIn: parent
						screen: modelData
						host: modulesHost
					}

					// ---- modules-right: bottom group ----
					Column {
						id: bottomGroup
						anchors {
							bottom: parent.bottom
							left: parent.left
							right: parent.right
						}
						anchors.bottomMargin: Config.barPaddingV
						spacing: Config.moduleSpacing

						Backlight { host: modulesHost }
						Battery {}
						Temperature { host: modulesHost }
						Workspaces {}
					}
				}
			}
		}
	}
}