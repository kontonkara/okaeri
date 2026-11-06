pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What everything on screen is drawn with: themes/dark.json (it has every
// key), the built-in theme the user's okaeri/theme.json extends, and that
// file itself, which takes effect as it's saved. Colors merge key by key.
Singleton {
	id: theme

	function parse(text, file) {
		try {
			return JSON.parse(text);
		} catch (error) {
			console.warn(`okaeri: can't read ${file}: ${error.message}`);
			return {};
		}
	}

	FileView {
		id: darkFile

		path: Quickshell.shellPath("themes/dark.json")
		blockLoading: true
	}

	FileView {
		id: lightFile

		path: Quickshell.shellPath("themes/light.json")
		blockLoading: true
	}

	FileView {
		id: userFile

		path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/okaeri/theme.json`
		blockLoading: true
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: theme.user = theme.parse(text(), path)
		onLoadFailed: theme.user = {}
	}

	readonly property var builtIn: ({
		dark: parse(darkFile.text(), darkFile.path),
		light: parse(lightFile.text(), lightFile.path)
	})
	property var user: ({})

	onUserChanged: {
		if (user.extends && !(user.extends in builtIn))
			console.warn(`okaeri: no theme "${user.extends}", it's one of ${Object.keys(builtIn).join(", ")}`);
	}

	readonly property var parent: builtIn[user.extends] || {}
	readonly property var values: Object.assign({}, builtIn.dark, parent, user, {
		colors: Object.assign({}, builtIn.dark.colors, parent.colors, user.colors)
	})

	readonly property var colors: values.colors
	readonly property string font: values.font || Qt.application.font.family
	readonly property real fontSize: u(values.fontSize)
	readonly property int fontWeight: values.fontWeight
	readonly property bool animate: !!values.animations
	// Panels let what's under them through, blurred, where the compositor has that.
	// In niri that's the wallpaper, unless a rule for okaeri-panel says xray false.
	readonly property bool blur: !!values.blur
	readonly property real barHeight: u(values.barHeight)
	readonly property real barMargin: u(values.barMargin)
	readonly property real barIcon: u(values.barIcon)

	// How far what opens stays from the sides of the screen, as the bar does, and
	// where it starts under it. Whole pixels: at a fraction its edges would smear.
	readonly property int edge: Math.round(barMargin)
	readonly property int below: Math.round(barMargin + barHeight + u(4))

	// `n` pixels at the UI scale.
	function u(n) {
		return n * values.scale;
	}

	// The theme's corner radius at the UI scale, or -1 for round.
	readonly property real radius: typeof values.radius === "number" ? u(values.radius) : -1

	// What a panel is filled with, and what's on it.
	readonly property color panel: Qt.alpha(colors.background, blur ? 0.72 : 1)
	readonly property color surface: Qt.alpha(colors.surface, blur ? 0.6 : 1)
	// Under the pointer, pressed, and the edge of a card.
	readonly property color hover: Qt.alpha(colors.text, 0.08)
	readonly property color pressed: Qt.alpha(colors.text, 0.16)
	readonly property color border: Qt.alpha(colors.text, 0.1)

	// The corners of a card, and of what sits in one.
	readonly property real cardRadius: radius < 0 ? u(14) : radius

	// The corner radius for something `size` across: round, unless the theme
	// sets one; `inset`, how far inside a rounded thing it sits.
	function round(size, inset) {
		return radius < 0 ? size / 2 : Math.min(size / 2, Math.max(0, radius - (inset || 0)));
	}

	// Line icons on a 24x24 grid, as SVG paths, for Icon.
	readonly property var icons: ({
		alert: "M12 4l9.5 16.5h-19z M12 10v5 M12 18h.01",
		apps: "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z",
		back: "M15 6l-6 6 6 6",
		bar: "M3 5h18v5H3z M3 14h18 M3 19h18",
		bell: "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9z M10.3 21a2 2 0 0 0 3.4 0",
		bellOff: "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9z M10.3 21a2 2 0 0 0 3.4 0 M3 3l18 18",
		bluetooth: "M7 7l10 10-5 5V2l5 5L7 17",
		bluetoothOff: "M7 7l10 10-5 5V2l5 5L7 17 M3 3l18 18",
		bolt: "M13 3L5 13h6l-1 8 8-10h-6l1-8z",
		calculator: "M6 3h12v18H6z M9 7h6 M9 12h.01 M12 12h.01 M15 12h.01 M9 16h.01 M12 16h.01 M15 16h.01",
		capsLock: "M12 4l7 8h-4v4H9v-4H5z M9 20h6",
		cast: "M3 9V6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-6 M3 13a7 7 0 0 1 7 7 M3 17a3 3 0 0 1 3 3",
		check: "M5 12.5l4.5 4.5L19 7.5",
		chevron: "M9 6l6 6-6 6",
		chip: "M8 8h8v8H8z M10 4v4 M14 4v4 M10 16v4 M14 16v4 M4 10h4 M4 14h4 M16 10h4 M16 14h4",
		clipboard: "M9 4h6v3H9z M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2",
		close: "M6 6l12 12 M18 6L6 18",
		coffee: "M4 9h12v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z M16 10h2a3 3 0 0 1 0 6h-2 M8 3v3 M12 3v3",
		eye: "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z",
		eyeOff: "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z M4 4l16 16",
		gear: "M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z",
		image: "M4 5h16v14H4z M4 16l5-5 4 4 3-3 4 4 M15 9h.01",
		keyboard: "M3 7h18v10H3z M7 11h.01 M11 11h.01 M15 11h.01 M8 14h8",
		lock: "M7 11V7a5 5 0 0 1 10 0v4 M5 11h14v10H5z",
		logout: "M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4 M15 8l4 4-4 4 M19 12H9",
		mic: "M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z M5 11a7 7 0 0 0 14 0 M12 18v3",
		micOff: "M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z M5 11a7 7 0 0 0 14 0 M12 18v3 M3 3l18 18",
		moon: "M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z",
		numLock: "M5 9h14 M5 15h14 M10 4L8 20 M16 4l-2 16",
		power: "M12 3v8 M17.66 6.34A8 8 0 1 1 6.34 6.34",
		refresh: "M20 12a8 8 0 1 1-2.34-5.66L20 8.5 M20 4v4.5h-4.5",
		search: "M11 4a7 7 0 1 0 0 14 7 7 0 1 0 0-14z M20 20l-3.9-3.9",
		sliders: "M4 7h10 M18 7h2 M14 5v4h4V5z M4 17h2 M10 17h10 M6 15v4h4v-4z",
		sun: "M12 8a4 4 0 1 0 0 8 4 4 0 1 0 0-8z M12 2.5v2 M12 19.5v2 M2.5 12h2 M19.5 12h2 M5.3 5.3l1.4 1.4 M17.3 17.3l1.4 1.4 M5.3 18.7l1.4-1.4 M17.3 6.7l1.4-1.4",
		trash: "M4 7h16 M9 7V4h6v3 M6 7l1 14h10l1-14",
		tray: "M4 13l2-8h12l2 8v6H4z M4 13h5l1 2h4l1-2h5",
		volume: "M4 9.5v5h3.5l4.5 4v-13l-4.5 4z M16 9a4.2 4.2 0 0 1 0 6 M18.5 6.5a7.8 7.8 0 0 1 0 11",
		volumeOff: "M4 9.5v5h3.5l4.5 4v-13l-4.5 4z M16.5 9.5l5 5 M21.5 9.5l-5 5",
		wifi: "M2 8.8a15 15 0 0 1 20 0 M5 12.6a10 10 0 0 1 14 0 M8.5 16.2a5 5 0 0 1 7 0 M12 20h.01",
		wifiOff: "M2 8.8a15 15 0 0 1 20 0 M5 12.6a10 10 0 0 1 14 0 M8.5 16.2a5 5 0 0 1 7 0 M12 20h.01 M3 3l18 18"
	})
}
