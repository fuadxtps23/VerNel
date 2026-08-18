import QtQuick

// A single line of text rotated 90° (reads top-to-bottom). The item is
// automatically sized to the rotated text's box:
// width = text height, height = text length.
Item {
	id: root

	property string text: ""
	property color color: Config.primary
	property int pixelSize: Config.pixelSize
	property bool bold: true

	width: label.contentHeight
	height: label.contentWidth

	Text {
		id: label
		anchors.centerIn: parent
		text: root.text
		color: root.color
		rotation: 90
		font {
			family: Config.fontFamily
			pixelSize: root.pixelSize
			bold: root.bold
		}
	}
}