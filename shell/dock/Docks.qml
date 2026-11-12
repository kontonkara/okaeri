import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.launcher
import qs.services

// The dock, on every screen while Settings.dock.on, but for those
// Settings.dock.hideOn names: the apps it keeps, Settings.dock.pinned by their
// ids, and after them the others that have windows, in the order they came. A
// click on one goes to its window, to the next of them if it has the focus
// already, or launches it, and the wheel goes through its windows; the middle
// button launches it anew; the right one opens its menu; and one that's kept
// goes where it's dragged among those.
Scope {
	id: docks

	readonly property var own: Settings.dock
	// What's on it: { id, entry, windows }, the windows as they were opened.
	readonly property var apps: {
		const running = {};
		Niri.windows.slice().sort((a, b) => a.id - b.id).forEach(window => {
			const entry = Apps.entryOf(window.app_id || "");
			const id = entry ? entry.id : window.app_id || "";
			running[id] = running[id] ?? { id, entry, windows: [] };
			running[id].windows.push(window);
		});
		const kept = own.pinned.map(id => running[id] ?? { id, entry: Apps.find(id), windows: [] }).filter(app => app.entry || app.windows.length > 0);
		const others = Object.keys(running).filter(id => !own.pinned.includes(id)).map(id => running[id]);
		return kept.concat(others.sort((a, b) => a.windows[0].id - b.windows[0].id));
	}

	// To the window `by` on from the one in focus, the first if none is, or the
	// app itself if it has none.
	function activate(app, by) {
		if (app.windows.length === 0) {
			if (app.entry)
				Apps.launch(app.entry);
			return;
		}
		const count = app.windows.length;
		const focused = app.windows.findIndex(window => window.is_focused);
		Niri.focusWindow(app.windows[(((focused < 0 ? (by > 0 ? -1 : 0) : focused) + by) % count + count) % count].id);
	}

	// Past the next of those kept that are on the dock, `by` 1, or the one before.
	function move(id, by) {
		const shown = apps.map(app => app.id).filter(other => own.pinned.includes(other));
		const beside = shown[shown.indexOf(id) + by];
		if (!shown.includes(id) || !beside)
			return;
		const rest = own.pinned.filter(other => other !== id);
		rest.splice(rest.indexOf(beside) + (by > 0 ? 1 : 0), 0, id);
		Settings.set("dock", "pinned", rest);
	}

	IpcHandler {
		target: "dock"

		function toggle(): void {
			Settings.set("dock", "on", !docks.own.on);
		}
	}

	Variants {
		model: docks.own.on ? Quickshell.screens.filter(screen => !docks.own.hideOn.includes(screen.name)) : []

		Dock {
			id: one

			apps: docks.apps
			held: menu.shown && menu.screen === modelData
			onActivated: app => docks.activate(app, 1)
			onTurned: (app, by) => docks.activate(app, by)
			onStarted: app => Apps.launch(app.entry)
			onAsked: (app, along) => menu.showFor(app.id, one, along)
			onMoved: (app, by) => docks.move(app.id, by)
		}
	}

	DockMenu {
		id: menu

		apps: docks.apps
	}
}
