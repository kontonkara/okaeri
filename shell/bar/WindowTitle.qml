import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// The title of the window in focus, while there's one, after its app's icon, cut
// off if it's long, and then whole under the pointer. On a bar at a side it runs
// down it.
Item {
	id: title

	readonly property var window: Niri.focusedWindow
	readonly property string text: window?.title ?? ""
	readonly property bool wanted: text !== ""
	readonly property bool upright: Settings.barSide
	// Its app's icon, "" for one the icon theme lacks. The entries load after the
	// first lookup: `values` has this come back when they're there.
	readonly property string picture: {
		const app = window?.app_id ?? "";
		const known = DesktopEntries.applications.values.length > 0;
		const name = (known && app ? DesktopEntries.heuristicLookup(app)?.icon : "") || app.toLowerCase();
		return !name ? "" : name.startsWith("/") ? Settings.url(name) : Quickshell.iconPath(name, true);
	}

	implicitWidth: upright ? line.height : line.width
	implicitHeight: upright ? line.width : line.height

	Row {
		id: line

		anchors.centerIn: parent
		spacing: Theme.u(6)
		rotation: title.upright ? 90 : 0

		IconImage {
			anchors.verticalCenter: parent.verticalCenter
			visible: title.picture !== ""
			source: title.picture
			implicitSize: Theme.u(16)
		}

		Text {
			id: words

			anchors.verticalCenter: parent.verticalCenter
			width: Math.min(implicitWidth, Theme.u(300))
			text: title.text
			textFormat: Text.PlainText
			maximumLineCount: 1
			color: Theme.colors.subtext
			elide: Text.ElideRight
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}
	}

	Tip {
		text: words.truncated ? title.text : ""
	}
}
