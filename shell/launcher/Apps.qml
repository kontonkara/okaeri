pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// The apps there are, what a search finds of them, and how often each was
// launched, kept in okaeri/launches.json of the state directory.
Singleton {
	id: apps

	// Rows a search gives at most: past the first few nobody reads on, and each
	// keystroke builds them anew.
	readonly property int limit: 50

	// Times launched, by id.
	property var launches: ({})

	// The first scan is over: until then the apps come in one by one, and each
	// would make `known` anew.
	property bool scanned: false

	// What a search goes through, in lower case once and not at each keystroke:
	// `texts` in the order they count. A reverse-DNS id's first part names no app,
	// so an id counts without it first, and in full last. `actions` are what else
	// the app can do, each with its name the same way.
	readonly property var known: !scanned ? [] : DesktopEntries.applications.values.filter(entry => !entry.noDisplay).map(entry => ({
		entry,
		texts: [[entry.name], [entry.genericName], Array.from(entry.keywords), [entry.id.replace(/^[a-z]+\./i, "")], [entry.id]]
			.map(texts => texts.map(text => text.toLowerCase())),
		actions: Array.from(entry.actions).map(action => ({ action, name: action.name.toLowerCase() }))
	}))

	// What image() found for each file: it takes reading the file, and each
	// keystroke would read them all.
	property var iconFiles: ({})

	// How `query` fits `text`, both in lower case: 4 it's all of it, 3 it starts
	// it, 2 it starts a word of it, 1 its letters are in it in that order, 0 no.
	function fit(query, text) {
		if (text === query)
			return 4;
		if (text.startsWith(query))
			return 3;
		for (let at = text.indexOf(query); at > 0; at = text.indexOf(query, at + 1)) {
			if (" -_./".includes(text[at - 1]))
				return 2;
		}
		let found = 0;
		for (let at = 0; at < text.length && found < query.length; at++) {
			if (text[at] === query[found])
				found++;
		}
		return found === query.length ? 1 : 0;
	}

	// The best fit of all an app's texts; of two alike, the one that counts more.
	// All of a text is out of reach of what weight() adds to the others.
	function score(query, app) {
		let best = 0;
		app.texts.forEach((texts, rank) => {
			for (const text of texts) {
				const level = fit(query, text);
				if (level)
					best = Math.max(best, (level === 4 ? 24 : level * 4) - rank);
			}
		});
		return best;
	}

	// What launches add to a fit: nothing for the first few, then enough to pass a
	// better one.
	function weight(times) {
		return Math.max(0, Math.min(Math.log2(1 + times) - 1, 6));
	}

	// An icon of the theme or a file, "" for one that isn't there.
	function image(icon) {
		if (!icon.startsWith("/"))
			return Quickshell.iconPath(icon, true);
		if (!(icon in iconFiles)) {
			// A file that can't be read leaves the data of the one before.
			iconFile.path = "";
			iconFile.path = icon;
			iconFiles[icon] = iconFile.data().byteLength ? `file://${icon.split("/").map(encodeURIComponent).join("/")}` : "";
		}
		return iconFiles[icon];
	}

	// Rows for List, the best first, the most launched of equals before the
	// rest. Without a query that's all the apps but the hidden, the pinned first.
	// With two letters or more, and Settings.launcher.actions on, an app's own
	// actions come up too by their names, as New Private Window does, each a little
	// under the app with the same fit: that one is what's more often meant. Only
	// what starts a word counts for them, or most queries would bring up every
	// app's New Window.
	function search(query) {
		const wanted = query.trim().toLowerCase();
		const { pinned, hidden, usage, actions } = Settings.launcher;
		const found = [];
		for (const app of known) {
			const points = hidden.includes(app.entry.id) ? 0 : wanted ? score(wanted, app) : 1;
			if (points) {
				const times = usage ? launches[app.entry.id] || 0 : 0;
				const pin = wanted ? -1 : pinned.indexOf(app.entry.id);
				found.push({ entry: app.entry, points: points + weight(times), times, pin: pin < 0 ? pinned.length : pin });
			}
			if (!actions || wanted.length < 2 || hidden.includes(app.entry.id))
				continue;
			for (const own of app.actions) {
				const level = fit(wanted, own.name);
				if (level > 1)
					found.push({ entry: app.entry, action: own.action, points: (level === 4 ? 24 : level * 4) - 0.5, times: 0, pin: pinned.length });
			}
		}
		found.sort((a, b) => a.pin - b.pin || b.points - a.points || b.times - a.times || a.entry.name.localeCompare(b.entry.name));
		return found.slice(0, limit).map(({ entry, action }) => {
			if (action)
				return { entry, action, text: action.name, subtext: entry.name, image: (action.icon && image(action.icon)) || image(entry.icon), icon: "apps" };
			const source = image(entry.icon);
			return {
				entry,
				text: entry.name,
				subtext: entry.genericName || entry.comment,
				image: source,
				icon: "apps",
				mark: pinned.includes(entry.id) ? "pin" : ""
			};
		});
	}

	// The app with this id, if it's still there.
	function find(id) {
		return known.find(app => app.entry.id === id)?.entry ?? null;
	}

	function pin(id, wanted) {
		const others = Settings.launcher.pinned.filter(other => other !== id);
		Settings.set("launcher", "pinned", wanted ? others.concat([id]) : others);
	}

	function hide(id, wanted) {
		const others = Settings.launcher.hidden.filter(other => other !== id);
		Settings.set("launcher", "hidden", wanted ? others.concat([id]) : others);
	}

	// The app a window is of, by the id the window gives: an entry's own, in any
	// case, or what the entries make of it.
	function entryOf(id) {
		if (!id)
			return null;
		const own = known.find(app => app.entry.id.toLowerCase() === id.toLowerCase());
		return own ? own.entry : DesktopEntries.heuristicLookup(id);
	}

	// One place up among those pinned to the launcher, or with "dock" kept on that.
	function raise(where, id) {
		const pinned = Settings[where].pinned.slice();
		const at = pinned.indexOf(id);
		if (at < 1)
			return;
		pinned.splice(at - 1, 2, id, pinned[at - 1]);
		Settings.set(where, "pinned", pinned);
	}

	// On the dock, or off it.
	function dock(id, wanted) {
		const others = Settings.dock.pinned.filter(other => other !== id);
		Settings.set("dock", "pinned", wanted ? others.concat([id]) : others);
	}

	// The picture of the app with this id in a window, "" if there's none.
	function imageOf(id) {
		const app = known.find(app => app.entry.id.toLowerCase() === (id || "").toLowerCase());
		return app ? image(app.entry.icon) : "";
	}

	// What runs a terminal app: $TERMINAL, or the first terminal of the apps.
	function terminal() {
		const own = Quickshell.env("TERMINAL");
		const app = known.find(app => app.entry.categories.includes("TerminalEmulator"));
		return own ? [own] : app ? app.entry.command : ["xdg-terminal-exec"];
	}

	// The app, or `action`, one of its own, for what else it can do.
	function launch(entry, action) {
		Env.act(action ? `launch ${entry.id} ${action.id}` : `launch ${entry.id}`, () => {
			// execute() would have it in the shell's scope, and doesn't look at this.
			const line = (action ?? entry).command;
			const command = entry.runInTerminal ? [...terminal(), "-e", ...line] : line;
			const directory = entry.workingDirectory;
			Niri.spawn(directory ? ["sh", "-c", 'cd "$0" && exec "$@"', directory, ...command] : command);
		});
		launches = Object.assign({}, launches, { [entry.id]: (launches[entry.id] || 0) + 1 });
		file.setText(JSON.stringify(launches));
	}

	// An icon's first lookup is what's slow: here, not in the first opening.
	onKnownChanged: {
		iconFiles = {};
		search("");
	}

	// After a reload there's no scan to wait for.
	Component.onCompleted: scanned = DesktopEntries.applications.values.length > 0

	// This says a scan ended, not that it found anything: one runs when anything
	// comes up in the directories above the apps, so `known` can't go by it.
	Connections {
		target: DesktopEntries

		function onApplicationsChanged() {
			apps.scanned = true;
		}
	}

	FileView {
		id: iconFile

		blockLoading: true
		printErrors: false
	}

	FileView {
		id: file

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/launches.json`
		printErrors: false
		onLoaded: {
			try {
				apps.launches = Object.assign({}, JSON.parse(text()));
			} catch (error) {
				console.warn(`okaeri: can't read ${path}: ${error.message}`);
			}
		}
	}
}
