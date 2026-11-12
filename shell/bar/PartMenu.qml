import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// What else a part of the bar can do, by the part: a right click on one that has
// no right click of its own opens it. First what's the part's own, where it has
// some (what a recording takes in, how warm the night light is and when, for how
// long the machine stays awake, which power profile, what the clock shows, what's
// beside the battery, the network or Bluetooth), then its settings in the
// settings window, and taking it off the bar. A click on a row does what it says.
Panel {
	id: menu

	// The part this is of, by its name on the bar.
	property string part: ""
	readonly property var rows: {
		const own = ownRows(part);
		const rest = [{ settings: true, text: "Settings of this part", subtext: "On the Bar page", icon: "gear" }];
		// The way to the rest of the shell stays.
		if (part !== "control")
			rest.push({ off: true, text: "Off the bar", subtext: "The Bar page brings it back", icon: "eyeOff" });
		return own.concat(own.length ? [{ separator: true }] : [], rest);
	}

	// A row that's one of a choice: checked while it's the one.
	function pick(text, chosen, does, subtext) {
		return { text, subtext: subtext ?? "", icon: "", check: chosen, does };
	}

	// The same keys as the part's card on the Bar page, and the tiles' options.
	function ownRows(name) {
		const line = { separator: true };
		if (name === "recording") {
			const area = Settings.recording.area;
			const audio = Settings.recording.audio;
			return [
				pick("The screen", area !== "region" || !Recorder.picks, () => Settings.set("recording", "area", "screen"), "The one in focus"),
				Object.assign(pick("A part of it", area === "region" && Recorder.picks, () => Settings.set("recording", "area", "region"), Recorder.picks ? "Picked as it starts" : "It needs slurp, which isn't here"), { enabled: Recorder.picks }),
				line,
				pick("No sound", audio === "none", () => Settings.set("recording", "audio", "none")),
				pick("With what plays", audio === "system", () => Settings.set("recording", "audio", "system")),
				pick("With the mic", audio === "mic", () => Settings.set("recording", "audio", "mic"))
			];
		}
		if (name === "night") {
			const own = Settings.nightLight;
			return [
				{ text: "Warmer", subtext: `${NightLight.warm} K now`, icon: "", stays: true, enabled: NightLight.warm > 2500, does: () => NightLight.step(-1) },
				{ text: "Cooler", subtext: "Closer to daylight", icon: "", stays: true, enabled: NightLight.warm < 6000, does: () => NightLight.step(1) },
				line,
				pick("All the time", own.mode === "always", () => Settings.set("nightLight", "mode", "always")),
				pick("From, until", own.mode === "schedule", () => Settings.set("nightLight", "mode", "schedule"), `${own.from} to ${own.until}`),
				pick("By the sun", own.mode === "sun", () => Settings.set("nightLight", "mode", "sun"), own.latitude || own.longitude ? "Where the settings say you are" : "Where you are goes in the settings")
			];
		}
		if (name === "awake") {
			return [30, 60, 120].map(span => ({ text: span < 60 ? `For ${span} minutes` : span === 60 ? "For an hour" : `For ${span / 60} hours`, subtext: "From now", icon: "", does: () => Awake.set(true, Date.now() + span * 60000) })).concat([
				pick("Until it's turned off", Awake.on && Awake.until === 0, () => Awake.set(true, 0)),
				pick("Not now", !Awake.on, () => Awake.set(false, 0))
			]);
		}
		if (name === "profile")
			return Power.choices.map(choice => pick(choice.text, Power.profile === choice.profile, () => Power.set(choice.profile)));
		if (name === "clock") {
			const clock = Settings.clock;
			return [
				pick("The date before the time", clock.date === "before", () => Settings.set("clock", "date", "before")),
				pick("The date after it", clock.date === "after", () => Settings.set("clock", "date", "after")),
				pick("No date", clock.date === "none", () => Settings.set("clock", "date", "none")),
				line,
				pick("Seconds", clock.seconds, () => Settings.set("clock", "seconds", !clock.seconds)),
				pick("12-hour time", clock.hours12, () => Settings.set("clock", "hours12", !clock.hours12), "With AM and PM")
			];
		}
		if (name === "battery") {
			const label = Settings.battery.label;
			return [
				pick("The percent beside it", label === "percent", () => Settings.set("battery", "label", "percent")),
				pick("The time left beside it", label === "time", () => Settings.set("battery", "label", "time"), "Where it's known"),
				pick("Nothing beside it", label === "none", () => Settings.set("battery", "label", "none"))
			];
		}
		if (name === "network") {
			const label = Settings.network.label;
			return [
				pick("The network beside it", label === "name", () => Settings.set("network", "label", "name")),
				pick("Nothing beside it", label === "none", () => Settings.set("network", "label", "none"))
			];
		}
		if (name === "bluetooth") {
			const label = Settings.bluetooth.label;
			return [
				pick("The device beside it", label === "name", () => Settings.set("bluetooth", "label", "name")),
				pick("Nothing beside it", label === "none", () => Settings.set("bluetooth", "label", "none"))
			];
		}
		return [];
	}

	// By `item`, the part called `name` on a bar on `screen`.
	function showFor(name, item, screen) {
		part = name;
		middle = Panels.middleOf(item);
		show(screen);
	}

	// Off the lane it's in: the bars of every screen go by the same.
	function takeOff(name) {
		const lane = ["left", "center", "right"].find(key => Settings.bar[key].includes(name));
		if (lane)
			Settings.set("bar", lane, Settings.bar[lane].filter(other => other !== name));
	}

	align: "top"
	panelWidth: Theme.u(260)
	padding: Theme.u(6)

	onPanelOpened: {
		list.pointer = null;
		list.currentIndex = -1;
		list.forceActiveFocus();
	}

	// Any panel takes a menu's place.
	Connections {
		target: Panels

		function onOpened(other) {
			if (other !== menu)
				menu.hide();
		}
	}

	List {
		id: list

		width: parent.width
		height: Math.min(contentHeight, Theme.u(480), menu.room)
		focus: true
		model: menu.rows
		onActivated: (index, row) => {
			// The rows still take clicks as the panel fades: a double click does.
			if (!menu.shown)
				return;
			const name = menu.part;
			if (!row.stays)
				menu.hide();
			if (row.settings)
				Settings.barPartWanted(name);
			else if (row.off)
				menu.takeOff(name);
			else if (row.does)
				row.does();
		}
		Keys.onEscapePressed: menu.hide()
	}
}
