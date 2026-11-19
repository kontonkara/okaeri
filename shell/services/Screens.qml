pragma Singleton

import QtQuick
import Quickshell
import qs

// The screens as the settings window set them, Settings.display.screens by
// their names: { mode, scale, vrr, transform, position, on }, each only where it
// was set. niri forgets what it's told at its next config: they're had again as
// the shell starts, as a screen comes and as niri reads its config, over what
// that says. A change from the window that can leave a screen dark is tried out
// first, and goes back by itself unless it's kept.
Singleton {
	id: screens

	readonly property var kept: Settings.display.screens ?? {}
	// Those niri had at the last look, for those that come.
	property var known: []
	// What's being tried out: { name, key, before, after }, and how long it has.
	property var trial: null
	property int left: 0

	// What `niri msg output` takes for `key` at `value`.
	function words(key, value) {
		if (key === "mode")
			return ["mode", value];
		if (key === "scale")
			return ["scale", String(value)];
		if (key === "vrr")
			return ["vrr", value ? "on" : "off"];
		if (key === "transform")
			return ["transform", value];
		if (key === "on")
			return [value ? "on" : "off"];
		return ["position", "set", String(value.x), String(value.y)];
	}

	// What screen `output` has now for `key`, as kept() keeps it.
	function now(output, key) {
		if (key === "mode") {
			const mode = output.modes[output.mode];
			return mode ? `${mode.width}x${mode.height}@${mode.rate.toFixed(3)}` : "";
		}
		if (key === "scale")
			return output.scale;
		if (key === "vrr")
			return output.vrr.on;
		if (key === "transform")
			return String(output.transform).toLowerCase().replace(/^_/, "").replace(/^flipped(\d+)$/, "flipped-$1");
		if (key === "on")
			return output.mode >= 0;
		return { x: output.x, y: output.y };
	}

	function keep(name, key, value) {
		const all = Object.assign({}, kept);
		all[name] = Object.assign({}, all[name], { [key]: value });
		Settings.set("display", "screens", all);
	}

	// Set at once and kept: what can't leave a screen dark.
	function set(name, key, value) {
		Niri.setOutput(name, words(key, value));
		keep(name, key, value);
	}

	// Set, and back as it was in fifteen seconds unless keepTrial() says so.
	function tryOut(name, key, value) {
		const output = Niri.outputs[name];
		if (!output)
			return;
		if (trial)
			dropTrial();
		trial = { name, key, before: now(output, key), after: value };
		left = 15;
		Niri.setOutput(name, words(key, value));
		ticking.restart();
	}

	function keepTrial() {
		if (!trial)
			return;
		keep(trial.name, trial.key, trial.after);
		trial = null;
		ticking.stop();
	}

	function dropTrial() {
		if (!trial)
			return;
		Niri.setOutput(trial.name, words(trial.key, trial.before));
		trial = null;
		ticking.stop();
	}

	// Screen `name` as kept, where niri has it otherwise.
	function apply(name) {
		const output = Niri.outputs[name];
		const own = kept[name];
		if (!output || !own)
			return;
		for (const key of ["on", "mode", "scale", "transform", "vrr", "position"]) {
			const value = own[key];
			if (value === undefined || (key === "vrr" && !output.vrr.supported))
				continue;
			if (JSON.stringify(now(output, key)) !== JSON.stringify(value))
				Niri.setOutput(name, words(key, value));
		}
	}

	// Those that came since the last look; all of them at the first, which may
	// have been before this was.
	function came() {
		const names = Object.keys(Niri.outputs);
		names.filter(name => !known.includes(name)).forEach(name => apply(name));
		known = names;
	}

	Component.onCompleted: came()

	Connections {
		target: Niri

		function onOutputsChanged() {
			screens.came();
		}

		// niri read its config again and took back what it was told: each is had
		// as kept again at the look that follows.
		function onConfigLoaded() {
			screens.known = [];
		}
	}

	Timer {
		id: ticking

		interval: 1000
		repeat: true
		onTriggered: {
			screens.left -= 1;
			if (screens.left <= 0)
				screens.dropTrial();
		}
	}
}
