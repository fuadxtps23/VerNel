pragma Singleton
import QtQuick
import Quickshell

// Global UI state shared between the bar and its popups.
Singleton {
	id: root

	property bool quickSettingsOpen: false
	property bool notificationsOpen: false
	property bool mprisDetailOpen: false
	property bool audioControlsOpen: false
	property bool calendarOpen: false
	property bool wifiHistoryOpen: false
	property bool wallpaperSelectorOpen: false

	// Last wallpaper applied from the selector (highlighted in the grid).
	property string currentWallpaper: ""

	property bool dndEnabled: false

	// Bottom edge (screen coords) of the quick settings card, synced by the
	// QuickSettings popup. The toast host uses it to sit below the panel
	// instead of overlapping it. 0 while never computed / panel closed.
	property real quickSettingsBottom: 0

	// Same for the audio controls card, so toasts also sit below it when open.
	property real audioControlsBottom: 0

	// Same for the calendar card.
	property real calendarBottom: 0

	// Same for the wallpaper selector card.
	property real wallpaperSelectorBottom: 0

	// ---- OSD overlay (keyboard locks / volume / brightness) ----
	// Driven by OsdMonitor; cleared by its 3s hide timer.
	property bool osdVisible: false
	property var osdScreen: null
	property string osdType: "lock" // "lock" | "volume" | "brightness"
	property string osdLabel: "" // lock: "CAPS LOCK" / "NUM LOCK"
	property bool osdOn: false // lock: state
	property int osdPercent: 0 // volume/brightness: 0-100
	property bool osdMuted: false // volume: muted

	// The bar's shared hover-highlight target. Modules report {y, height}
	// (in bar coordinates) when hovered so the bar can morph/slide one
	// highlight between icons instead of each icon fading its own.
	property var barHover: null
	// The HoverHighlight instance that currently owns barHover (a QObject
	// reference so the owning module can be identified for clearing).
	property var barHoverTracker: null

	// The screen a popup should appear on (set by the module that opened it).
	// null means "the popup owner decides".
	property var popupScreen: null

	// Last screen the cursor was seen on (tracked by PointerTracker).
	property var pointerScreen: null

	// Set by shell.qml's NotificationServer when a new notification arrives.
	property var lastNotification: null

	// Persistent in-session notification history (plain copies), so the
	// notification center keeps entries even after the daemon forgets them.
	property var notificationHistory: []

	readonly property bool anyPopupOpen: root.quickSettingsOpen || root.notificationsOpen
		|| root.mprisDetailOpen || root.audioControlsOpen || root.calendarOpen
		|| root.wallpaperSelectorOpen

	function onPopupScreen(screen) {
		return screen !== undefined && screen !== null ? screen : root.pointerScreen
	}

	// Opening one panel closes the others (macOS-style control center).
	function openQuickSettings(screen) {
		root.popupScreen = root.onPopupScreen(screen)
		root.quickSettingsOpen = true
		root.notificationsOpen = false
		root.mprisDetailOpen = false
		root.audioControlsOpen = false
		root.calendarOpen = false
		root.wifiHistoryOpen = false
		root.wallpaperSelectorOpen = false
	}

	function openNotifications(screen) {
		root.popupScreen = root.onPopupScreen(screen)
		root.notificationsOpen = true
		root.quickSettingsOpen = false
		root.mprisDetailOpen = false
		root.audioControlsOpen = false
		root.calendarOpen = false
		root.wifiHistoryOpen = false
		root.wallpaperSelectorOpen = false
	}

	function openMprisDetail(screen) {
		root.popupScreen = root.onPopupScreen(screen)
		root.mprisDetailOpen = true
		root.quickSettingsOpen = false
		root.notificationsOpen = false
		root.audioControlsOpen = false
		root.calendarOpen = false
		root.wifiHistoryOpen = false
		root.wallpaperSelectorOpen = false
	}

	function openAudioControls(screen) {
		root.popupScreen = root.onPopupScreen(screen)
		root.audioControlsOpen = true
		root.quickSettingsOpen = false
		root.notificationsOpen = false
		root.mprisDetailOpen = false
		root.calendarOpen = false
		root.wifiHistoryOpen = false
		root.wallpaperSelectorOpen = false
	}

	function openCalendar(screen) {
		root.popupScreen = root.onPopupScreen(screen)
		root.calendarOpen = true
		root.quickSettingsOpen = false
		root.notificationsOpen = false
		root.mprisDetailOpen = false
		root.audioControlsOpen = false
		root.wifiHistoryOpen = false
		root.wallpaperSelectorOpen = false
	}

	function openWallpaperSelector(screen) {
		root.popupScreen = root.onPopupScreen(screen)
		root.wallpaperSelectorOpen = true
		root.quickSettingsOpen = false
		root.notificationsOpen = false
		root.mprisDetailOpen = false
		root.audioControlsOpen = false
		root.calendarOpen = false
		root.wifiHistoryOpen = false
	}

	function closeAll() {
		root.quickSettingsOpen = false
		root.notificationsOpen = false
		root.mprisDetailOpen = false
		root.audioControlsOpen = false
		root.calendarOpen = false
		root.wifiHistoryOpen = false
		root.wallpaperSelectorOpen = false
	}

	// ---- notification history ----
	function addHistory(n) {
		if (!n) return
		for (const h of root.notificationHistory) {
			if (h.id === n.id) return
		}
		root.notificationHistory = root.notificationHistory.concat([{
			id: n.id,
			appName: n.appName || "Unknown",
			appIcon: n.appIcon || "",
			summary: n.summary || "",
			body: n.body || "",
			image: n.image || "",
			actions: [],
			// The live Notification object (if still alive) so the panel can
			// dismiss it on the daemon side too.
			real: n
		}])
		if (root.notificationHistory.length > 50) root.notificationHistory = root.notificationHistory.slice(-50)
	}

	function clearHistory() {
		root.notificationHistory = []
		root.toastClearTick++
	}

	// Bumped by clearHistory(); Toast.qml watches it and slides every visible
	// toast off to the right.
	property int toastClearTick: 0

	function removeHistoryById(id) {
		root.notificationHistory = root.notificationHistory.filter(h => h.id !== id)
	}

	// Dismiss one notification: closes it on the daemon (if it's still alive)
	// and removes it from the panel.
	function dismissHistory(id) {
		let real = null
		for (const h of root.notificationHistory) {
			if (h.id === id) { real = h.real; break }
		}
		if (real && real.dismiss) real.dismiss()
		root.removeHistoryById(id)
	}
}