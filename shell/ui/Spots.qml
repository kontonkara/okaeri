pragma Singleton

import QtQuick
import Quickshell

// What shows, found by what it says, for tests to click on it wherever it is:
// the item whose `keys`, its text and the like, say `text`, a line first, as
// what has a subtext is; and in it, or a step or two up from a word that's no
// line, the part of it by its objectName, or "line" for the whole of it.
Singleton {
	function find(item, text, lines, keys) {
		if (!item || !item.visible)
			return null;
		if (keys.some(key => item[key] === text) && (!lines || item.subtext !== undefined))
			return item;
		for (const child of item.children ?? []) {
			const found = find(child, text, lines, keys);
			if (found)
				return found;
		}
		return null;
	}

	function named(item, name) {
		if (!item)
			return null;
		if (item.objectName === name)
			return item;
		for (const child of item.children ?? []) {
			const found = named(child, name);
			if (found)
				return found;
		}
		return null;
	}

	// What says `text` under `root`, and its part `part`: [line, part], null for
	// either that isn't there.
	function part(root, text, part, keys) {
		const found = find(root, text, true, keys) ?? find(root, text, false, keys);
		if (!found)
			return [null, null];
		let target = part === "line" ? found : named(found, part);
		for (let above = found.parent, steps = 0; !target && above && steps < 2 && found.subtext === undefined; above = above.parent, steps++)
			target = named(above, part);
		return [found, target];
	}
}
