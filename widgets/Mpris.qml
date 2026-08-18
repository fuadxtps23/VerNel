import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// mpris - centered, rotated 90°. Shows "{player_icon} {dynamic}" like waybar,
// preferring the currently playing player. Left click opens the detail box.
Item {
	id: root

	width: Config.barWidth
	height: label.height
	visible: root.player != null

	readonly property var player: {
		// Ignore playerless shells like playerctld, which stay on the bus with
		// no track. A player counts if it's actually playing (some players
		// expose no title metadata at all) or it has a track loaded.
		let fallback = null
		for (const candidate of Mpris.players.values) {
			if (!candidate.isPlaying && !candidate.trackTitle) continue
			if (candidate.isPlaying) return candidate
			if (fallback === null) fallback = candidate
		}
		return fallback
	}

	property var screen: null
	property var host: null

	function playerIcon(p) {
		const key = p.desktopEntry.toLowerCase() + " " + p.identity.toLowerCase()
		if (key.includes("spotify")) return ""
		if (key.includes("firefox")) return ""
		if (key.includes("chromium")) return ""
		if (key.includes("mpv")) return "󰐹"
		if (key.includes("vlc")) return "󰕼"
		if (key.includes("kdeconnect")) return ""
		return ""
	}

	readonly property string text: {
		const p = root.player
		if (!p) return ""
		let dynamic = p.trackTitle || "Unknown Title"
		if (p.trackArtist) dynamic = `${p.trackArtist} - ${dynamic}`
		if (dynamic.length > 30) dynamic = dynamic.substring(0, 30) + "…"
		return `${root.playerIcon(p)} ${dynamic}`
	}

	HoverHighlight {
		anchors.fill: parent
		active: ma.containsMouse
		host: root.host
	}

	RotatedText {
		id: label
		anchors.centerIn: parent
		text: root.text
		color: Config.primary
	}

	MouseArea {
		id: ma
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
		enabled: root.player != null
		onClicked: {
			if (!root.player) return
			if (mouse.button === Qt.LeftButton) {
				if (ShellState.mprisDetailOpen) ShellState.closeAll()
				else ShellState.openMprisDetail(root.screen)
			}
			else if (mouse.button === Qt.RightButton) root.player.next()
			else if (mouse.button === Qt.MiddleButton) root.player.togglePlaying()
		}
		onWheel: {
			if (!root.player || !root.player.volumeSupported) return
			const delta = wheel.angleDelta.y > 0 ? 0.01 : -0.01
			root.player.volume = Math.max(0, Math.min(1, root.player.volume + delta))
		}
	}
}