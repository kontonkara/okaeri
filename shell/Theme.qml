pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What everything on screen is drawn with: themes/dark.json (it has every
// key), the user's okaeri/theme.json, which takes effect as it's saved, and
// over those what the settings window changed, in a file of the shell's own.
// The colors are a palette's, the one the user's file `extends`, with its own
// `colors` over that key by key, or the one chosen in the settings window, or
// the hour's; and the accent can be the wallpaper's.
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
		id: palettesFile

		path: Quickshell.shellPath("themes/palettes.json")
		blockLoading: true
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
		onLoaded: {
			theme.user = theme.parse(text(), path);
			theme.userRead = true;
		}
		onLoadFailed: {
			theme.user = {};
			theme.userRead = true;
		}
	}

	FileView {
		id: ownFile

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/theme.json`
		blockLoading: true
		printErrors: false
		onLoaded: {
			theme.own = theme.parse(text(), path);
			theme.ownRead = true;
		}
		onLoadFailed: {
			theme.own = {};
			theme.ownRead = true;
		}
	}

	// The palettes there are, by name: dark and light, those of
	// themes/palettes.json, and the user's own, `palettes` in their file.
	readonly property var builtIn: Object.assign({
		dark: parse(darkFile.text(), darkFile.path),
		light: parse(lightFile.text(), lightFile.path)
	}, parse(palettesFile.text(), palettesFile.path), user.palettes)
	readonly property var palettes: Object.keys(builtIn)
	property var user: ({})
	property var own: ({})
	property bool userRead: false
	property bool ownRead: false
	// Those come a moment after the start: until then this is the built-in theme.
	readonly property bool ready: userRead && ownRead

	// Undefined takes the key away: what the files say again.
	function set(key, value) {
		const next = Object.assign({}, own, { [key]: value });
		if (value === undefined)
			delete next[key];
		own = next;
		ownFile.setText(JSON.stringify(own, null, "\t") + "\n");
	}

	// Back to what the files say.
	function reset() {
		own = {};
		ownFile.setText("{}\n");
	}

	// Whether the settings window set any of the keys `names`.
	function owns(names) {
		const keys = Object.keys(own);
		return names.some(name => keys.includes(name));
	}

	// Back to what the files say for those keys alone, as the Look page has them,
	// and the rest as it was set.
	function resetKeys(names) {
		if (!owns(names))
			return;
		const kept = Object.assign({}, own);
		names.forEach(name => delete kept[name]);
		own = kept;
		ownFile.setText(JSON.stringify(own, null, "\t") + "\n");
	}

	// With the file's own palettes, which the list above may not have yet.
	onUserChanged: {
		const known = Object.keys(Object.assign({}, builtIn, user.palettes));
		if (user.extends && !known.includes(user.extends))
			console.warn(`okaeri: no theme "${user.extends}", it's one of ${known.join(", ")}`);
	}

	// Everything but the colors, which come from a palette.
	readonly property var plain: Object.assign({}, builtIn.dark, user, own)
	// With `auto`, "time" or "sun", the palette is `day`'s by day and `night`'s
	// by night: from `dayFrom` to `nightFrom` by the clock, or from sunrise to
	// sunset where the night light or the weather is set for, and by the clock
	// where neither is. A minute at a time, and only then.
	readonly property bool timed: plain.auto === "time" || plain.auto === "sun"
	readonly property bool day: {
		if (!timed)
			return false;
		const at = clock.date.getHours() * 60 + clock.date.getMinutes();
		const sun = plain.auto === "sun" ? sunOn(clock.date) : null;
		const from = sun ? sun.rise : minutes(plain.dayFrom);
		const to = sun ? sun.set : minutes(plain.nightFrom);
		return from <= to ? at >= from && at < to : at >= from || at < to;
	}
	// The palette that's on: the hour's, the one the settings window chose, or
	// the one the user's file extends. One chosen here or by the hour is all of
	// the colors: the user's own would be those of one palette on another, unless
	// it's the one their file extends.
	readonly property bool chosen: timed || !!own.extends
	readonly property string named: timed ? (day ? plain.day : plain.night) : own.extends || user.extends || ""
	readonly property var parent: builtIn[named] || {}
	readonly property var palette: Object.assign({}, builtIn.dark.colors, parent.colors, chosen && named !== (user.extends || "dark") ? {} : user.colors)
	readonly property bool light: Qt.color(palette.background).hslLightness > 0.5
	// An accent of one's own, `accent` as "#rrggbb", over any palette's.
	readonly property string accent: /^#[0-9a-fA-F]{6}$/.test(plain.accent ?? "") ? plain.accent : ""
	// Everyone's wallpaper as it is now: the one for a light palette while that's on.
	readonly property string picture: (light && Settings.wallpaper.light) || Settings.wallpaper.path

	// Another in its place: in the setting that has the one that shows.
	function hang(path) {
		Settings.set("wallpaper", light && Settings.wallpaper.light ? "light" : "path", path);
	}

	// With `wallpaperAccent`, the accent is the wallpaper's most vivid color, as
	// light or dark as the palette takes: one with no color to speak of leaves it.
	readonly property var vivid: {
		let best = null;
		let most = 0.2;
		for (let at = 0; at < quantizer.colors.length; at++) {
			const color = quantizer.colors[at];
			const vividness = color.hslSaturation * (1 - Math.abs(color.hslLightness - 0.5) * 1.2);
			if (vividness > most) {
				best = color;
				most = vividness;
			}
		}
		return best ? Qt.hsla(best.hslHue, Math.min(best.hslSaturation, 0.7), light ? 0.38 : 0.74, 1) : null;
	}
	readonly property var values: Object.assign({}, plain, {
		colors: Object.assign({}, palette, accent ? { accent } : {}, plain.wallpaperAccent && vivid ? { accent: vivid } : {})
	})

	// The colors of the palette `name`, as they'd be on: "" for what the files say.
	function colorsOf(name) {
		const file = user.extends || "dark";
		return Object.assign({}, builtIn.dark.colors, (builtIn[name || file] || {}).colors, (name || file) === file ? user.colors : {});
	}

	// "07:30" in minutes of the day.
	function minutes(text) {
		const parts = `${text}`.split(":");
		return (Number(parts[0]) || 0) * 60 + (Number(parts[1]) || 0);
	}

	// When the sun rises and sets on `date`, in minutes of the day here, where the
	// settings say where that is, and it does both that day.
	function sunOn(date) {
		const places = [Settings.nightLight, Settings.weather].filter(place => place.latitude !== 0 || place.longitude !== 0);
		if (places.length === 0)
			return null;
		const degree = Math.PI / 180;
		const latitude = places[0].latitude * degree;
		const start = new Date(date.getFullYear(), 0, 0);
		const year = 2 * Math.PI / 365 * (Math.floor((date - start) / 86400000) - 0.5);
		const drift = 229.18 * (0.000075 + 0.001868 * Math.cos(year) - 0.032077 * Math.sin(year) - 0.014615 * Math.cos(2 * year) - 0.040849 * Math.sin(2 * year));
		const tilt = 0.006918 - 0.399912 * Math.cos(year) + 0.070257 * Math.sin(year) - 0.006758 * Math.cos(2 * year) + 0.000907 * Math.sin(2 * year) - 0.002697 * Math.cos(3 * year) + 0.00148 * Math.sin(3 * year);
		const reach = Math.cos(90.833 * degree) / (Math.cos(latitude) * Math.cos(tilt)) - Math.tan(latitude) * Math.tan(tilt);
		if (reach < -1 || reach > 1)
			return null;
		const half = Math.acos(reach) / degree;
		const noon = 720 - 4 * places[0].longitude - drift - date.getTimezoneOffset();
		return { rise: noon - 4 * half, set: noon + 4 * half };
	}

	SystemClock {
		id: clock

		enabled: theme.timed
		precision: SystemClock.Minutes
	}

	// The wallpaper's colors, read small, only when the accent is to be one.
	ColorQuantizer {
		id: quantizer

		source: theme.plain.wallpaperAccent ? Settings.url(theme.picture) : ""
		depth: 3
		rescaleSize: 64
	}

	readonly property var colors: values.colors
	readonly property string font: values.font || Qt.application.font.family
	readonly property real fontSize: u(values.fontSize)
	readonly property int fontWeight: values.fontWeight
	readonly property bool animate: !!values.animations
	// How fast what moves does: "quick", "normal" or "slow", and how a panel comes:
	// "grow" out of where it belongs, "fade" in place, or "slide" in from the bar;
	// and how a notification does: "slide" in from its side, "fade" or "grow".
	readonly property real pace: ({ quick: 0.6, slow: 1.6 })[values.speed] ?? 1
	readonly property string panelMotion: ["fade", "slide"].includes(values.panelMotion) ? values.panelMotion : "grow"
	readonly property string toastMotion: ["fade", "grow"].includes(values.toastMotion) ? values.toastMotion : "slide"

	// An animation `n` milliseconds long at the pace that's set.
	function ms(n) {
		return Math.round(n * pace);
	}
	// Panels let what's under them through, blurred, where the compositor has that,
	// and so do toasts. In niri that's the wallpaper, and with realBlur the windows
	// too, which takes a rule of Niri.rules.
	readonly property bool blur: !!values.blur
	readonly property bool toastBlur: !!values.toastBlur
	readonly property bool realBlur: !!values.realBlur
	// The bar has only the wallpaper under it, so what niri does by itself is all it
	// takes, and that's blurred once and not with each frame.
	readonly property bool barBlur: !!values.barBlur
	// How much of a surface that lets things through is its own color.
	readonly property real opacity: values.opacity / 100
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
	readonly property color panel: Qt.alpha(colors.background, blur ? opacity : 1)
	readonly property color surface: Qt.alpha(colors.surface, blur ? opacity * 0.83 : 1)
	readonly property color barFill: Qt.alpha(colors.background, barBlur ? opacity : 1)
	readonly property color toastFill: Qt.alpha(colors.background, toastBlur ? opacity : 1)
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

	// The palette from outside, as the Look page chooses it, so the settings window
	// shows it and Back to the config undoes it: `okaeri theme toggle` goes between
	// the day's and the night's, for a key. Any of these is one all day from then on.
	IpcHandler {
		id: calls

		target: "theme"

		// The other of the two, from how light what's on is.
		function toggle(): void {
			calls.palette(theme.light ? theme.plain.night : theme.plain.day);
		}

		function dark(): void {
			calls.palette(theme.plain.night);
		}

		function light(): void {
			calls.palette(theme.plain.day);
		}

		function palette(name: string): void {
			if (!theme.palettes.includes(name)) {
				console.info(`okaeri: no palette "${name}", it's one of ${theme.palettes.join(", ")}`);
				return;
			}
			theme.set("auto", "off");
			theme.set("extends", name);
		}

		// Along the palettes, as the Look page lists them: none named is dark's.
		function next(): void {
			const at = Math.max(0, theme.palettes.indexOf(theme.named));
			calls.palette(theme.palettes[(at + 1) % theme.palettes.length]);
		}

		function previous(): void {
			const at = Math.max(0, theme.palettes.indexOf(theme.named));
			calls.palette(theme.palettes[(at + theme.palettes.length - 1) % theme.palettes.length]);
		}

		// An accent of one's own over any palette's, as #rrggbb, or "" for the palette's.
		function accent(color: string): void {
			if (color !== "" && !/^#[0-9a-fA-F]{6}$/.test(color)) {
				console.info(`okaeri: no accent "${color}", it's #rrggbb or nothing`);
				return;
			}
			theme.set("accent", color.toLowerCase() || undefined);
		}

		function state(): string {
			return JSON.stringify({ palette: theme.named, light: theme.light, auto: theme.plain.auto, accent: String(theme.values.colors.accent) });
		}
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
		cloud: "M7 18h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 11 3.5 3.5 0 0 0 7 18z",
		coffee: "M4 9h12v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z M16 10h2a3 3 0 0 1 0 6h-2 M8 3v3 M12 3v3",
		copy: "M9 9h11v11H9z M5 15H4V4h11v1",
		ethernet: "M5 6h14v10h-4v3H9v-3H5z M9 10v2 M12 10v2 M15 10v2",
		eye: "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z",
		eyeOff: "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z M4 4l16 16",
		file: "M6 3h8l4 4v14H6z M14 3v4h4",
		fog: "M7 12h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 5 3.5 3.5 0 0 0 7 12z M4 16h16 M6 20h12",
		gamepad: "M6 8h12a4 4 0 0 1 4 4v1a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4v-1a4 4 0 0 1 4-4z M6.5 11v3 M5 12.5h3 M15 11.5h.01 M17.5 13.5h.01",
		gear: "M12 9a3 3 0 1 0 0 6 3 3 0 1 0 0-6z M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z",
		headphones: "M4 15v-3a8 8 0 0 1 16 0v3 M4 14h3v6H4z M17 14h3v6h-3z",
		hibernate: "M12 3v18 M4.2 7.5l15.6 9 M4.2 16.5l15.6-9 M9.5 4.5L12 6l2.5-1.5 M9.5 19.5L12 18l2.5 1.5",
		hotspot: "M12 12h.01 M8.5 8.5a5 5 0 0 0 0 7 M15.5 8.5a5 5 0 0 1 0 7 M5.6 5.6a9 9 0 0 0 0 12.8 M18.4 5.6a9 9 0 0 1 0 12.8",
		image: "M4 5h16v14H4z M4 16l5-5 4 4 3-3 4 4 M15 9h.01",
		keyboard: "M3 7h18v10H3z M7 11h.01 M11 11h.01 M15 11h.01 M8 14h8",
		lock: "M7 11V7a5 5 0 0 1 10 0v4 M5 11h14v10H5z",
		logout: "M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4 M15 8l4 4-4 4 M19 12H9",
		mic: "M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z M5 11a7 7 0 0 0 14 0 M12 18v3",
		micOff: "M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z M5 11a7 7 0 0 0 14 0 M12 18v3 M3 3l18 18",
		moon: "M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z",
		mouse: "M6 9a6 6 0 0 1 12 0v6a6 6 0 0 1-12 0z M12 7v3",
		music: "M9 18V5l11-2v13 M6 15a3 3 0 1 0 0 6 3 3 0 0 0 0-6z M17 13a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
		next: "M6 5l10 7-10 7z M18 5v14",
		numLock: "M5 9h14 M5 15h14 M10 4L8 20 M16 4l-2 16",
		osd: "M3 14h18v6H3z M7 17h6 M12 4v6 M9 7l3 3 3-3",
		pause: "M8 5v14 M16 5v14",
		phone: "M7 3h10v18H7z M11 18h2",
		pin: "M9 4h6l-1 7 3 3H7l3-3z M12 14v7",
		plus: "M12 5v14 M5 12h14",
		plane: "M12 3c-.8 0-1.5 1-1.5 2.5V9L3 13.5V16l7.5-2.5V18L8 20v1.5l4-1 4 1V20l-2.5-2v-4.5L21 16v-2.5L13.5 9V5.5C13.5 4 12.8 3 12 3z",
		play: "M7 5l12 7-12 7z",
		power: "M12 3v8 M17.66 6.34A8 8 0 1 1 6.34 6.34",
		previous: "M18 5L8 12l10 7z M6 5v14",
		qr: "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h.01 M17 17h.01 M20 14h.01 M14 20h.01 M20 20h.01",
		rain: "M7 14h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 7 3.5 3.5 0 0 0 7 14z M8 17l-1 3 M12 17l-1 3 M16 17l-1 3",
		refresh: "M20 12a8 8 0 1 1-2.34-5.66L20 8.5 M20 4v4.5h-4.5",
		repeat: "M17 3l3 3-3 3 M4 12v-2a4 4 0 0 1 4-4h12 M7 21l-3-3 3-3 M20 12v2a4 4 0 0 1-4 4H4",
		repeatOne: "M17 3l3 3-3 3 M4 12v-2a4 4 0 0 1 4-4h12 M7 21l-3-3 3-3 M20 12v2a4 4 0 0 1-4 4H4 M11 10.5l1.5-1v5",
		search: "M11 4a7 7 0 1 0 0 14 7 7 0 1 0 0-14z M20 20l-3.9-3.9",
		shield: "M12 3l7 3v5.5c0 4.3-2.9 7.6-7 9.5-4.1-1.9-7-5.2-7-9.5V6z",
		shuffle: "M3 7h3l9 10h6 M3 17h3l3.2-3.6 M11.8 10.6L15 7h6 M18 4l3 3-3 3 M18 14l3 3-3 3",
		sliders: "M4 7h10 M18 7h2 M14 5v4h4V5z M4 17h2 M10 17h10 M6 15v4h4v-4z",
		snow: "M7 14h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 7 3.5 3.5 0 0 0 7 14z M8 18h.01 M12 20h.01 M16 18h.01",
		storm: "M7 14h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 7 3.5 3.5 0 0 0 7 14z M12 14l-2 4h4l-2 4",
		sun: "M12 8a4 4 0 1 0 0 8 4 4 0 1 0 0-8z M12 2.5v2 M12 19.5v2 M2.5 12h2 M19.5 12h2 M5.3 5.3l1.4 1.4 M17.3 17.3l1.4 1.4 M5.3 18.7l1.4-1.4 M17.3 6.7l1.4-1.4",
		sunset: "M3 18h18 M7 18a5 5 0 0 1 10 0 M12 7v3 M5.6 10.6l1.4 1.4 M18.4 10.6l-1.4 1.4",
		text: "M5 6h14 M12 6v13 M9 19h6",
		trash: "M4 7h16 M9 7V4h6v3 M6 7l1 14h10l1-14",
		tray: "M4 13l2-8h12l2 8v6H4z M4 13h5l1 2h4l1-2h5",
		up: "M6 15l6-6 6 6",
		video: "M3 7h12v10H3z M15 10.5l6-3.5v10l-6-3.5",
		volume: "M4 9.5v5h3.5l4.5 4v-13l-4.5 4z M16 9a4.2 4.2 0 0 1 0 6 M18.5 6.5a7.8 7.8 0 0 1 0 11",
		volumeOff: "M4 9.5v5h3.5l4.5 4v-13l-4.5 4z M16.5 9.5l5 5 M21.5 9.5l-5 5",
		wifi: "M2 8.8a15 15 0 0 1 20 0 M5 12.6a10 10 0 0 1 14 0 M8.5 16.2a5 5 0 0 1 7 0 M12 20h.01",
		wifi1: "M8.5 16.2a5 5 0 0 1 7 0 M12 20h.01",
		wifi2: "M5 12.6a10 10 0 0 1 14 0 M8.5 16.2a5 5 0 0 1 7 0 M12 20h.01",
		wifiOff: "M2 8.8a15 15 0 0 1 20 0 M5 12.6a10 10 0 0 1 14 0 M8.5 16.2a5 5 0 0 1 7 0 M12 20h.01 M3 3l18 18"
	})
}
