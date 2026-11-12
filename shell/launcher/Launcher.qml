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
// show a script's lines instead, to pick one of, which the script is told. The
// field keeps the keys, Up and Down reach the list from it.
Panel {
	id: launcher

	// What a / in front asks for.
	readonly property var modes: [
		{ mode: "calc", text: "Sums", subtext: "/calc and the sum, or the last ones", icon: "calculator" },
		{ mode: "win", text: "Open windows", subtext: "/win: Enter goes to one, Shift+Enter closes it", icon: "apps" },
		{ mode: "wall", text: "Wallpapers", subtext: "/wall", icon: "image" },
		{ mode: "emoji", text: "Emoji and symbols", subtext: "/emoji and a name: Enter types it and copies it, Shift+Enter only copies", icon: "text" },
		{ mode: "clip", text: "Clipboard", subtext: "/clip and what was copied: Enter copies it again, Shift+Enter the other of that and pasting", icon: "clipboard" },
		{ mode: "file", text: "Files", subtext: "/file and a part of the name: Enter opens it, Shift+Enter its folder", icon: "file" },
		{ mode: "set", text: "Settings", subtext: "/set and what to look for", icon: "gear" },
		{ mode: "session", text: "Session", subtext: "/session", icon: "power" }
	]
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
				subtext: [Apps.entryOf(w.app_id)?.name || w.app_id || "Window"].concat(where).join(" · "),
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
			subtext: "Session",
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
				found.push({ wallpaper: pictures.get(index, "filePath"), text: name, subtext: "Wallpaper", image: pictures.get(index, "fileUrl"), icon: "image" });
		}
		return found;
	}

	function emoji(wanted) {
		return Emoji.search(wanted, Apps.limit).map(([character, name]) => ({
			emoji: character,
			glyph: character,
			text: name.replace(/ \(symbol\)$/, ""),
			subtext: name.endsWith("(symbol)") ? "Symbol" : "Emoji"
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
			subtext: entry.subtext || (entry.pinned ? "Pinned" : "Copied"),
			icon: "clipboard",
			mark: entry.id
		}));
	}

	// The settings window, on what's looked for.
	function settings(wanted) {
		return [{ settings: wanted, text: wanted ? `Look for "${wanted}" in the settings` : "Open the settings", subtext: "Settings", icon: "gear" }];
	}

	// What else `entry` can do.
	function menu(entry) {
		const pinned = Settings.launcher.pinned.includes(entry.id);
		const docked = Settings.dock.pinned.includes(entry.id);
		return [{ back: true, text: "Back", subtext: entry.name, icon: "back" }].concat(Array.from(entry.actions).map(action => ({
			action,
			text: action.name,
			image: Apps.image(action.icon),
			icon: "apps"
		})), [
			{ pin: !pinned, pinning: true, text: pinned ? "Unpin" : "Pin to the top", icon: "pin" },
			{ hiding: true, text: "Hide from the launcher", icon: "eyeOff" },
			{ dock: !docked, docking: true, text: docked ? "Take off the dock" : "Keep on the dock", icon: "apps" }
		]);
	}

	// What goes by what's typed: the sum, the apps, and after them the open windows
	// and what the session can do, or with a / what that asks for.
	function typed() {
		const text = field.text;
		const wanted = text.trim().toLowerCase();
		if (picking)
			return picks(wanted);
		const asked = text.match(/^\s*\/(\S*)(\s+.*)?$/);
		if (!asked)
			return sum().concat(Apps.search(text), wanted ? windows(wanted) : [], wanted.length < 2 ? [] : session(wanted));
		if (asked[2] === undefined)
			return modes.filter(row => row.mode.startsWith(asked[1].toLowerCase()));
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
		}
		return [];
	}

	function rows() {
		// What tells rows apart, so one that stays from a search to the next moves
		// instead of being made anew: all that shows on it.
		return (menuOf ? menu(menuOf) : typed()).map(row => Object.assign({
			key: [row.text, row.subtext, row.entry?.id, row.action?.id, row.window, row.session?.text, row.mark].join("|")
		}, row));
	}

	// Not a binding: an app moving up for its launch would show as the panel
	// fades.
	function search() {
		found.values = rows();
		list.currentIndex = 0;
		list.positionViewAtBeginning();
	}

	// The same search over apps that came or went, on the same app if it's there.
	function refresh() {
		const selected = found.values[list.currentIndex]?.entry?.id;
		search();
		list.currentIndex = Math.max(0, found.values.findIndex(row => row.entry?.id === selected));
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
	// thing there is to do with it: a file's folder opens, what was copied is
	// pasted where Enter copies and copied where it pastes, and an emoji is only
	// copied. A window closes, and the launcher stays on the rest of them.
	function otherWay(row) {
		if (row?.window) {
			Env.act("close window", () => Niri.closeWindow(row.window));
			return;
		}
		if (row?.file)
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
		field.text = "";
		hiding = false;
		field.revealed = false;
		list.pointer = null;
		field.take();
		search();
	}

	// This also has Apps start now, and read the apps before the first opening.
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
		placeholder: launcher.picking ? launcher.picking.prompt || "Pick one" : "Search, or / for more"
		secret: launcher.hiding
		shifted: true
		// No sums of what a script is told, a password least of all.
		onTextChanged: {
			Calculator.ask(launcher.picking ? "" : text);
			launcher.menuOf = null;
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
			else
				return;
			event.accepted = true;
		}
		Keys.onEscapePressed: event => {
			if (launcher.menuOf)
				launcher.closeMenu();
			else
				event.accepted = false;
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
				if (row.back || row.pinning || row.hiding || row.docking) {
					if (row.pinning)
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
				else if (row.clip) {
					Clipboard.restore(row.clip);
					if (Settings.clipboard.paste)
						Clipboard.paste();
				} else if (row.settings !== undefined)
					Settings.sought(row.settings);
				else if (row.emoji)
					Emoji.put(row.emoji);
				else
					Apps.launch(row.entry);
				launcher.hide();
			}
		}

		Text {
			anchors.centerIn: parent
			visible: list.count === 0
			text: /^\s*\/calc(\s|$)/i.test(field.text) && Env.lacks("qalc") ? "Sums need qalc, which isn't here"
				: !/^\s*\/file(\s|$)/i.test(field.text) ? "Nothing found"
				: launcher.filing.length < 2 ? "Two letters of a file's name, or more"
				: looking.running || finder.running ? "Looking..." : "Nothing found"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

	}
}
