pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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
	// so an id counts without it first, and in full last.
	readonly property var known: !scanned ? [] : DesktopEntries.applications.values.filter(entry => !entry.noDisplay).map(entry => ({
		entry,
		texts: [[entry.name], [entry.genericName], Array.from(entry.keywords), [entry.id.replace(/^[a-z]+\./i, "")], [entry.id]]
			.map(texts => texts.map(text => text.toLowerCase()))
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
	function score(query, app) {
		let best = 0;
		app.texts.forEach((texts, rank) => {
			for (const text of texts) {
				const level = fit(query, text);
				if (level)
					best = Math.max(best, level * 4 - rank);
			}
		});
		return best;
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
	// rest. Without a query that's all the apps.
	function search(query) {
		const wanted = query.trim().toLowerCase();
		const found = [];
		for (const app of known) {
			const points = wanted ? score(wanted, app) : 1;
			if (points)
				found.push({ entry: app.entry, points, times: launches[app.entry.id] || 0 });
		}
		found.sort((a, b) => b.points - a.points || b.times - a.times || a.entry.name.localeCompare(b.entry.name));
		return found.slice(0, limit).map(({ entry }) => {
			const source = image(entry.icon);
			return {
				entry,
				text: entry.name,
				subtext: entry.genericName || entry.comment,
				image: source,
				icon: "apps"
			};
		});
	}

	// What runs a terminal app: $TERMINAL, or the first terminal of the apps.
	function terminal() {
		const own = Quickshell.env("TERMINAL");
		const app = known.find(app => app.entry.categories.includes("TerminalEmulator"));
		return own ? [own] : app ? app.entry.command : ["xdg-terminal-exec"];
	}

	function launch(entry) {
		Env.act(`launch ${entry.id}`, () => {
			// execute() doesn't look at this.
			if (entry.runInTerminal) {
				Quickshell.execDetached({
					command: [...terminal(), "-e", ...entry.command],
					workingDirectory: entry.workingDirectory
				});
			} else {
				entry.execute();
			}
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
