import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.clipboard
import qs.services
import qs.ui

// The app launcher: what's typed picks from the apps and Enter launches the
// selected one, copies the answer to a sum, or goes to an open window or to the
// session menu. A / in front asks for one kind of thing alone, emoji, what was
// copied, files by their names and the settings among them, and alone it says
// which there are. A right click or Shift+Enter on an app shows what else it can
// do, in the list's place, and on a file, an emoji or something copied does the
// other thing there is to do with it; a window it closes. `okaeri dmenu` has it
// show a script's lines instead, to pick one of, which the script is told. A >
// in front runs the rest as a command, and a ? looks it up on the web, at
// Settings.launcher.search. The button in the field, or Ctrl+G, has the groups
// apps go by in the list's place, folders of one's own and the kinds apps say
// they are: one picked, the list and the search are within it, until Escape.
// The field keeps the keys, Up and Down reach the list from it.
Panel {
	id: launcher

	// What a / in front asks for.
	readonly property var modes: [
		{ mode: "calc", text: Tr.t("Sums"), subtext: "/calc and the sum, or the last ones", icon: "calculator" },
		{ mode: "win", text: Tr.t("Open windows"), subtext: "/win: Enter goes to one, Shift+Enter closes it", icon: "apps" },
		{ mode: "wall", text: Tr.t("Wallpapers"), subtext: "/wall", icon: "image" },
		{ mode: "emoji", text: Tr.t("Emoji and symbols"), subtext: "/emoji and a name: Enter types it and copies it, Shift+Enter only copies", icon: "text" },
		{ mode: "clip", text: Tr.t("Clipboard"), subtext: "/clip and what was copied: Enter copies it again, Shift+Enter the other of that and pasting", icon: "clipboard" },
		{ mode: "file", text: Tr.t("Files"), subtext: "/file and a part of the name: Enter opens it, Shift+Enter its folder", icon: "file" },
		{ mode: "ps", text: Tr.t("Processes"), subtext: "/ps and a name: Enter twice ends one, Shift+Enter twice kills it", icon: "chip" },
		{ mode: "set", text: Tr.t("Settings"), subtext: "/set and what to look for", icon: "gear" },
		{ mode: "shot", text: Tr.t("Screenshots"), subtext: "/shot: take one, or the latest: Enter opens one, Shift+Enter copies it", icon: "image" },
		{ mode: "color", text: Tr.t("A color off the screen"), subtext: "/color: a click on the screen copies it as #rrggbb", icon: "eye" },
		{ mode: "todo", text: Tr.t("Things to do"), subtext: "/todo and what: Enter adds it; without, Enter ticks one off", icon: "notes" },
		{ mode: "timer", text: Tr.t("Timer and stopwatch"), subtext: "/timer and how long, as 10m or 1:30, and what for", icon: "bell" },
		{ mode: "session", text: Tr.t("Session"), subtext: "/session", icon: "power" }
	]

	// Modes of one's own, Settings.launcher.modes, and those plugins bring, by
	// their plugin.json's `modes` or a QML file, `launcher`. A command lists the
	// rows, with what's typed as $1: a line each, its text, after a tab what's
	// under it, and after another what Enter gives `run` as $1, else the text;
	// with no `run` Enter copies that. A `live` one is asked again as what's typed
	// changes; the rest once as the mode opens, and what's typed picks from what
	// it listed. A name the launcher has already, or one taken before, is left
	// out. A plugin's run in its folder.
	readonly property var ownModes: {
		const taken = new Set(modes.map(row => row.mode));
		const all = (Array.isArray(Settings.launcher.modes) ? Settings.launcher.modes : []).filter(one => one && typeof one.list === "string" && one.list !== "").map(one => Object.assign({ text: "", subtext: Tr.t("A mode of yours"), run: "", live: false, dir: "" }, one)).concat(...Plugins.running.map(plugin => plugin.modes.map(one => Object.assign({}, one, { subtext: one.subtext || Tr.f("From %1", plugin.name), dir: plugin.dir }))), qmlModes);
		return all.filter(one => {
			const name = String(one.mode ?? "").toLowerCase();
			if (!/^[a-z0-9_-]+$/.test(name) || taken.has(name))
				return false;
			taken.add(name);
			return true;
		});
	}
	// Those of plugins' QML files, each { mode, text, subtext, icon, item }.
	property var qmlModes: []
	// What a command of a mode listed: for which mode and what was typed, and
	// the rows.
	property var listed: ({ mode: "", asked: "", rows: [] })
	// The mode of one's own that's typed, and what's typed after it.
	readonly property var owning: {
		const asked = field.text.match(/^\s*\/(\S+)\s(.*)$/);
		const own = asked ? ownModes.find(one => one.mode.toLowerCase() === asked[1].toLowerCase()) : null;
		return own ? { own, query: asked[2].trim() } : null;
	}

	onOwningChanged: {
		if (!owning || owning.own.item)
			return;
		if (owning.own.live)
			listing.restart();
		else if (listed.mode !== owning.own.mode)
			listOwn();
	}

	function gatherModes() {
		const found = [];
		for (let at = 0; at < pluginModes.count; at++) {
			const item = pluginModes.objectAt(at)?.item;
			if (item && typeof item.rows === "function" && typeof item.mode === "string")
				found.push({ mode: item.mode, text: String(item.text || ""), subtext: String(item.subtext || Tr.f("From %1", pluginModes.objectAt(at).name)), icon: String(item.icon || ""), item });
		}
		qmlModes = found;
	}

	// Asked of the command of the mode that's typed, one at a time, the last one
	// last.
	function listOwn() {
		if (!owning || owning.own.item || lister.running)
			return;
		const own = owning.own;
		lister.mode = own.mode;
		lister.asked = own.live ? owning.query : "";
		lister.workingDirectory = own.dir || home;
		lister.command = ["sh", "-c", own.list, "sh", lister.asked];
		lister.running = true;
	}

	function ownRows(own, query) {
		const wanted = query.toLowerCase();
		if (own.item) {
			let rows = [];
			try {
				rows = own.item.rows(query);
			} catch (error) {
				console.warn("okaeri: launcher: mode", own.mode, "failed:", error);
			}
			return (Array.isArray(rows) ? rows : []).filter(row => row && row.text !== undefined).map(row => Object.assign({}, row, { text: String(row.text), subtext: String(row.subtext ?? ""), icon: row.icon || own.icon || "play", does: typeof row.does === "function" ? row.does : () => {} }));
		}
		if (listed.mode !== own.mode)
			return [];
		return listed.rows.filter(row => own.live || !wanted || row.text.toLowerCase().includes(wanted) || row.subtext.toLowerCase().includes(wanted)).slice(0, 200).map(row => Object.assign({ does: () => runOwn(own, row.value, query), icon: "play" }, row));
	}

	// `run` with what the row gives, by niri, so what it starts isn't the
	// shell's; or that copied.
	function runOwn(own, value, query) {
		if (!own.run) {
			Clipboard.put(value);
			return;
		}
		const into = own.dir ? `cd '${own.dir.replace(/'/g, "'\\''")}' || exit; ` : "";
		Env.act(`launcher mode ${own.mode}`, () => Niri.spawn(["sh", "-c", into + own.run, "sh", value, query]));
	}

	function readListed(text) {
		listed = {
			mode: lister.mode,
			asked: lister.asked,
			rows: text.split("\n").filter(line => line.trim() !== "").map(line => {
				const [shown, under, value] = line.split("\t");
				return { text: shown, subtext: under ?? "", value: value || shown, mark: `${lister.mode}|${line}` };
			})
		};
	}
	// The group whose apps alone show, by its key, "" for all of them; and whether
	// the groups there are show in the list's place, to pick one of.
	property string group: ""
	property bool grouping: false
	readonly property var grouped: Apps.groups.find(one => one.key === group) ?? null

	function groupRows() {
		return [{ group: "", text: Tr.t("All apps"), subtext: "", icon: "apps" }].concat(Apps.groups.map(one => ({
			group: one.key,
			text: one.text,
			subtext: one.count === 1 ? "1 app" : `${one.count} apps`,
			icon: one.own ? "file" : "apps",
			mark: one.key === group ? "on" : ""
		})));
	}

	// By the button in the field and Ctrl+G: the groups, or back to the apps.
	function toggleGroups() {
		if (picking || Apps.groups.length === 0)
			return;
		menuOf = null;
		grouping = !grouping;
		search();
	}

	function pickGroup(key) {
		group = key;
		grouping = false;
		if (field.text !== "")
			field.text = "";
		else
			search();
	}

	// Whether what's typed asks for what was copied.
	readonly property bool clipping: /^\s*\/clip\s/i.test(field.text)

	onClippingChanged: {
		if (clipping)
			Clipboard.load();
	}

	// The part of a file's name that's asked for, and the files that have it, as
	// they're found: under Settings.launcher.files, or the home folder, by fd where
	// that's there and by find where it's not.
	readonly property string filing: (field.text.match(/^\s*\/file\s+(.*)$/i) ?? [])[1]?.trim() ?? ""
	property var files: []
	readonly property string home: Quickshell.env("HOME")

	// What was found for less stays until what's asked now is: an empty list at
	// every letter would flicker.
	onFilingChanged: {
		if (filing.length > 1)
			looking.restart();
		else
			files = [];
	}

	// A script's lines to pick from, and the pipe that takes the answer: null with
	// none asking. What else it has is what pickFrom() was asked.
	property var picking: null
	// A script asked for a password, and what's typed shows as dots: until the
	// next opening, not only until the answer, or it would show as the panel
	// fades.
	property bool hiding: false

	// The app whose menu is in the list's place, if one is.
	property var menuOf: null

	// The lines of a script that have what's typed, as they came, each with where
	// it was among all of them, which --index answers with.
	function picks(wanted) {
		return picking.lines.map((line, at) => ({ pick: line, at: picking.places[at], text: line, mark: at })).filter(row => row.text.toLowerCase().includes(wanted));
	}

	// A file of a script's, "" for one that isn't there.
	function readOf(path) {
		lines.path = "";
		lines.path = path;
		return lines.text();
	}

	// A script's lines to pick one of, from `file`, and the pipe the answer goes
	// to. `asked` says how: { prompt, password (what's typed shows as dots),
	// index (the answer is where the line picked was), onlyMatch (only a line is
	// an answer, never what's typed), select (the line to start on) }, any of them
	// left out.
	function pickFrom(file, pipe, asked) {
		answer("");
		const all = readOf(file).split("\n");
		const places = all.map((line, at) => at).filter(at => all[at] !== "");
		show();
		picking = Object.assign({ lines: places.map(at => all[at]), places, pipe }, asked);
		hiding = !!asked.password;
		search();
		const start = asked.select ? found.values.findIndex(row => row.pick === asked.select) : -1;
		if (start > 0) {
			list.currentIndex = start;
			list.positionViewAtIndex(start, ListView.Contain);
		}
	}

	// What was picked, for the script that waits: nothing says none was.
	function answer(text) {
		if (!picking)
			return;
		// Not for ever: a script that's gone isn't there to take it.
		Quickshell.execDetached(["timeout", "5", "sh", "-c", 'printf "%s" "$1" >"$2"', "sh", text, picking.pipe]);
		picking = null;
	}

	// Each by its title, with its app, its workspace and, with more than one
	// screen, the screen under it; the one in focus is checked.
	function windows(wanted) {
		const screens = new Set(Niri.workspaces.map(space => space.output)).size;
		return Niri.windows.filter(w => [w.title, w.app_id].some(text => (text || "").toLowerCase().includes(wanted))).map(w => {
			const space = Niri.workspaces.find(space => space.id === w.workspace_id);
			const where = space ? [`workspace ${space.name || space.idx}`].concat(screens > 1 && space.output ? [space.output] : []) : [];
			return {
				window: w.id,
				text: w.title,
				subtext: [Apps.entryOf(w.app_id)?.name || w.app_id || Tr.t("Window")].concat(where).join(" · "),
				image: Apps.imageOf(w.app_id),
				icon: "apps",
				mark: w.is_focused ? "check" : ""
			};
		});
	}

	function session(wanted) {
		return Session.actions.filter(row => row.text.toLowerCase().includes(wanted)).map(row => ({
			session: row,
			text: row.text,
			subtext: Tr.t("Session"),
			icon: row.icon
		}));
	}

	function sum() {
		return Calculator.result ? [{ text: Calculator.result, subtext: Calculator.expression, icon: "calculator", sum: true }] : [];
	}

	// The last sums, for their answers.
	function sums() {
		return Calculator.recent.map(sum => ({ text: sum.result, subtext: sum.expression, icon: "calculator", copy: sum.result }));
	}

	function wallpapers(wanted) {
		const found = [];
		for (let index = 0; index < pictures.count && found.length < Apps.limit; index++) {
			const name = pictures.get(index, "fileName");
			if (name.toLowerCase().includes(wanted))
				found.push({ wallpaper: pictures.get(index, "filePath"), text: name, subtext: Tr.t("Wallpaper"), image: pictures.get(index, "fileUrl"), icon: "image" });
		}
		return found;
	}

	function emoji(wanted) {
		return Emoji.search(wanted, Apps.limit).map(([character, name]) => ({
			emoji: character,
			glyph: character,
			text: name.replace(/ \(symbol\)$/, ""),
			subtext: name.endsWith("(symbol)") ? Tr.t("Symbol") : Tr.t("Emoji")
		}));
	}

	// Asked again as what's typed changes: one at a time, the last one last.
	function look() {
		if (finder.running || filing.length < 2)
			return;
		finder.asked = filing;
		finder.command = ["sh", "-c", 'if command -v fd >/dev/null; then fd --max-results 40 --ignore-case --fixed-strings -- "$2" "$1"; else find "$1" -maxdepth 6 -not -path "*/.*" -iname "*$2*" 2>/dev/null | head -n 40; fi', "sh", Settings.launcher.files || home, filing];
		finder.running = true;
	}

	// A row for each, by its name, with where it is under it.
	function fileRows() {
		return files.map(path => {
			const whole = path.replace(/\/$/, "");
			const cut = whole.lastIndexOf("/");
			return { file: whole, text: whole.slice(cut + 1), subtext: whole.slice(0, cut).replace(home, "~") || "/", icon: "file", mark: whole };
		});
	}

	// What was copied, the newest first, a line of each.
	function clips(wanted) {
		return Clipboard.shown.filter(entry => entry.text.toLowerCase().includes(wanted)).slice(0, Apps.limit).map(entry => ({
			clip: entry,
			text: entry.text.replace(/\s+/g, " ").slice(0, 200),
			subtext: entry.subtext || (entry.pinned ? Tr.t("Pinned") : Tr.t("Copied")),
			icon: "clipboard",
			mark: entry.id
		}));
	}

	// The settings window, on what's looked for.
	function settings(wanted) {
		return [{ settings: wanted, text: wanted ? `Look for "${wanted}" in the settings` : "Open the settings", subtext: "Settings", icon: "gear" }];
	}

	// A timer for as long as what's typed first says, with the rest of it as what
	// it's for, or pomodoros; the one that runs, to stop; and the stopwatch.
	function timer(asked) {
		const words = asked.trim().split(/\s+/);
		const seconds = Timers.parse(words[0] ?? "");
		const what = words.slice(1).join(" ");
		const found = [];
		if (seconds > 0)
			found.push({ does: () => Timers.start(seconds, what), text: Tr.f("A timer for %1", Timers.span(seconds)), subtext: what || "It says when the time is up", icon: "bell" });
		else if (!Timers.counting)
			found.push({ does: () => Timers.startPomodoro(), text: "Pomodoros", subtext: Tr.f("%1 min of work, then a break, and again", Settings.pomodoro.work), icon: "bell" });
		if (Timers.counting)
			found.push({ does: () => Timers.stop(), text: "Stop the timer", subtext: Tr.f("%1 left", Timers.clock(Timers.left)), icon: "close" });
		found.push({ does: () => Timers.toggleWatch(), text: Timers.watching ? "Stop the stopwatch" : "Start the stopwatch", subtext: Timers.watched > 0 ? Timers.clock(Timers.watched) : "", icon: Timers.watching ? "pause" : "play" });
		return found;
	}

	// A thing to do added from the text, or without it those not done yet, Enter
	// ticking one off, the launcher staying on the rest.
	function todoRows(text) {
		if (text)
			return [{ does: () => Notes.add(text), text: Tr.f("Add %1", text), subtext: "To what's to do", icon: "notes" }];
		return Notes.todos.map((todo, index) => ({ todo, index })).filter(one => !one.todo.done).map(one => ({
			key: `todo|${one.todo.text}`,
			stays: true,
			does: () => Notes.toggle(one.index),
			text: one.todo.text,
			subtext: Tr.t("Enter ticks it off"),
			icon: "box"
		}));
	}

	// One's processes with `query` in their names, their command lines or as their
	// pids, the busiest first. Enter on one asks to end it and stays, and on it
	// again ends it; Shift+Enter kills it the same way. Each row stays itself as
	// its numbers change.
	function processRows(query) {
		return Processes.list.filter(one => !query || one.name.toLowerCase().includes(query) || one.command.toLowerCase().includes(query) || String(one.pid) === query).slice(0, 50).map(one => ({
			key: `ps|${one.pid}`,
			pid: one.pid,
			stays: true,
			does: () => Processes.ask(one.pid, false),
			text: one.name,
			subtext: Processes.armed === one.pid ? (Processes.armedHard ? "Shift+Enter again kills it" : "Enter again ends it") : `${one.cpu.toFixed(1)}% · ${Processes.memory(one.memory)} · ${one.pid}`,
			icon: "chip"
		}));
	}

	// A screenshot to take, the text off the screen and the latest to edit where
	// there's what for, and the latest taken, those that have `query` in their
	// names.
	function shots(query) {
		const later = Settings.screenshots.delay > 0 ? `In ${Settings.screenshots.delay} s` : "";
		return [
			{ does: () => Screenshots.take("area"), text: Tr.t("A part of the screen"), subtext: Tr.t("Picked by niri"), icon: "image" },
			{ does: () => Screenshots.take("screen"), text: Tr.t("The screen"), subtext: later, icon: "image" },
			{ does: () => Screenshots.take("window"), text: Tr.t("The window in focus"), subtext: later, icon: "image" }
		].concat(Screenshots.reads ? [{ does: () => Screenshots.textOffScreen(), text: Tr.t("Text off the screen"), subtext: Tr.t("Of a part of it, onto the clipboard"), icon: "text" }] : [], Screenshots.edits && Screenshots.latest.length > 0 ? [{ does: () => Screenshots.edit(Screenshots.latest[0]), text: Tr.t("Edit the latest"), subtext: Screenshots.latest[0].replace(/^.*\//, ""), icon: "pencil" }] : []).filter(row => !query || row.text.toLowerCase().includes(query)).concat(Screenshots.latest.filter(file => !query || file.toLowerCase().includes(query)).map(file => ({
			shot: file,
			text: file.replace(/^.*\//, ""),
			subtext: file.replace(/\/[^/]*$/, "").replace(Quickshell.env("HOME"), "~"),
			image: Settings.url(file),
			icon: "image"
		})));
	}

	// What else `entry` can do.
	function menu(entry) {
		const pinned = Settings.launcher.pinned.includes(entry.id);
		const docked = Settings.dock.pinned.includes(entry.id);
		return [{ back: true, text: Tr.t("Back"), subtext: entry.name, icon: "back" }].concat(Array.from(entry.actions).map(action => ({
			action,
			text: action.name,
			image: Apps.image(action.icon),
			icon: "apps"
		})), [
			{ pin: !pinned, pinning: true, text: pinned ? "Unpin" : "Pin to the top", icon: "pin" },
			{ hiding: true, text: Tr.t("Hide from the launcher"), icon: "eyeOff" },
			{ dock: !docked, docking: true, text: docked ? "Take off the dock" : "Keep on the dock", icon: "apps" }
		], Apps.folders.map(folder => {
			const inside = Array.isArray(folder.apps) && folder.apps.includes(entry.id);
			return { folding: true, folder: folder.name, fold: !inside, text: inside ? `Out of ${folder.name}` : `Into ${folder.name}`, subtext: "A folder of yours", icon: "file" };
		}));
	}

	// What goes by what's typed: the sum, the apps, and after them the open windows
	// and what the session can do, or with a / what that asks for.
	function typed() {
		const text = field.text;
		const wanted = text.trim().toLowerCase();
		if (picking)
			return picks(wanted);
		// A > in front runs the rest as a command, and a ? looks it up on the web.
		const command = text.match(/^\s*>\s*(.*)$/);
		if (command)
			return command[1].trim() ? [{ does: () => Env.act("run a command", () => Niri.spawn(["sh", "-c", command[1].trim()])), text: Tr.f("Run %1", command[1].trim()), subtext: "A command, by sh", icon: "play" }] : [{ stays: true, does: () => {}, text: "A command to run", subtext: "> and the command", icon: "play" }];
		const looked = text.match(/^\s*\?\s*(.*)$/);
		if (looked)
			return looked[1].trim() ? [{ does: () => Env.act("web search", () => Qt.openUrlExternally(Settings.launcher.search.replace("%s", encodeURIComponent(looked[1].trim())))), text: Tr.f("Look up %1", looked[1].trim()), subtext: "On the web", icon: "search" }] : [{ stays: true, does: () => {}, text: "Something to look up on the web", subtext: "? and the words", icon: "search" }];
		const asked = text.match(/^\s*\/(\S*)(\s+.*)?$/);
		if (!asked)
			return grouped ? Apps.search(text, grouped.has) : sum().concat(Apps.search(text), wanted ? windows(wanted) : [], wanted.length < 2 ? [] : session(wanted));
		if (asked[2] === undefined)
			return modes.concat(ownModes.map(own => ({ mode: own.mode, text: own.text || `/${own.mode}`, subtext: own.text ? `/${own.mode} · ${own.subtext}` : own.subtext, icon: own.icon || "play" }))).filter(row => row.mode.toLowerCase().startsWith(asked[1].toLowerCase()));
		const query = asked[2].trim().toLowerCase();
		switch (asked[1].toLowerCase()) {
		case "calc":
			return query ? sum() : sums();
		case "win":
			return windows(query);
		case "wall":
			return wallpapers(query);
		case "emoji":
			return emoji(query);
		case "clip":
			return clips(query);
		case "file":
			return fileRows();
		case "set":
			return settings(asked[2].trim());
		case "session":
			return session(query);
		case "timer":
			return timer(asked[2]);
		case "shot":
			return shots(query);
		case "ps":
			return processRows(query);
		case "todo":
			return todoRows(asked[2].trim());
		case "color":
			return [{ does: () => colorSoon.restart(), text: Tr.t("Pick a color off the screen"), subtext: Tr.t("A click on it copies it as #rrggbb"), icon: "eye" }];
		}
		return owning ? ownRows(owning.own, asked[2].trim()) : [];
	}

	function rows() {
		// What tells rows apart, so one that stays from a search to the next moves
		// instead of being made anew: all that shows on it, or a process's number,
		// as what it takes changes on every look.
		return (menuOf ? menu(menuOf) : grouping ? groupRows() : typed()).map(row => Object.assign({
			key: row.pid ? `pid ${row.pid}` : [row.text, row.subtext, row.entry?.id, row.action?.id, row.window, row.session?.text, row.mark].join("|")
		}, row));
	}

	// Not a binding: an app moving up for its launch would show as the panel
	// fades.
	function search() {
		found.values = rows();
		list.currentIndex = 0;
		list.positionViewAtBeginning();
	}

	// The same search over apps that came or went, or processes looked at again, on
	// the same row if it's there, and where the list was scrolled to.
	function refresh() {
		// The row picked stays picked: an app by its entry, the rest by their keys.
		const was = found.values[list.currentIndex];
		const scrolled = list.contentY;
		found.values = rows();
		list.currentIndex = Math.max(0, found.values.findIndex(row => was?.entry ? row.entry?.id === was.entry.id : row.key === was?.key));
		list.contentY = Math.max(list.originY, Math.min(scrolled, list.originY + Math.max(0, list.contentHeight - list.height)));
		// For tests: how far down it stayed.
		console.info("okaeri: launcher: refreshed at", Math.round(list.contentY - list.originY));
	}

	function openMenu(row) {
		if (row?.entry) {
			menuOf = row.entry;
			search();
		} else {
			otherWay(row);
		}
	}

	// What Shift+Enter or a right click does with a row that's no app, the other
	// thing there is to do with it: a file's folder opens, a screenshot is copied,
	// what was copied is pasted where Enter copies and copied where it pastes, and
	// an emoji is only copied. A window closes, and the launcher stays on the rest
	// of them.
	function otherWay(row) {
		if (row?.pid) {
			Processes.ask(row.pid, true);
			return;
		}
		if (row?.window) {
			Env.act("close window", () => Niri.closeWindow(row.window));
			return;
		}
		if (row?.shot)
			Screenshots.copy(row.shot);
		else if (row?.file)
			Env.act("open folder", () => Niri.spawn(["xdg-open", row.file.replace(/\/[^/]*$/, "") || "/"]));
		else if (row?.clip) {
			Clipboard.restore(row.clip);
			if (!Settings.clipboard.paste)
				Clipboard.paste();
		} else if (row?.emoji)
			Emoji.put(row.emoji, true);
		else
			return;
		hide();
	}

	// Back on the app it was for, if that's still there.
	function closeMenu() {
		const app = menuOf?.id;
		menuOf = null;
		search();
		list.currentIndex = Math.max(0, found.values.findIndex(row => row.entry?.id === app));
		list.positionViewAtIndex(list.currentIndex, ListView.Contain);
	}

	align: "center"
	panelWidth: Theme.u(600)

	// Closed with a script still waiting: nothing was picked.
	onPanelClosed: answer("")

	onPanelOpened: {
		Session.check();
		menuOf = null;
		listed = { mode: "", asked: "", rows: [] };
		group = "";
		grouping = false;
		field.text = "";
		hiding = false;
		field.revealed = false;
		list.pointer = null;
		field.take();
		search();
	}

	// This also has Apps start now, and read the apps before the first opening.
	// Once the launcher is out of the way: it's not what's to be picked from.
	Timer {
		id: colorSoon

		interval: 300
		onTriggered: Env.act("color pick", () => Niri.pickColor())
	}

	// One's processes are looked at while /ps is open, and only then; each look and
	// a row asked to end shows at once.
	Binding {
		target: Processes
		property: "watched"
		value: launcher.shown && /^\s*\/ps(\s|$)/i.test(field.text)
	}

	Connections {
		target: Processes

		function onListChanged() {
			if (Processes.watched)
				launcher.refresh();
		}

		function onArmedChanged() {
			if (Processes.watched)
				launcher.refresh();
		}
	}

	// A thing ticked off under /todo goes from the rows at once.
	Connections {
		target: Notes

		function onTodosChanged() {
			if (launcher.shown && /^\s*\/todo(\s|$)/i.test(field.text))
				launcher.refresh();
		}
	}

	Connections {
		target: Apps

		function onKnownChanged() {
			if (launcher.shown && !launcher.menuOf)
				launcher.refresh();
		}

		function onLauncherWanted() {
			launcher.toggle();
		}
	}

	// What was copied is read as /clip asks for it, and comes a moment later.
	Connections {
		target: Clipboard

		function onShownChanged() {
			if (launcher.shown && launcher.clipping)
				launcher.search();
		}
	}

	// The windows listed follow those there are, one closed from here too, on the
	// same row.
	Connections {
		target: Niri

		function onWindowsChanged() {
			if (!launcher.shown || launcher.menuOf || !found.values.some(row => row.window))
				return;
			const at = list.currentIndex;
			launcher.search();
			list.currentIndex = Math.max(0, Math.min(at, found.values.length - 1));
			list.positionViewAtIndex(list.currentIndex, ListView.Contain);
		}
	}

	// A moment after the keystroke.
	Connections {
		target: Calculator

		function onResultChanged() {
			if (launcher.shown)
				launcher.search();
		}
	}

	IpcHandler {
		target: "launcher"

		function toggle(): void {
			launcher.toggle();
		}

		// Open with `text` typed already: `okaeri launcher open "/emoji "` for a key
		// that goes straight to the emoji.
		function open(text: string): void {
			launcher.show();
			field.text = text;
		}

		// A script's lines to pick one of: the file that has them, and the pipe
		// the answer goes to. `okaeri dmenu` called it so before menuWith.
		function menu(file: string, pipe: string, prompt: string): void {
			launcher.pickFrom(file, pipe, { prompt });
		}

		// The same as `okaeri dmenu` calls it now: `options` are the words
		// password, index and only-match, those wanted, as pickFrom() has them.
		// The prompt and the line to start on are in the files prompt and select
		// beside `file`: they can have anything in them, and a call's arguments
		// can't have commas.
		function menuWith(file: string, pipe: string, options: string): void {
			const words = options.split(/\s+/);
			const dir = file.replace(/[^/]*$/, "");
			launcher.pickFrom(file, pipe, {
				prompt: launcher.readOf(`${dir}prompt`),
				select: launcher.readOf(`${dir}select`),
				password: words.includes("password"),
				index: words.includes("index"),
				onlyMatch: words.includes("only-match")
			});
		}

		// For tests: how far down the list is.
		function scrolled(): real {
			return list.contentY;
		}

		// For tests: whether what's typed shows as dots.
		function secret(): bool {
			return field.secret && !field.revealed;
		}

		// For tests: what the rows say, as JSON.
		function texts(): string {
			return JSON.stringify(found.values.map(row => row.text));
		}
	}

	// A moment after the last key.
	Timer {
		id: looking

		interval: 200
		onTriggered: launcher.look()
	}

	Process {
		id: finder

		// What it was asked for: by the time it's done, that may be something else.
		property string asked

		stdout: StdioCollector {
			id: paths
		}
		onExited: {
			if (asked !== launcher.filing) {
				launcher.look();
				return;
			}
			launcher.files = paths.text.split("\n").filter(path => path !== "");
			if (launcher.shown)
				launcher.search();
		}
	}

	// A moment after the last key, for a live mode of one's own.
	Timer {
		id: listing

		interval: 200
		onTriggered: launcher.listOwn()
	}

	Process {
		id: lister

		// The mode and what was typed it was asked for: by the time it's done, that
		// may be something else.
		property string mode
		property string asked

		stdout: StdioCollector {
			id: listedText
		}
		stderr: StdioCollector {
			onStreamFinished: {
				if (text.trim() !== "")
					console.warn("okaeri: launcher: mode", lister.mode, "said:", text.trim());
			}
		}
		onExited: {
			launcher.readListed(listedText.text);
			const own = launcher.owning?.own;
			if (own && !own.item && (own.mode !== mode || own.live && launcher.owning.query !== asked))
				launcher.listOwn();
			if (launcher.shown)
				launcher.search();
		}
	}

	// Plugins' QML modes, each as long as its plugin is on.
	Instantiator {
		id: pluginModes

		model: Plugins.running.filter(plugin => plugin.launcher !== "")
		onObjectAdded: launcher.gatherModes()
		onObjectRemoved: Qt.callLater(launcher.gatherModes)

		Loader {
			required property var modelData
			readonly property string name: modelData.name

			source: modelData.launcher
			onLoaded: launcher.gatherModes()
		}
	}

	// A QML mode says when its rows changed, and the list follows while it's open.
	Connections {
		target: launcher.owning?.own.item ?? null
		ignoreUnknownSignals: true

		function onChanged() {
			if (launcher.shown)
				launcher.refresh();
		}
	}

	FileView {
		id: lines

		blockLoading: true
		printErrors: false
	}

	// Only names until /wall has them show.
	FolderListModel {
		id: pictures

		folder: Settings.url(Settings.pictures)
		nameFilters: ["*.bmp", "*.gif", "*.jpeg", "*.jpg", "*.png", "*.webp"]
		caseSensitive: false
		sortCaseSensitive: false
		showDirs: false
		onCountChanged: {
			if (launcher.shown && /^\s*\/wall\s/i.test(field.text))
				launcher.search();
		}
	}

	TextField {
		id: field

		width: parent.width
		focus: true
		icon: "search"
		placeholder: launcher.picking ? launcher.picking.prompt || "Pick one" : launcher.grouped ? `Search in ${launcher.grouped.text}` : "Search, or / for more"
		secret: launcher.hiding
		shifted: true
		trailing: folders.visible ? folders.width + Theme.u(2) : 0
		// No sums of what a script is told, a password least of all.
		onTextChanged: {
			Calculator.ask(launcher.picking ? "" : text);
			launcher.menuOf = null;
			launcher.grouping = false;
			launcher.search();
		}
		// With nothing found for a script, what's typed is the answer, but for one
		// that wants a line or where it is.
		onAccepted: {
			if (launcher.picking && list.count === 0) {
				launcher.answer(launcher.picking.onlyMatch || launcher.picking.index ? "" : text);
				launcher.hide();
			} else {
				list.activate(list.currentIndex);
			}
		}
		onShiftAccepted: launcher.openMenu(list.entry(list.currentIndex))
		Keys.onUpPressed: list.move(-1)
		Keys.onDownPressed: list.move(1)
		// A screenful of the rows at once, and Ctrl with N and P as the arrows, as
		// other launchers have them.
		Keys.onPressed: event => {
			const ctrl = !!(event.modifiers & Qt.ControlModifier);
			if (event.key === Qt.Key_PageDown)
				list.page(1);
			else if (event.key === Qt.Key_PageUp)
				list.page(-1);
			else if (ctrl && event.key === Qt.Key_N)
				list.move(1);
			else if (ctrl && event.key === Qt.Key_P)
				list.move(-1);
			else if (ctrl && event.key === Qt.Key_G)
				launcher.toggleGroups();
			else
				return;
			event.accepted = true;
		}
		Keys.onEscapePressed: event => {
			if (launcher.menuOf)
				launcher.closeMenu();
			else if (launcher.grouping) {
				launcher.grouping = false;
				launcher.search();
			} else if (launcher.group !== "")
				launcher.pickGroup("");
			else
				event.accepted = false;
		}

		// The groups apps go by, in the list's place: the one that's on says so here.
		Button {
			id: folders

			anchors.right: parent.right
			anchors.rightMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			height: parent.height - Theme.u(8)
			visible: !launcher.picking && Apps.groups.length > 0
			flat: !launcher.grouped && !launcher.grouping
			activeFocusOnTab: false
			icon: "apps"
			text: launcher.grouped ? launcher.grouped.text : ""
			longest: Theme.u(120)
			tip: Tr.t("Groups · Ctrl+G")
			onClicked: launcher.toggleGroups()
		}
	}

	// As tall with one app as with many: on a centered panel the field would
	// move with each keystroke.
	Item {
		width: parent.width
		height: list.rowHeight * 8

		List {
			id: list

			anchors.fill: parent
			rowHeight: Theme.u(46)
			iconSize: Theme.u(26)
			activeFocusOnTab: false
			model: ScriptModel {
				id: found

				objectProp: "key"
			}

			add: Transition {
				enabled: Theme.animate

				NumberAnimation {
					property: "opacity"
					from: 0
					to: 1
					duration: Theme.ms(120)
				}
			}

			displaced: Transition {
				enabled: Theme.animate

				NumberAnimation {
					property: "y"
					duration: Theme.ms(120)
					easing.type: Easing.OutCubic
				}
			}

			onMenuAsked: (index, row) => launcher.openMenu(row)

			onActivated: (index, row) => {
				// The rows still take clicks as the panel fades: a double click does.
				if (!launcher.shown)
					return;
				if (row.pick !== undefined) {
					launcher.answer(launcher.picking.index ? String(row.at) : row.pick);
					launcher.hide();
					return;
				}
				if (row.mode) {
					field.text = `/${row.mode} `;
					return;
				}
				if (row.group !== undefined) {
					launcher.pickGroup(row.group);
					return;
				}
				if (row.back || row.pinning || row.hiding || row.docking || row.folding) {
					if (row.folding)
						Apps.fold(launcher.menuOf.id, row.folder, row.fold);
					else if (row.pinning)
						Apps.pin(launcher.menuOf.id, row.pin);
					else if (row.docking)
						Apps.dock(launcher.menuOf.id, row.dock);
					else if (row.hiding)
						Apps.hide(launcher.menuOf.id, true);
					launcher.closeMenu();
					return;
				}
				// From the app's menu, or a row of the search.
				if (row.action)
					Apps.launch(launcher.menuOf ?? row.entry, row.action);
				else if (row.window)
					Niri.focusWindow(row.window);
				else if (row.session)
					Session.asked(row.session);
				else if (row.sum)
					Calculator.take();
				else if (row.copy)
					Calculator.copy(row.copy);
				else if (row.wallpaper)
					Theme.hang(row.wallpaper);
				else if (row.file)
					Env.act("open file", () => Niri.spawn(["xdg-open", row.file]));
				else if (row.shot)
					Screenshots.open(row.shot);
				else if (row.clip) {
					Clipboard.restore(row.clip);
					if (Settings.clipboard.paste)
						Clipboard.paste();
				} else if (row.settings !== undefined)
					Settings.sought(row.settings);
				else if (row.emoji)
					Emoji.put(row.emoji);
				else if (row.does) {
					row.does();
					if (row.stays)
						return;
				}
				else
					Apps.launch(row.entry);
				launcher.hide();
			}
		}

		Text {
			anchors.centerIn: parent
			visible: list.count === 0
			text: /^\s*\/calc(\s|$)/i.test(field.text) && Env.lacks("qalc") ? Tr.t("Sums need qalc, which isn't here")
				: /^\s*\/ps(\s|$)/i.test(field.text) && Processes.list.length === 0 ? "Looking..."
				: launcher.owning && !launcher.owning.own.item && (lister.running || listing.running || launcher.listed.mode !== launcher.owning.own.mode) ? "Looking..."
				: !/^\s*\/file(\s|$)/i.test(field.text) ? "Nothing found"
				: launcher.filing.length < 2 ? "Two letters of a file's name, or more"
				: looking.running || finder.running ? "Looking..." : "Nothing found"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

	}
}
