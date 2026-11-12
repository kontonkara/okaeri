pragma Singleton

import QtQuick
import Quickshell
import qs

// What the panel and its bar button share. Nothing here reaches for Wi-Fi or
// Bluetooth, so the bar doesn't start them: they come with the first opening.
Singleton {
	// The panel sets this.
	property bool open: false
	// The page that's open, by its name, and whether the keys opened it: the
	// keys then go on to it.
	property string unfolded: ""
	property bool keyed: false

	// The tile whose page of what else it can do is open, by a right click on it,
	// and the tiles the panel shows now, in their order.
	property string options: ""
	property var shown: []

	signal toggled
	// Someone wants the panel up at a page.
	signal asked(string page)
	// Something in it is done with the panel: it goes.
	signal leave

	// The page of what else tile `name` can do, and how it sits.
	function showOptions(name) {
		options = name;
		unfolded = "options";
	}

	// One place on among those shown, `by` 1, or with -1 one back: they swap.
	function moveTile(name, by) {
		const at = shown.indexOf(name);
		const other = shown[at + by];
		if (at < 0 || !other)
			return;
		const all = order.slice();
		all[all.indexOf(name)] = other;
		all[all.indexOf(other)] = name;
		Settings.set("control", "tiles", all);
	}

	// Into the place of tile `other`, the rest moving on to make room.
	function moveTileTo(name, other) {
		const all = order.filter(one => one !== name);
		const at = all.indexOf(other);
		if (at < 0)
			return;
		all.splice(order.indexOf(name) < order.indexOf(other) ? at + 1 : at, 0, name);
		Settings.set("control", "tiles", all);
	}

	function setWide(name, wanted) {
		const rest = Settings.control.wide.filter(other => other !== name);
		Settings.set("control", "wide", wanted ? rest.concat([name]) : rest);
	}

	function hideTile(name) {
		Settings.set("control", "hidden", Settings.control.hidden.filter(other => other !== name).concat([name]));
	}

	// The tiles there are, by their names, the user's own in Settings.control.custom
	// after the others, and all of them in Settings.control.tiles' order, the
	// ones it doesn't name after it.
	readonly property var builtIn: ["wifi", "bluetooth", "night", "awake", "power", "airplane", "vpn", "record", "hotspot"]
	readonly property var tiles: builtIn.concat(Settings.control.custom.map(own => own.name).filter(name => !builtIn.includes(name)))
	readonly property var order: Settings.control.tiles.filter(name => tiles.includes(name)).concat(tiles.filter(name => !Settings.control.tiles.includes(name)))

	function show(page) {
		asked(page);
	}

	function toggle() {
		toggled();
	}

	// Which of `names`, the tiles as they come, take a whole row: a wide one, and
	// one left alone in its row, before a wide one or at the end.
	function whole(names) {
		const result = {};
		let half = false;
		names.forEach((name, at) => {
			if (Settings.control.wide.includes(name)) {
				result[name] = true;
			} else if (half) {
				result[name] = false;
				half = false;
			} else {
				const next = names[at + 1];
				result[name] = next === undefined || Settings.control.wide.includes(next);
				half = !result[name];
			}
		});
		return result;
	}
}
