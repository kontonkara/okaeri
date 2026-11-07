import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui

// The app launcher: what's typed picks from the apps and Enter launches the
// selected one, copies the answer to a sum, or goes to an open window or to the
// session menu. A / in front asks for one kind of thing alone, and alone it says
// which there are. A right click or Shift+Enter on an app shows what else it can
// do, in the list's place. The field keeps the keys, Up and Down reach the list
// from it.
Panel {
	id: launcher

	// What a / in front asks for.
	readonly property var modes: [
		{ mode: "calc", text: "Sums", subtext: "/calc and the sum, or the last ones", icon: "calculator" },
		{ mode: "win", text: "Open windows", subtext: "/win", icon: "apps" },
		{ mode: "wall", text: "Wallpapers", subtext: "/wall", icon: "image" },
		{ mode: "session", text: "Session", subtext: "/session", icon: "power" }
	]
	// The app whose menu is in the list's place, if one is.
	property var menuOf: null

	function windows(wanted) {
		return Niri.windows.filter(w => [w.title, w.app_id].some(text => (text || "").toLowerCase().includes(wanted))).map(w => ({
			window: w.id,
			text: w.title,
			subtext: "Open window",
			image: Apps.imageOf(w.app_id),
			icon: "apps"
		}));
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

	// What else `entry` can do.
	function menu(entry) {
		const pinned = Settings.launcher.pinned.includes(entry.id);
		return [{ back: true, text: "Back", subtext: entry.name, icon: "back" }].concat(Array.from(entry.actions).map(action => ({
			action,
			text: action.name,
			image: Apps.image(action.icon),
			icon: "apps"
		})), [
			{ pin: !pinned, pinning: true, text: pinned ? "Unpin" : "Pin to the top", icon: "pin" },
			{ hiding: true, text: "Hide from the launcher", icon: "eyeOff" }
		]);
	}

	// What goes by what's typed: the sum, the apps, and after them the open windows
	// and what the session can do, or with a / what that asks for.
	function typed() {
		const text = field.text;
		const wanted = text.trim().toLowerCase();
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
		case "session":
			return session(query);
		}
		return [];
	}

	function rows() {
		// What tells rows apart, so one that stays from a search to the next moves
		// instead of being made anew: all that shows on it.
		return (menuOf ? menu(menuOf) : typed()).map(row => Object.assign({
			key: [row.text, row.subtext, row.entry?.id, row.window, row.session?.text, row.mark].join("|")
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
		}
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

	onPanelOpened: {
		Session.check();
		menuOf = null;
		field.text = "";
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

		// For tests: how far down the list is.
		function scrolled(): real {
			return list.contentY;
		}
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
		placeholder: "Search, or / for more"
		shifted: true
		onTextChanged: {
			Calculator.ask(text);
			launcher.menuOf = null;
			launcher.search();
		}
		onAccepted: list.activate(list.currentIndex)
		onShiftAccepted: launcher.openMenu(list.entry(list.currentIndex))
		Keys.onUpPressed: list.move(-1)
		Keys.onDownPressed: list.move(1)
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
					duration: 120
				}
			}

			displaced: Transition {
				enabled: Theme.animate

				NumberAnimation {
					property: "y"
					duration: 120
					easing.type: Easing.OutCubic
				}
			}

			onMenuAsked: (index, row) => launcher.openMenu(row)

			onActivated: (index, row) => {
				// The rows still take clicks as the panel fades: a double click does.
				if (!launcher.shown)
					return;
				if (row.mode) {
					field.text = `/${row.mode} `;
					return;
				}
				if (row.back || row.pinning || row.hiding) {
					if (row.pinning)
						Apps.pin(launcher.menuOf.id, row.pin);
					else if (row.hiding)
						Apps.hide(launcher.menuOf.id, true);
					launcher.closeMenu();
					return;
				}
				if (row.action)
					Apps.launch(launcher.menuOf, row.action);
				else if (row.window)
					Niri.focusWindow(row.window);
				else if (row.session)
					Session.asked(row.session);
				else if (row.sum)
					Calculator.take();
				else if (row.copy)
					Calculator.copy(row.copy);
				else if (row.wallpaper)
					Settings.set("wallpaper", "path", row.wallpaper);
				else
					Apps.launch(row.entry);
				launcher.hide();
			}
		}

		Text {
			anchors.centerIn: parent
			visible: list.count === 0
			text: "Nothing found"
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize
		}

	}
}
