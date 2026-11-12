import QtQuick
import Quickshell
import qs
import qs.launcher
import qs.services
import qs.ui

// What else an app on the dock can do, by its icon: its windows by name if it
// has more than one, a new one, what its entry offers besides, whether the
// dock keeps it, and closing what it has open.
Panel {
	id: menu

	// The dock's apps, and the id of the one this is of.
	property var apps: []
	property string appId: ""
	readonly property var app: apps.find(app => app.id === appId) ?? null
	readonly property var rows: {
		if (!app)
			return [];
		const name = app.entry?.name ?? app.id;
		const kept = Settings.dock.pinned.includes(app.id);
		const windows = app.windows.length > 1 ? app.windows.map(window => ({
			window,
			text: window.title || name,
			check: window.is_focused
		})) : [];
		const starts = app.entry ? [{ start: true, text: app.windows.length ? "New window" : "Open", icon: "plus" }].concat(Array.from(app.entry.actions).map(action => ({
			action,
			text: action.name,
			image: Apps.image(action.icon),
			icon: "apps"
		}))) : [];
		// Its windows on other workspaces than the one in focus.
		const here = Niri.workspaces.find(workspace => workspace.is_focused)?.id;
		const away = app.windows.filter(window => window.workspace_id !== here);
		if (away.length && here !== undefined)
			starts.push({ bringing: true, text: away.length > 1 ? `Bring its ${away.length} windows here` : "Bring it here", icon: "apps" });
		const rest = [{ keeping: true, keep: !kept, text: kept ? "Take off the dock" : "Keep on the dock", icon: "pin" }];
		if (app.windows.length)
			rest.push({ closing: true, text: app.windows.length > 1 ? `Close ${app.windows.length} windows` : "Close", icon: "close" });
		const line = [{ separator: true }];
		return windows.concat(windows.length ? line : [], starts, starts.length ? line : [], rest);
	}

	// By `dock`, where `along` its edge of the screen the app's icon is.
	function showFor(id, dock, along) {
		appId = id;
		edge = dock.at;
		off = dock.gap + dock.thick + Theme.u(6);
		middle = along;
		show(dock.screen);
	}

	align: "top"
	panelWidth: Theme.u(260)
	padding: Theme.u(6)

	onPanelOpened: {
		list.pointer = null;
		list.currentIndex = -1;
		list.forceActiveFocus();
	}

	// The app went from the dock.
	onAppChanged: {
		if (shown && !app)
			hide();
	}

	// Any panel takes a menu's place.
	Connections {
		target: Panels

		function onOpened(other) {
			if (other !== menu)
				menu.hide();
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
			const app = menu.app;
			menu.hide();
			if (row.window)
				Niri.focusWindow(row.window.id);
			else if (row.start)
				Apps.launch(app.entry);
			else if (row.action)
				Apps.launch(app.entry, row.action);
			else if (row.keeping)
				Apps.dock(app.id, row.keep);
			else if (row.bringing)
				app.windows.filter(window => window.workspace_id !== Niri.workspaces.find(workspace => workspace.is_focused)?.id).forEach(window => Niri.bringWindow(window.id));
			else if (row.closing)
				app.windows.forEach(window => Niri.closeWindow(window.id));
		}
	}
}
