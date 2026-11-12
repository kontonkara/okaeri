import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.launcher
import qs.services

// The dock, on every screen while Settings.dock.on: the apps it keeps,
// Settings.dock.pinned by their ids, and after them the others that have
// windows, in the order they came. A click on one goes to its window, to the
// next of them if it has the focus already, or launches it; the middle button
// launches it anew; the right one keeps it on the dock, or lets it go.
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

	function activate(app) {
		if (app.windows.length === 0) {
			if (app.entry)
				Apps.launch(app.entry);
			return;
		}
		const focused = app.windows.findIndex(window => window.is_focused);
		Niri.focusWindow(app.windows[(focused + 1) % app.windows.length].id);
	}

	function pin(id, wanted) {
		const rest = own.pinned.filter(other => other !== id);
		Settings.set("dock", "pinned", wanted ? rest.concat([id]) : rest);
	}

	IpcHandler {
		target: "dock"

		function toggle(): void {
			Settings.set("dock", "on", !docks.own.on);
		}
	}

	Variants {
		model: docks.own.on ? Quickshell.screens : []

		Dock {
			apps: docks.apps
			onActivated: app => docks.activate(app)
			onStarted: app => Apps.launch(app.entry)
			onPinned: (app, wanted) => docks.pin(app.id, wanted)
		}
	}
}
