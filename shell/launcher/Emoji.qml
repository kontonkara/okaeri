pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Emoji and a few symbols by their names, for the launcher's /emoji: emoji.json
// is Unicode's emoji-test.txt (© Unicode, Inc., under its terms of use), the
// fully-qualified ones up to Emoji 16.0 and without skin tones, and after them
// symbols a keyboard rarely has. One picked is typed into the window in focus,
// and copied too, for where typing doesn't reach.
Singleton {
	id: emoji

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
		const words = query.split(/\s+/).filter(word => word !== "");
		const rank = name => {
			const plain = name.replace(/ \(symbol\)$/, "");
			return plain === query ? 0 : plain.startsWith(query) ? 1 : 2;
		};
		return known.filter(([, name]) => words.every(word => name.includes(word))).map(([character, name]) => ({ character, name, rank: rank(name) })).sort((a, b) => a.rank - b.rank || a.name.length - b.name.length).slice(0, limit).map(({ character, name }) => [character, name]);
	}

	function put(character) {
		Env.act("emoji", () => {
			Quickshell.execDetached(["wl-copy", "--", character]);
			Quickshell.execDetached(["sh", "-c", 'sleep 0.2; exec wtype -- "$1"', "sh", character]);
		});
	}

	FileView {
		id: data

		path: Quickshell.shellPath("launcher/emoji.json")
		blockLoading: true
	}
}
