import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// What's in Settings, to change in place, a page at a time. A change stays over
// what the config says, and the button under the pages goes back to that. It's a
// window, not a panel: the compositor's keys go to it and not to what's under it,
// and it stays while what it changes is looked at.
FloatingWindow {
	id: window

	readonly property var pages: [
		{ text: "Bar", icon: "bar", page: barPage },
		{ text: "Tray", icon: "tray", page: trayPage },
		{ text: "Control center", icon: "sliders", page: controlPage },
		{ text: "Launcher", icon: "search", page: launcherPage },
		{ text: "Clipboard", icon: "clipboard", page: clipboardPage },
		{ text: "Notifications", icon: "bell", page: notificationsPage },
		{ text: "Sounds", icon: "volume", page: soundsPage },
		{ text: "On-screen display", icon: "osd", page: osdPage },
		{ text: "Display", icon: "sunset", page: displayPage },
		{ text: "Wallpaper", icon: "image", page: wallpaperPage },
		{ text: "Look", icon: "eye", page: lookPage },
		{ text: "Session", icon: "lock", page: sessionPage }
	]
	property int page: 0
	// What the screen in focus has room for, and the least it's made.
	readonly property size room: Qt.size((Niri.focusedScreen?.width ?? Infinity) - Theme.u(48), (Niri.focusedScreen?.height ?? Infinity) - Theme.below - Theme.edge - Theme.u(24))
	readonly property size least: Qt.size(Math.round(Math.min(Theme.u(640), room.width)), Math.round(Math.min(Theme.u(440), room.height)))
	// The size it was last given, kept in the state directory; until there's one
	// it's a size of its own. niri lets it be made another: okaeri's rules for
	// niri have it float.
	property var kept: null
	// What it was given as it opened: only another size is one to keep.
	property size given
	// What's looked for, and every line and card there is to find, by its page:
	// { page, text, subtext, part }, read off the pages as the first search starts;
	// `part` is a part of the bar whose card has it.
	property string query: ""
	property var found: []
	readonly property var results: {
		const words = query.trim().toLowerCase().split(/\s+/).filter(word => word !== "");
		if (words.length === 0)
			return [];
		return found.filter(entry => words.every(word => `${entry.text} ${entry.subtext} ${where(entry)}`.toLowerCase().includes(word))).slice(0, 60);
	}
	// The line to bring into sight once its page is there, and the part of the
	// bar to choose first for it.
	property string seeking: ""
	property string choosing: ""

	// Each page made once, out of sight, for what's on it.
	function index() {
		if (found.length > 0)
			return;
		const all = [];
		pages.forEach((entry, page) => {
			const made = entry.page.createObject(indexing, { width: Theme.u(560), height: Theme.u(2000) });
			if (!made)
				return;
			gather(made, page, all, "");
			// The bar's parts have cards of their own, made as one is chosen.
			for (const [part, card] of Object.entries(made.partSettings ?? {})) {
				const madeCard = card.createObject(made, { width: Theme.u(520) });
				if (madeCard) {
					gather(madeCard, page, all, part);
					madeCard.destroy();
				}
			}
			made.destroy();
		});
		found = all.filter((entry, at) => all.findIndex(other => other.page === entry.page && other.text === entry.text && other.part === entry.part) === at);
	}

	// Where an entry is, in words: its page, and its part of the bar.
	function where(entry) {
		const part = entry.part ? barPartName(entry.part) : "";
		return part ? `${pages[entry.page].text} · ${part}` : pages[entry.page].text;
	}

	function barPartName(part) {
		return ({ clock: "Clock", workspaces: "Workspaces", battery: "Battery", media: "Media", network: "Network", system: "System load", bluetooth: "Bluetooth" })[part] ?? part;
	}

	// A line has a text and a subtext; a card has a title.
	function gather(item, page, all, part) {
		if (!item)
			return;
		if (typeof item.text === "string" && item.text !== "" && item.subtext !== undefined)
			all.push({ page, part, text: item.text, subtext: item.subtext || "" });
		else if (typeof item.title === "string" && item.title !== "" && item.padding !== undefined)
			all.push({ page, part, text: item.title, subtext: "" });
		for (const child of item.children ?? [])
			gather(child, page, all, part);
	}

	// Its page, and the line on it in sight.
	function open(entry) {
		seeking = entry.text;
		choosing = entry.part;
		query = "";
		if (page === entry.page)
			sought();
		else
			page = entry.page;
	}

	// The page that shows has a line to bring into sight.
	signal sought

	// A size that fits: the kept one, or the first one.
	function fitted() {
		const wanted = kept ?? { width: Theme.u(1000), height: Theme.u(700) };
		return Qt.size(Math.round(Math.max(least.width, Math.min(wanted.width, room.width))), Math.round(Math.max(least.height, Math.min(wanted.height, room.height))));
	}

	// Opened anew, so one left on another workspace comes here, with the focus.
	function show() {
		visible = false;
		fade.stop();
		veil.opacity = Theme.blur && Theme.realBlur ? 1 : 0;
		keptFile.reload();
		try {
			const read = JSON.parse(keptFile.text());
			if (read.width > 0 && read.height > 0)
				kept = { width: read.width, height: read.height };
		} catch (error) {}
		const size = fitted();
		given = size;
		implicitWidth = size.width;
		implicitHeight = size.height;
		visible = true;
		opening.restart();
	}

	function toggle() {
		if (visible)
			visible = false;
		else
			show();
	}

	title: "Settings"
	visible: false
	minimumSize: least
	onWidthChanged: keeping.restart()
	onHeightChanged: keeping.restart()
	// The fill is on an item: a window that was solid when it first showed stays so.
	color: "transparent"
	// Asked for as it shows: asked for while it's hidden, it's lost once it has shown
	// without.
	BackgroundEffect.blurRegion: Theme.blur && visible ? glass : null

	FileView {
		id: keptFile

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/settings-window.json`
		// Read anew as it opens, there and then: it may have come since.
		blockAllReads: true
		printErrors: false
	}

	// Once it's done being made another size.
	Timer {
		id: keeping

		interval: 500
		onTriggered: {
			if (!window.visible || window.width <= 0 || window.height <= 0)
				return;
			const size = { width: Math.round(window.width), height: Math.round(window.height) };
			if (size.width === window.given.width && size.height === window.given.height)
				return;
			window.kept = size;
			keptFile.setText(JSON.stringify(size) + "\n");
		}
	}

	Region {
		id: glass

		item: window.contentItem
		radius: Theme.cardRadius
	}

	Connections {
		target: Settings

		function onAsked() {
			window.show();
		}
	}

	IpcHandler {
		target: "settings"

		function toggle(): void {
			window.toggle();
		}

		// For tests: how much of the veil is there.
		function veiled(): real {
			return veil.opacity;
		}

		// For tests: the page that shows, by its name.
		function shown(): string {
			return window.pages[window.page].text;
		}
	}

	// Where pages are made for the search to read.
	Item {
		id: indexing

		visible: false
	}

	Rectangle {
		anchors.fill: parent
		color: Theme.panel
	}

	// niri can't blur what's under a window while it opens, only the wallpaper: as
	// that ended the blur would come in at once. Until then it's solid, and then
	// it goes clear.
	Rectangle {
		id: veil

		anchors.fill: parent
		visible: opacity > 0
		color: Theme.colors.background
		opacity: 0
	}

	// A little longer than niri takes by default, or with the animation changed.
	Timer {
		id: opening

		interval: 300
		onTriggered: fade.restart()
	}

	NumberAnimation {
		id: fade

		target: veil
		property: "opacity"
		to: 0
		duration: Theme.animate ? 200 : 0
		easing.type: Easing.OutCubic
	}

	Component {
		id: barPage

		BarPage {
			onOpens: name => window.page = window.pages.findIndex(entry => entry.text === name)
		}
	}

	Component {
		id: trayPage

		TrayPage {}
	}

	Component {
		id: controlPage

		ControlPage {}
	}

	Component {
		id: launcherPage

		LauncherPage {}
	}

	Component {
		id: clipboardPage

		ClipboardPage {}
	}

	Component {
		id: notificationsPage

		NotificationsPage {}
	}

	Component {
		id: soundsPage

		SoundsPage {}
	}

	Component {
		id: displayPage

		DisplayPage {}
	}

	Component {
		id: osdPage

		OsdPage {}
	}

	Component {
		id: lookPage

		LookPage {}
	}

	Component {
		id: wallpaperPage

		WallpaperPage {}
	}

	Component {
		id: sessionPage

		SessionPage {}
	}

	Loader {
		anchors.fill: parent
		anchors.margins: Math.round(Theme.u(12))
		active: window.visible
		focus: true

		sourceComponent: FocusScope {
			focus: true

			Keys.onEscapePressed: window.visible = false

			// A line on the page, by its text, the first there is.
			function line(item, text) {
				if (!item)
					return null;
				if ((item.text === text && item.subtext !== undefined) || (item.title === text && item.padding !== undefined))
					return item;
				for (const child of item.children ?? []) {
					const found = line(child, text);
					if (found)
						return found;
				}
				return null;
			}

			// The line that was looked for, scrolled to where it shows and lit up a
			// moment.
			function reveal() {
				// A part's card comes once it's chosen, a moment later.
				if (window.choosing !== "" && content.item.chosen !== undefined) {
					content.item.chosen = window.choosing;
					window.choosing = "";
					choosing.restart();
					return;
				}
				const item = line(content.item, window.seeking);
				window.seeking = "";
				if (!item)
					return;
				const view = content.item;
				if (view.contentY !== undefined) {
					const at = item.mapToItem(view.contentItem, 0, 0).y;
					view.contentY = Math.max(0, Math.min(at - Theme.u(16), view.contentHeight - view.height));
				}
				const where = item.mapToItem(content, 0, 0);
				mark.x = content.x + where.x - Theme.u(4);
				mark.y = where.y - Theme.u(4);
				mark.width = item.width + Theme.u(8);
				mark.height = item.height + Theme.u(8);
				lighting.restart();
			}

			Timer {
				id: choosing

				interval: 600
				onTriggered: reveal()
			}

			Connections {
				target: window

				function onSought() {
					Qt.callLater(reveal);
				}

				// Emptied as a result is picked.
				function onQueryChanged() {
					if (search.text !== window.query)
						search.text = window.query;
				}
			}

			TextField {
				id: search

				width: menu.width
				implicitHeight: Theme.u(34)
				icon: "search"
				placeholder: "Search"
				onTextChanged: {
					if (text !== "")
						window.index();
					window.query = text;
				}
				onAccepted: {
					if (window.results.length > 0)
						window.open(window.results[0]);
				}
				Keys.onEscapePressed: event => {
					if (text !== "")
						text = "";
					else
						event.accepted = false;
				}
				Keys.onDownPressed: found.forceActiveFocus()
			}

			List {
				id: found

				anchors.top: search.bottom
				anchors.topMargin: Theme.u(8)
				anchors.bottom: back.top
				width: menu.width
				visible: window.query !== ""
				rowHeight: Theme.u(40)
				model: window.results.map(entry => ({ entry, text: entry.text, subtext: window.where(entry) }))
				onActivated: (index, row) => window.open(row.entry)

				Text {
					parent: found
					anchors.centerIn: parent
					visible: found.count === 0
					text: "Nothing found"
					color: Theme.colors.subtext
					font.family: Theme.font
					font.pixelSize: Theme.fontSize - Theme.u(2)
				}
			}

			Column {
				id: menu

				anchors.top: search.bottom
				anchors.topMargin: Theme.u(8)
				width: Theme.u(170)
				visible: window.query === ""
				spacing: Theme.u(4)

				Repeater {
					model: window.pages

					Button {
						required property int index
						required property var modelData

						width: parent.width
						atStart: true
						pad: Theme.u(10)
						flat: index !== window.page
						icon: modelData.icon
						text: modelData.text
						onClicked: window.page = index
					}
				}
			}

			Button {
				id: back

				anchors.bottom: parent.bottom
				width: menu.width
				enabled: Object.keys(Settings.own).length + Object.keys(Theme.own).length > 0
				atStart: true
				pad: Theme.u(10)
				flat: true
				text: "Back to the config"
				onClicked: {
					Settings.reset();
					Theme.reset();
				}
			}

			Loader {
				id: content

				x: menu.width + Math.round(Theme.u(12))
				width: parent.width - x
				height: parent.height
				sourceComponent: window.pages[window.page].page
				transform: Translate {
					id: slide
				}
				onLoaded: {
					if (Theme.animate)
						appear.restart();
					if (window.seeking !== "")
						Qt.callLater(reveal);
				}
			}

			// Where what was looked for is.
			Rectangle {
				id: mark

				radius: Theme.round(height)
				color: "transparent"
				border.width: Theme.u(2)
				border.color: Theme.colors.accent
				opacity: 0
			}

			SequentialAnimation {
				id: lighting

				NumberAnimation {
					target: mark
					property: "opacity"
					to: 1
					duration: Theme.animate ? 120 : 0
				}

				PauseAnimation {
					duration: 1200
				}

				NumberAnimation {
					target: mark
					property: "opacity"
					to: 0
					duration: Theme.animate ? 400 : 0
				}
			}

			// A new page comes up a little, out of nothing.
			ParallelAnimation {
				id: appear

				NumberAnimation {
					target: content
					property: "opacity"
					from: 0
					to: 1
					duration: 140
					easing.type: Easing.OutCubic
				}

				NumberAnimation {
					target: slide
					property: "y"
					from: Theme.u(8)
					to: 0
					duration: 180
					easing.type: Easing.OutCubic
				}
			}
		}
	}
}
