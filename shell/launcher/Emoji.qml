pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Emoji and a few symbols by their names, for the launcher's /emoji: emoji.json
// is Unicode's emoji-test.txt (© Unicode, Inc., under its terms of use), the
// fully-qualified ones up to Emoji 16.0 and without skin tones, and after them
// symbols a keyboard rarely has. One picked is typed into the window in focus,
// and copied too, for where typing doesn't reach. The last ones picked come
// first while nothing is asked for.
Singleton {
	id: emoji

	// The characters picked last, the newest first, kept in a file.
	property var recent: []
	readonly property int kept: 24

	// [character, name] each.
	readonly property var known: {
		try {
			return JSON.parse(data.text());
		} catch (error) {
			return [];
		}
	}

	// What has every word of `wanted` in its name: the one named so first, then
	// those whose names start with it, the shorter names before the longer.
	function search(wanted, limit) {
		const query = wanted.trim().toLowerCase();
		if (query === "") {
			const first = recent.map(character => known.find(([other]) => other === character)).filter(found => !!found);
			return first.concat(known.filter(([character]) => !recent.includes(character))).slice(0, limit);
		}
		const words = query.split(/\s+/).filter(word => word !== "");
		const rank = name => {
			const plain = name.replace(/ \(symbol\)$/, "");
			return plain === query ? 0 : plain.startsWith(query) ? 1 : 2;
		};
		return known.filter(([, name]) => words.every(word => name.includes(word))).map(([character, name]) => ({ character, name, rank: rank(name) })).sort((a, b) => a.rank - b.rank || a.name.length - b.name.length).slice(0, limit).map(({ character, name }) => [character, name]);
	}

	// Typed and copied, or with `only` just copied.
	function put(character, only) {
		Env.act(only ? "emoji copy" : "emoji", () => {
			Quickshell.execDetached(["wl-copy", "--", character]);
			if (!only)
				Quickshell.execDetached(["sh", "-c", 'sleep 0.2; exec wtype -- "$1"', "sh", character]);
		});
		recent = [character].concat(recent.filter(other => other !== character)).slice(0, kept);
		recentFile.setText(JSON.stringify(recent));
	}

	FileView {
		id: recentFile

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/emoji.json`
		printErrors: false
		onLoaded: {
			try {
				emoji.recent = [].concat(JSON.parse(text()));
			} catch (error) {
				console.warn(`okaeri: can't read ${path}: ${error.message}`);
			}
		}
	}

	FileView {
		id: data

		path: Quickshell.shellPath("launcher/emoji.json")
		blockLoading: true
	}
}
