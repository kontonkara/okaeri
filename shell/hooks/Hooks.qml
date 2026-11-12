import QtQuick
import Quickshell
import qs
import qs.services

// Commands of the user's for when things happen, Settings.hooks by what
// happened: "charger" as it goes in, "battery" as it comes out, "low" as the
// battery gets low, "colors" as the palette or the accent changes, and once as
// the shell starts, and "wallpaper" as another picture goes up. Each has what
// it's about in its environment: OKAERI_CHARGE, OKAERI_LIGHT and OKAERI_PALETTE
// with every color as OKAERI_COLOR_ACCENT and so on, OKAERI_WALLPAPER. niri
// starts them, as it does apps. The colors go into other apps' files too, by
// Templates, and those are written before the "colors" command runs.
Scope {
	id: hooks

	readonly property var own: Settings.hooks
	// Not for how things are as the shell comes up: those aren't changes.
	property bool ready: false
	readonly property string wallpaper: Theme.picture
	// The colors as text, to tell one set from another.
	readonly property string colors: Object.keys(Theme.colors).map(name => `${name}=${Theme.colors[name]}`).join(" ")

	function run(name, about) {
		const command = own[name];
		if (!command)
			return;
		const set = Object.keys(about).map(key => `${key}=${about[key]}`);
		Env.act(`hook ${name}`, () => Niri.spawn(["env"].concat(set, ["sh", "-c", command])));
	}

	function painted() {
		templates.paint();
		const about = { OKAERI_LIGHT: Theme.light ? 1 : 0, OKAERI_PALETTE: Theme.named || "dark" };
		Object.keys(Theme.colors).forEach(name => about[`OKAERI_COLOR_${name.toUpperCase()}`] = `${Theme.colors[name]}`);
		run("colors", about);
	}

	onWallpaperChanged: {
		if (ready && wallpaper)
			run("wallpaper", { OKAERI_WALLPAPER: wallpaper });
	}
	// A palette comes a color at a time: once they've all changed.
	onColorsChanged: {
		if (ready)
			settling.restart();
	}

	Connections {
		target: Power

		function onDrainingChanged() {
			if (hooks.ready)
				hooks.run(Power.draining ? "battery" : "charger", { OKAERI_CHARGE: Power.charge });
		}

		function onLowChanged() {
			if (hooks.ready && Power.low)
				hooks.run("low", { OKAERI_CHARGE: Power.charge });
		}
	}

	// The theme and the battery come in a piece at a time as the shell starts:
	// after that, the colors as they are, for what follows them.
	Timer {
		running: true
		interval: 2000
		onTriggered: {
			hooks.ready = true;
			hooks.painted();
		}
	}

	Timer {
		id: settling

		interval: 300
		onTriggered: hooks.painted()
	}

	Templates {
		id: templates
	}
}
