pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the shell does, as Theme is how it looks: settings.json (it has every
// key), the user's okaeri/settings.json over it, which takes effect as it's
// saved, and over those what the settings window changed, in a file of the shell's
// own: the user's can be read-only. Sections merge key by key.
Singleton {
	id: settings

	// Someone wants the settings window, or it open on what `query` finds.
	signal asked
	signal sought(string query)
	// The settings window at a page, by its name in the menu.
	signal pageWanted(string name)
	// The settings window at the Bar page, with a part of the bar chosen there.
	signal barPartWanted(string name)

	FileView {
		id: defaultsFile

		path: Quickshell.shellPath("settings.json")
		blockLoading: true
	}

	FileView {
		id: userFile

		path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/okaeri/settings.json`
		blockLoading: true
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: settings.user = Theme.parse(text(), path)
		onLoadFailed: settings.user = {}
	}

	FileView {
		id: ownFile

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/settings.json`
		blockLoading: true
		printErrors: false
		onLoaded: settings.own = Theme.parse(text(), path)
		onLoadFailed: settings.own = {}
	}

	readonly property var defaults: Theme.parse(defaultsFile.text(), defaultsFile.path)
	property var user: ({})
	property var own: ({})

	readonly property var session: Object.assign({}, defaults.session, user.session, own.session)
	readonly property var idle: Object.assign({}, defaults.idle, user.idle, own.idle)
	readonly property var battery: Object.assign({}, defaults.battery, user.battery, own.battery)
	readonly property var control: Object.assign({}, defaults.control, user.control, own.control)
	readonly property var launcher: Object.assign({}, defaults.launcher, user.launcher, own.launcher)
	readonly property var clipboard: Object.assign({}, defaults.clipboard, user.clipboard, own.clipboard)
	readonly property var audio: Object.assign({}, defaults.audio, user.audio, own.audio)
	readonly property var osd: Object.assign({}, defaults.osd, user.osd, own.osd)
	readonly property var sounds: Object.assign({}, defaults.sounds, user.sounds, own.sounds)
	readonly property var wallpaper: Object.assign({}, defaults.wallpaper, user.wallpaper, own.wallpaper)
	readonly property var tray: Object.assign({}, defaults.tray, user.tray, own.tray)
	readonly property var bar: Object.assign({}, defaults.bar, user.bar, own.bar)
	readonly property var clock: Object.assign({}, defaults.clock, user.clock, own.clock)
	readonly property var workspaces: Object.assign({}, defaults.workspaces, user.workspaces, own.workspaces)
	readonly property var weather: Object.assign({}, defaults.weather, user.weather, own.weather)
	readonly property var display: Object.assign({}, defaults.display, user.display, own.display)
	readonly property var recording: Object.assign({}, defaults.recording, user.recording, own.recording)
	readonly property var dock: Object.assign({}, defaults.dock, user.dock, own.dock)
	readonly property var hooks: Object.assign({}, defaults.hooks, user.hooks, own.hooks)
	readonly property var locks: Object.assign({}, defaults.locks, user.locks, own.locks)
	readonly property var profile: Object.assign({}, defaults.profile, user.profile, own.profile)
	readonly property var nightLight: Object.assign({}, defaults.nightLight, user.nightLight, own.nightLight)
	readonly property var system: Object.assign({}, defaults.system, user.system, own.system)
	readonly property var network: Object.assign({}, defaults.network, user.network, own.network)
	readonly property var hotspot: Object.assign({}, defaults.hotspot, user.hotspot, own.hotspot)
	readonly property var bluetooth: Object.assign({}, defaults.bluetooth, user.bluetooth, own.bluetooth)
	readonly property var media: Object.assign({}, defaults.media, user.media, own.media)
	readonly property var notifications: Object.assign({}, defaults.notifications, user.notifications, own.notifications)
	readonly property var game: Object.assign({}, defaults.game, user.game, own.game)
	readonly property var drives: Object.assign({}, defaults.drives, user.drives, own.drives)
	readonly property var desktop: Object.assign({}, defaults.desktop, user.desktop, own.desktop)
	readonly property var plugins: Object.assign({}, defaults.plugins, user.plugins, own.plugins)
	readonly property var language: Object.assign({}, defaults.language, user.language, own.language)
	readonly property var visualizer: Object.assign({}, defaults.visualizer, user.visualizer, own.visualizer)
	readonly property var updates: Object.assign({}, defaults.updates, user.updates, own.updates)
	readonly property var pomodoro: Object.assign({}, defaults.pomodoro, user.pomodoro, own.pomodoro)
	readonly property var screenshots: Object.assign({}, defaults.screenshots, user.screenshots, own.screenshots)
	// Where the wallpapers are to pick from: the folder set, or where the wallpaper is.
	readonly property string pictures: wallpaper.folder || wallpaper.path.replace(/\/[^/]*$/, "") || `${Quickshell.env("HOME")}/Pictures`

	function set(section, key, value) {
		own = Object.assign({}, own, { [section]: Object.assign({}, own[section], { [key]: value }) });
		save();
	}

	// Where the panel of a part of the bar opens: the side the part is on, or the
	// right if it's not on the bar.
	function corner(part) {
		return bar.left.includes(part) ? "top-left" : bar.center.includes(part) ? "top" : "top-right";
	}

	// Whether a name on the bar is a separator or a space: "separator",
	// "separator 2", "space" and on, as many as there are.
	function spacer(name) {
		return /^(separator|space)( [0-9]+)?$/.test(name);
	}

	// Whether `screen` has a bar: Settings.bar.hideOn names those that don't.
	function barOn(screen) {
		return !screen || !bar.hideOn.includes(screen.name);
	}

	// What lane `lane` of the bar on screen `name` has: its own, where it has lanes
	// of its own in bar.screens, or else every screen's.
	function laneOf(name, lane) {
		return (name ? bar.screens?.[name]?.[lane] : null) ?? bar[lane];
	}

	// Lane `lane` of the bar on screen `name`, or with "" every screen's. A screen
	// that comes to have one lane of its own has all three, from every screen's.
	function setLane(name, lane, parts) {
		if (!name) {
			set("bar", lane, parts);
			return;
		}
		const all = Object.assign({}, bar.screens);
		all[name] = Object.assign({ left: bar.left, center: bar.center, right: bar.right }, all[name], { [lane]: parts });
		set("bar", "screens", all);
	}

	// The dock of screen `name`: every screen's settings, with what that screen has
	// of its own in dock.screens over them.
	function dockOf(name) {
		return Object.assign({}, dock, (name ? dock.screens?.[name] : null) ?? {});
	}

	// A setting of the dock of screen `name`, or with "" of every screen's.
	function setDock(name, key, value) {
		if (!name) {
			set("dock", key, value);
			return;
		}
		const all = Object.assign({}, dock.screens);
		all[name] = Object.assign({}, all[name], { [key]: value });
		set("dock", "screens", all);
	}

	// A screen's dock like every other again.
	function dropDock(name) {
		const all = Object.assign({}, dock.screens);
		delete all[name];
		set("dock", "screens", all);
	}

	// A screen's bar like every other again.
	function dropLanes(name) {
		const all = Object.assign({}, bar.screens);
		delete all[name];
		set("bar", "screens", all);
	}

	// Every lane of every bar as `change` makes it of what it has.
	function eachLane(change) {
		const lanes = ["left", "center", "right"];
		lanes.forEach(lane => {
			const next = change(bar[lane]);
			if (next.join() !== bar[lane].join())
				set("bar", lane, next);
		});
		const all = {};
		Object.keys(bar.screens ?? {}).forEach(name => {
			all[name] = {};
			lanes.forEach(lane => all[name][lane] = change(bar.screens[name][lane] ?? bar[lane]));
		});
		if (JSON.stringify(all) !== JSON.stringify(bar.screens ?? {}))
			set("bar", "screens", all);
	}

	// Where the bars are on their screens: "top", "bottom", "left" or "right".
	readonly property string barAt: ["bottom", "left", "right"].includes(bar.position) ? bar.position : "top"
	readonly property bool barBelow: barAt === "bottom"
	// At a side, where it's narrow and its parts stand one over another.
	readonly property bool barSide: barAt === "left" || barAt === "right"

	// How far what opens on `screen` stays from each of its edges: clear of its
	// bar on the side that has it, and off the edge on the others.
	function inset(screen, side) {
		return barOn(screen) && barAt === side ? Theme.below : Theme.edge;
	}

	function top(screen) {
		return inset(screen, "top");
	}

	function bottom(screen) {
		return inset(screen, "bottom");
	}

	function left(screen) {
		return inset(screen, "left");
	}

	function right(screen) {
		return inset(screen, "right");
	}

	// `path` as a URL, with what would mean something else in one kept as a name.
	function url(path) {
		return path ? `file://${encodeURI(path).replace(/[?#]/g, encodeURIComponent)}` : "";
	}

	// Back to what the files say.
	function reset() {
		own = {};
		save();
	}

	// Whether the shell's own file has any of `names` set: sections, or single
	// keys of one as "battery.warning", where a section is on more than one page of
	// the settings window.
	function owns(names) {
		return names.some(name => {
			const [section, key] = name.split(".");
			const keys = Object.keys(own[section] ?? {});
			return key === undefined ? keys.length > 0 : keys.includes(key);
		});
	}

	// Back to what the files say for those alone, as a page of the settings window
	// has them, and the rest as it was set. A section left with nothing goes too.
	function resetSections(names) {
		if (!owns(names))
			return;
		const kept = Object.assign({}, own);
		names.forEach(name => {
			const [section, key] = name.split(".");
			if (key === undefined) {
				delete kept[section];
				return;
			}
			const rest = Object.assign({}, kept[section]);
			delete rest[key];
			if (Object.keys(rest).length > 0)
				kept[section] = rest;
			else
				delete kept[section];
		});
		own = kept;
		save();
	}

	// What the files say for a key, without what the settings window set.
	function inFiles(section, key) {
		return Object.assign({}, defaults[section], user[section])[key];
	}

	// A list of names that goes by what's in it, as those of what's left out: set,
	// unless it's what the files have, and then the window's own goes.
	function setNames(section, key, names) {
		const files = (inFiles(section, key) ?? []).slice().sort().join("\n");
		if (names.slice().sort().join("\n") === files)
			resetSections([`${section}.${key}`]);
		else
			set(section, key, names);
	}

	function save() {
		ownFile.setText(JSON.stringify(own, null, "\t") + "\n");
	}
}
