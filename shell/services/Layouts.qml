pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Whole layouts of the shell, a click each on the Look page: where the bar is
// and how it looks, what's on it, and the dock, over what was set before. The
// last one taken can be taken back for as long as the shell runs.
Singleton {
	id: layouts

	// What the bar has where nothing says otherwise.
	readonly property var right: ["privacy", "recording", "cast", "units", "tray", "notifications", "clipboard", "battery", "control"]
	// Each: its name, what it shows as, and what it sets: of the settings by
	// section, { bar, dock }, and of the theme.
	readonly property var all: [
		{
			name: "top",
			text: "A bar on top",
			settings: {
				bar: { position: "top", look: "whole", autoHide: false, left: ["workspaces", "media"], center: ["clock"], right: right, screens: {} },
				dock: { on: false }
			},
			theme: { barMargin: 4 }
		},
		{
			name: "islands",
			text: "Islands",
			settings: {
				bar: { position: "top", look: "islands", autoHide: false, left: ["workspaces", "media"], center: ["clock"], right: right, screens: {} },
				dock: { on: false }
			},
			theme: { barMargin: 8 }
		},
		{
			name: "capsules",
			text: "Capsules",
			settings: {
				bar: { position: "top", look: "capsules", autoHide: false, left: ["workspaces", "media"], center: ["clock"], right: right, screens: {} },
				dock: { on: false }
			},
			theme: { barMargin: 6 }
		},
		{
			name: "dock",
			text: "A bar and a dock",
			settings: {
				bar: { position: "top", look: "whole", autoHide: false, left: ["workspaces", "title"], center: ["clock"], right: right, screens: {} },
				dock: { on: true, position: "bottom", launcher: "start", smartHide: true, autoHide: false, screens: {} }
			},
			theme: { barMargin: 4 }
		},
		{
			name: "panel",
			text: "A panel below",
			settings: {
				bar: { position: "bottom", look: "whole", autoHide: false, left: ["launcher", "workspaces", "title"], center: [], right: ["privacy", "recording", "cast", "units", "tray", "notifications", "clipboard", "volume", "network", "battery", "clock", "control"], screens: {} },
				dock: { on: false }
			},
			theme: { barMargin: 0 }
		},
		{
			name: "side",
			text: "A bar at the side",
			settings: {
				bar: { position: "left", look: "whole", autoHide: false, left: ["launcher", "workspaces"], center: ["clock"], right: ["tray", "notifications", "battery", "control"], screens: {} },
				dock: { on: false }
			},
			theme: { barMargin: 4 }
		},
		{
			name: "quiet",
			text: "Out of the way",
			settings: {
				bar: { position: "top", look: "islands", autoHide: true, left: ["workspaces"], center: ["clock"], right: ["notifications", "battery", "control"], screens: {} },
				dock: { on: false }
			},
			theme: { barMargin: 6 }
		}
	]
	// What the last one taken changed, as it was: to take it back.
	property var before: null
	// The one things are as now, or "".
	readonly property string current: {
		const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
		const found = all.find(layout => Object.keys(layout.settings).every(section => Object.keys(layout.settings[section]).every(key => same(Settings[section][key], layout.settings[section][key]))) && Object.keys(layout.theme).every(key => same(Theme.values[key], layout.theme[key])));
		return found?.name ?? "";
	}

	function find(name) {
		return all.find(layout => layout.name === name) ?? null;
	}

	// Layout `name` over what's set, and what it changes kept to take it back.
	function take(name) {
		const layout = find(name);
		if (!layout)
			return false;
		const settings = {};
		Object.keys(layout.settings).forEach(section => {
			settings[section] = {};
			Object.keys(layout.settings[section]).forEach(key => settings[section][key] = Settings.own[section]?.[key]);
		});
		const theme = {};
		Object.keys(layout.theme).forEach(key => theme[key] = Theme.own[key]);
		before = { settings, theme };
		Settings.setAll(layout.settings);
		Theme.setAll(layout.theme);
		return true;
	}

	// Back to how things were before the last one was taken.
	function back() {
		if (!before)
			return;
		Settings.setAll(before.settings);
		Theme.setAll(before.theme);
		before = null;
	}

	// `okaeri layouts list`, with a star by the one things are as, `take <name>`
	// and `back`.
	IpcHandler {
		target: "layouts"

		function list(): string {
			return layouts.all.map(layout => layout.name === layouts.current ? `${layout.name} *` : layout.name).join("\n");
		}

		function take(name: string): string {
			return layouts.take(name) ? "" : `No layout "${name}": ${layouts.all.map(layout => layout.name).join(", ")}`;
		}

		function back(): void {
			layouts.back();
		}
	}
}
