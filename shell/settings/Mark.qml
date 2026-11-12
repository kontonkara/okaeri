import QtQuick
import qs
import qs.ui

// Left of a line of the settings window that holds `holds`, "section.key" of
// Settings or "theme.key" of Theme: a dot while the window has that set over what
// the files say, and a click on it takes it back to them.
Item {
	id: mark

	required property string holds
	readonly property bool themed: holds.startsWith("theme.")
	readonly property string name: themed ? holds.slice(6) : holds
	readonly property bool set: holds !== "" && (themed ? Theme.owns([name]) : Settings.owns([name]))

	x: -Theme.u(11)
	anchors.verticalCenter: parent.verticalCenter
	width: Theme.u(8)
	height: width
	visible: set

	Rectangle {
		anchors.centerIn: parent
		width: Theme.u(6)
		height: width
		radius: Theme.round(height)
		color: Theme.colors.accent
	}

	MouseArea {
		anchors.fill: parent
		anchors.margins: -Theme.u(4)
		cursorShape: Qt.PointingHandCursor
		onClicked: {
			if (mark.themed)
				Theme.resetKeys([mark.name]);
			else
				Settings.resetSections([mark.name]);
		}
	}

	Tip {
		text: "Set here: a click takes it back to the config"
	}
}
