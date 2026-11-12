pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// The clipboard's history, kept by cliphist. What's copied goes into it
// through wl-paste; it's read and changed here, by ids, which go to the
// commands as arguments of their own: what was copied stays out of shell
// strings and of the log. None of this goes through Env.act: it's the
// session's clipboard and okaeri's own file, and a test has its own of both.
// What's pinned is kept apart from the history, and outlasts it.
Singleton {
	id: clipboard

	// ./try keeps a history of its own, or that window would write in the
	// desktop's. A directory each: cliphist makes it, private.
	readonly property string folder: Env.guest ? "clipboard-guest" : "clipboard"
	readonly property string database: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/${folder}/history.db`
	// Where a row decodes the picture it shows, for as long as that takes.
	readonly property string pictures: `${Quickshell.env("XDG_RUNTIME_DIR")}/okaeri/${folder}`

	// { id, text, subtext, picture }, newest first.
	property var entries: []
	// Those pinned, as that and { pinned, file }: the file has what was copied.
	readonly property string pinFolder: database.replace(/[^/]*$/, "pins")
	property var pins: []
	// All there is to show: what's pinned first, and only there. Text is the same
	// thing where it reads the same; a picture only says its kind and size, as
	// many do, so that goes by the entry it was pinned from.
	readonly property var shown: pins.concat(entries.filter(entry => !pins.some(pin => pin.from === entry.id || (!entry.picture && !pin.picture && pin.text === entry.text))))
	// How long the history gets, which goes to the watchers.
	readonly property int keep: Settings.clipboard.keep
	// Whether pictures go into it too: without them their watcher doesn't run.
	readonly property bool images: Settings.clipboard.images
	// Nothing copied is kept while this is on, a password say, till it's off or
	// the shell starts again. The watchers go on all the same and drop what comes
	// while the file `pauseFile` is there: one that started again would store
	// what's on the clipboard then, the last thing copied while paused.
	property bool paused: false
	readonly property string pauseFile: `${Quickshell.env("XDG_RUNTIME_DIR")}/okaeri/${folder}-paused`
	// What the watchers run for each thing copied. The sh in between passes
	// CLIPBOARD_STATE on to cliphist as it becomes it, and reads what it drops,
	// so the app that copied it isn't cut off as it writes.
	readonly property var store: ["sh", "-c", 'if [ -e "$0" ]; then cat >/dev/null; else exec "$@"; fi', pauseFile,
		"cliphist", "-db-path", database, "-max-items", String(keep), "-max-dedupe-search", "750", "store"]
	property bool started: false
	// Commands waiting for their turn.
	property var chores: []
	// Pictures of rows that went, for the sweeper.
	property var discarded: []
	// The pinned picture that was last put back, by id: the history gets it as a
	// new entry, and the pin is that one's from then on.
	property string awaited: ""

	signal toggleRequested

	function toggle() {
		toggleRequested();
	}

	// By the panel's button and by calls. In the queue, as the file goes and
	// comes in the order they were asked for.
	function pause() {
		if (paused)
			return;
		paused = true;
		run(["sh", "-c", 'mkdir -p "${1%/*}" && : >"$1"', "sh", pauseFile]);
	}

	function resume() {
		if (!paused)
			return;
		paused = false;
		run(["rm", "-f", "--", pauseFile]);
	}

	function togglePause() {
		if (paused)
			resume();
		else
			pause();
	}

	function parse(line) {
		const tab = line.indexOf("\t");
		const id = line.slice(0, tab);
		const text = line.slice(tab + 1);
		const picture = text.match(/^\[\[ binary data (\d+ \w+) (\w+) (\d+x\d+) \]\]$/);
		if (picture)
			return { id, text: "Image", subtext: `${picture[2].toUpperCase()}, ${picture[3]}, ${picture[1]}`, picture: true };
		return { id, text };
	}

	// A filter sees this much of an entry. The apps are read as they're first asked
	// for: paste() has them by then.
	function load() {
		DesktopEntries.applications.values;
		lister.exec(["cliphist", "-db-path", database, "-preview-width", "300", "list"]);
	}

	function run(command) {
		chores.push(command);
		next();
	}

	// One at a time, in the order they came.
	function next() {
		if (!worker.running && chores.length)
			worker.exec(chores.shift());
	}

	// wl-copy takes the clipboard even with nothing to put on it, so only what
	// decodes goes there: an id is gone once the same thing was copied again.
	// What it is, wl-copy tells from the bytes; the list's preview can be wrong.
	function restore(entry) {
		awaited = entry.pinned && entry.picture ? entry.id : "";
		if (awaited) {
			adopting.looks = 0;
			adopting.restart();
		}
		if (entry.pinned)
			run(["sh", "-c", 'wl-copy <"$1"', "sh", entry.file]);
		else
			run(["sh", "-c", 'if cliphist -db-path "$1" decode "$2" >/dev/null; then cliphist -db-path "$1" decode "$2" | wl-copy; fi', "sh", database, entry.id]);
	}

	// Into the window in focus, as the panel has let go of the keys. What's on the
	// clipboard by then was put there first: these go one at a time.
	function paste() {
		const app = Niri.lastWindow?.app_id;
		if (!app)
			return;
		const terminal = DesktopEntries.heuristicLookup(app)?.categories.includes("TerminalEmulator");
		const keys = terminal ? ["-M", "ctrl", "-M", "shift", "-k", "v", "-m", "shift", "-m", "ctrl"] : ["-M", "ctrl", "-k", "v", "-m", "ctrl"];
		run(["sh", "-c", 'sleep 0.2; exec wtype "$@"', "sh", ...keys]);
	}

	// A row only comes up with its file there, for the preview to read.
	function pin(entry) {
		if (pinner.running)
			return;
		const name = String(Date.now());
		pinner.entry = { id: `pin-${name}`, from: entry.id, text: entry.text, subtext: entry.subtext, picture: entry.picture, pinned: true, file: `${pinFolder}/${name}` };
		pinner.exec(["sh", "-c", 'mkdir -p "${3%/*}" && cliphist -db-path "$1" decode "$2" >"$3"', "sh", database, entry.id, pinner.entry.file]);
	}

	// The history has `entries` where it had `before`: the oldest new picture that
	// says of itself what the pinned one put back does is that one, and the pin
	// has it from here on.
	function adopt(entries, before) {
		const pin = pins.find(other => other.id === awaited);
		const found = pin ? entries.filter(entry => entry.picture && entry.subtext === pin.subtext && !before.some(other => other.id === entry.id)).pop() : null;
		if (!found)
			return;
		awaited = "";
		pins = pins.map(other => other === pin ? Object.assign({}, pin, { from: found.id }) : other);
		savePins();
	}

	function savePins() {
		pinsFile.setText(JSON.stringify(pins));
	}

	function unpin(entry) {
		const id = entry.id;
		const file = entry.file;
		pins = pins.filter(other => other.id !== id);
		savePins();
		Quickshell.execDetached(["rm", "-f", "--", file]);
	}

	function remove(entry) {
		if (entry.pinned) {
			unpin(entry);
			return;
		}
		// `entry` can be a view into the list's model, which changes below.
		const id = entry.id;
		entries = entries.filter(other => other.id !== id);
		run(["sh", "-c", 'printf "%s\\n" "$2" | cliphist -db-path "$1" delete', "sh", database, id]);
	}

	// The clipboard too: a watcher starts by storing what's on it, which would
	// bring that back. Removing one row leaves the clipboard alone, on purpose:
	// that's something to paste yet, so a new watcher can store it again. What's
	// pinned stays.
	function clear() {
		entries = [];
		run(["cliphist", "-db-path", database, "wipe"]);
		run(["wl-copy", "--clear"]);
	}

	// A row's decoding outlives the row by a moment, and can make the file only
	// then: it goes a little later, when that's over.
	function discard(file) {
		discarded.push(file);
		sweeper.restart();
	}

	// The watchers have it from their start on, and that's before this is set.
	onKeepChanged: {
		if (started) {
			textWatch.running = false;
			imageWatch.running = false;
		}
	}

	onImagesChanged: {
		if (started)
			imageWatch.running = images;
	}

	// For tests, and never what was copied.
	onPausedChanged: console.info(`okaeri: clipboard: ${paused ? "paused" : "kept again"}`)

	// What a shell that died left, a pause too: that ends with it.
	Component.onCompleted: {
		started = true;
		Quickshell.execDetached(["rm", "-rf", "--", pictures, pauseFile]);
	}

	Process {
		id: pinner

		property var entry

		onExited: code => {
			if (code === 0) {
				clipboard.pins = [entry].concat(clipboard.pins);
				clipboard.savePins();
			}
		}
	}

	FileView {
		id: pinsFile

		path: `${clipboard.pinFolder}/pins.json`
		printErrors: false
		onLoaded: clipboard.pins = Theme.parse(text() || "[]", path)
	}

	Process {
		id: lister

		stdout: StdioCollector {
			id: listing
		}

		// A list that failed says nothing: a locked history isn't an empty one.
		onExited: code => {
			if (code !== 0)
				return;
			const entries = listing.text.split("\n").filter(line => /^\d+\t/.test(line)).map(clipboard.parse);
			// The same list keeps its rows, and their previews.
			if (JSON.stringify(entries) === JSON.stringify(clipboard.entries))
				return;
			clipboard.adopt(entries, clipboard.entries);
			clipboard.entries = entries;
		}
	}

	// The watcher stores what was put back a moment after: a few looks for it, and
	// a picture that comes later is another.
	Timer {
		id: adopting

		property int looks: 0

		interval: 500
		repeat: true
		onTriggered: {
			looks += 1;
			if (clipboard.awaited === "" || looks > 4) {
				clipboard.awaited = "";
				stop();
			} else {
				clipboard.load();
			}
		}
	}

	Process {
		id: worker

		onExited: clipboard.next()
	}

	Timer {
		id: sweeper

		interval: 200
		onTriggered: {
			Quickshell.execDetached(["rm", "-f", "--"].concat(clipboard.discarded));
			clipboard.discarded = [];
		}
	}

	// wl-paste tells what a password manager copied by CLIPBOARD_STATE=sensitive
	// in the environment of the command it runs, and `cliphist store` leaves
	// that out: keep it in cliphist's environment, as `store` does. What's put
	// back comes up from anywhere in the history, not doubled, by the dedupe
	// search. setpriv, which becomes wl-paste, ends them with the shell, however
	// that goes. These run under ./try too: the inner niri has a clipboard of its
	// own, so they see only that one, and unlike the notification server nothing
	// here is for only one to hold.
	Process {
		id: textWatch

		running: true
		command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch"].concat(clipboard.store)
		onExited: revive.restart()
	}

	Process {
		id: imageWatch

		running: clipboard.images
		command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image", "--watch"].concat(clipboard.store)
		onExited: revive.restart()
	}

	Timer {
		id: revive

		interval: 5000
		// Not without what they run: they'd only end again.
		onTriggered: {
			if (Env.lacks("cliphist") || Env.lacks("wl-paste"))
				return;
			textWatch.running = true;
			if (clipboard.images)
				imageWatch.running = true;
		}
	}

	IpcHandler {
		target: "clipboard"

		function toggle(): void {
			clipboard.toggle();
		}

		function clear(): void {
			clipboard.clear();
		}

		// Nothing copied is kept from now on, till resume or the shell's next start.
		function pause(): void {
			clipboard.pause();
		}

		function resume(): void {
			clipboard.resume();
		}
	}
}
