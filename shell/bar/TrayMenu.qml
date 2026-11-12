import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// An app's menu under its icon, submenus in the same place with a way back.
// It's a panel and not a popup: a popup gets the keys through the surface it's
// on, and the bar leaves them to the window in focus.
Panel {
	id: menu

	// The menus on the way to the one shown, from the app's own on.
	property var path: []

	function showFor(item, under) {
		middle = Panels.middleOf(under);
		path = [item.menu];
		show(under.QsWindow.window.screen);
	}

	function enter(entry) {
		path = path.concat([entry]);
	}

	function back() {
		path = path.slice(0, -1);
	}

	// Without the icon a theme lacks: Qt would draw its placeholder.
	function image(source) {
		const name = source.startsWith("image://icon/") ? source.slice(13).split("?")[0] : "";
		return !name || Quickshell.hasThemeIcon(name) ? source : "";
	}

	readonly property var rows: {
		const opener = openers.instances[openers.instances.length - 1];
		const entries = opener?.children ? opener.children.values : [];
		const rows = entries.map(entry => ({
			entry,
			separator: entry.isSeparator,
			// A menu's underscore marks its access key.
			text: entry.text.replace(/_(?!_)/g, "").replace(/__/g, "_"),
			image: menu.image(entry.icon),
			enabled: entry.enabled,
			check: entry.checkState === Qt.Checked,
			more: entry.hasChildren
		}));
		return path.length > 1 ? [{ icon: "back", text: "Back", back: true }].concat(rows) : rows;
	}

	align: "top"
	panelWidth: Theme.u(280)
	padding: Theme.u(6)

	onPanelOpened: {
		list.pointer = null;
		list.forceActiveFocus();
	}

	// Closed for the app too: it fills a menu as that opens.
	onVisibleChanged: {
		if (!visible)
			path = [];
	}

	// Its app went away. A moment on: putting it away changes the rows again.
	onRowsChanged: {
		if (shown && !openers.instances[0]?.menu)
			Qt.callLater(() => {
				if (menu.shown && !openers.instances[0]?.menu)
					menu.hide();
			});
	}

	// Any panel takes a menu's place.
	Connections {
		target: Panels

		function onOpened(other) {
			if (other !== menu)
				menu.hide();
		}
	}

	// One for each on the way: a menu that nobody holds open can take what's in
	// it away, and the submenu shown with it. The app's own does.
	Variants {
		id: openers

		model: menu.path

		QsMenuOpener {
			required property var modelData

			menu: modelData
		}
	}

	List {
		id: list

		width: parent.width
		height: Math.min(contentHeight, Theme.u(480), menu.room)
		focus: true
		model: menu.rows
		onActivated: (index, row) => {
			// The rows still take clicks as the panel fades: a double click does.
			if (!menu.shown)
				return;
			if (row.back) {
				menu.back();
			} else if (row.more) {
				menu.enter(row.entry);
			} else {
				Env.act(`tray menu ${index}`, () => row.entry.triggered());
				menu.hide();
			}
		}
		Keys.onEscapePressed: {
			if (menu.path.length > 1)
				menu.back();
			else
				menu.hide();
		}
	}
}
