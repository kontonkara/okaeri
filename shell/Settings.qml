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
	readonly property var hooks: Object.assign({}, defaults.hooks, user.hooks, own.hooks)
	readonly property var locks: Object.assign({}, defaults.locks, user.locks, own.locks)
	readonly property var profile: Object.assign({}, defaults.profile, user.profile, own.profile)
	readonly property var nightLight: Object.assign({}, defaults.nightLight, user.nightLight, own.nightLight)
	readonly property var system: Object.assign({}, defaults.system, user.system, own.system)
	readonly property var network: Object.assign({}, defaults.network, user.network, own.network)
	readonly property var bluetooth: Object.assign({}, defaults.bluetooth, user.bluetooth, own.bluetooth)
	readonly property var media: Object.assign({}, defaults.media, user.media, own.media)
	readonly property var notifications: Object.assign({}, defaults.notifications, user.notifications, own.notifications)
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

	// Whether `screen` has a bar: Settings.bar.hideOn names those that don't.
	function barOn(screen) {
		return !screen || !bar.hideOn.includes(screen.name);
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

	function save() {
		ownFile.setText(JSON.stringify(own, null, "\t") + "\n");
	}
}
