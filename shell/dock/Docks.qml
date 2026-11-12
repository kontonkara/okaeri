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

	// What's on the dock of screen `output`: as `apps`, with only the windows
	// Settings.dock.windows has it show, "all" of them, those on its "screen", or
	// with "pinned" none of other apps than those it keeps.
	function appsOn(output) {
		if (own.windows !== "screen" && own.windows !== "pinned")
			return apps;
		const here = own.windows === "screen" ? Niri.on(output).map(workspace => workspace.id) : null;
		return apps.map(app => here ? Object.assign({}, app, { windows: app.windows.filter(window => here.includes(window.workspace_id)) }) : app).filter(app => own.pinned.includes(app.id) || (own.windows === "screen" && app.windows.length > 0));
	}

	// To the window `by` on from the one in focus, the first if none is, or the
	// app itself if it has none.
	function activate(app, by) {
		if (app.windows.length === 0) {
			if (app.entry)
				docks.launch(app);
			return;
		}
		const count = app.windows.length;
		const focused = app.windows.findIndex(window => window.is_focused);
		Niri.focusWindow(app.windows[(((focused < 0 ? (by > 0 ? -1 : 0) : focused) + by) % count + count) % count].id);
	}

	// What starts from it now: { id, count, at }, the windows it had then and when.
	// It's starting until it has more, or for eight seconds at most.
	property var starting: []
	readonly property var launching: starting.map(one => one.id)

	function launch(app) {
		Apps.launch(app.entry);
		starting = starting.filter(one => one.id !== app.id).concat([{ id: app.id, count: app.windows.length, at: Date.now() }]);
		// For tests: what hops.
		console.info("okaeri: dock: launching", app.id);
	}

	function settle() {
		const now = Date.now();
		const left = starting.filter(one => now - one.at < 8000 && (apps.find(app => app.id === one.id)?.windows.length ?? 0) <= one.count);
		if (left.length !== starting.length)
			starting = left;
	}

	onAppsChanged: settle()

	Timer {
		interval: 1000
		running: docks.starting.length > 0
		repeat: true
		onTriggered: docks.settle()
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

		// Keep an app on it, by its id as its desktop file has it, or let it go.
		function pin(id: string): void {
			Apps.dock(id, true);
		}

		function unpin(id: string): void {
			Apps.dock(id, false);
		}
	}

	Variants {
		model: docks.own.on ? Quickshell.screens.filter(screen => !docks.own.hideOn.includes(screen.name)) : []

		Dock {
			id: one

			apps: docks.appsOn(modelData.name)
			held: menu.shown && menu.screen === modelData
			onActivated: app => docks.activate(app, 1)
			onTurned: (app, by) => docks.activate(app, by)
			launching: docks.launching
			onStarted: app => docks.launch(app)
			onAsked: (app, along) => menu.showFor(app.id, one, along)
			onMoved: (app, by) => docks.move(app.id, by)
		}
	}

	DockMenu {
		id: menu

		apps: docks.apps
	}
}
