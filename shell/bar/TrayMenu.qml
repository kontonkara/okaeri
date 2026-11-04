import QtQuick
import Quickshell
import qs
import qs.ui

// An app's menu under its icon, submenus in the same place with a way back.
// A click elsewhere closes it.
PopupWindow {
	id: popup

	// The menus above the one shown.
	property var parents: []

	function show(item, under) {
		anchor.item = under;
		parents = [];
		opener.menu = item.menu;
		visible = true;
		list.forceActiveFocus();
	}

	function enter(entry) {
		parents = parents.concat([opener.menu]);
		opener.menu = entry;
		list.currentIndex = -1;
	}

	function back() {
		opener.menu = parents[parents.length - 1];
		parents = parents.slice(0, -1);
		list.currentIndex = -1;
	}

	// Without the icon a theme lacks: Qt would draw its placeholder.
	function image(source) {
		const name = source.startsWith("image://icon/") ? source.slice(13).split("?")[0] : "";
		return !name || Quickshell.hasThemeIcon(name) ? source : "";
	}

	readonly property var rows: {
		const entries = opener.children ? opener.children.values : [];
		const rows = entries.map(entry => ({
			entry,
			separator: entry.isSeparator,
			// A menu's underscore marks its access key.
			text: entry.text.replace(/_(?!_)/g, "").replace(/__/g, "_"),
			image: popup.image(entry.icon),
			enabled: entry.enabled,
			check: entry.checkState === Qt.Checked,
			more: entry.hasChildren
		}));
		return parents.length ? [{ icon: "back", text: "Back", back: true }].concat(rows) : rows;
	}

	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.margins.bottom: -Theme.u(6)
	grabFocus: true
	color: "transparent"
	implicitWidth: card.width
	implicitHeight: card.height

	QsMenuOpener {
		id: opener
	}

	Card {
		id: card

		width: Theme.u(280)
		height: Math.min(list.contentHeight, Theme.u(480)) + padding * 2
		padding: Theme.u(6)
		color: Theme.colors.background

		List {
			id: list

			width: parent.width
			height: Math.min(contentHeight, Theme.u(480))
			model: popup.rows
			onActivated: (index, row) => {
				if (row.back) {
					popup.back();
				} else if (row.more) {
					popup.enter(row.entry);
				} else {
					row.entry.triggered();
					popup.visible = false;
				}
			}
			Keys.onEscapePressed: {
				if (popup.parents.length)
					popup.back();
				else
					popup.visible = false;
			}
		}
	}
}
