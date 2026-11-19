import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// What else a tile can do, on a page in the panel's place: a right click on the
// tile opens it. First what's the tile's own, where it has some (what a
// recording takes in, how warm the night light is, for how long the machine
// stays awake, which power profile), then how it sits among the others: a whole
// row or half of one, a place earlier or later, out of the panel, and the rest
// of its settings in the settings window. A click on a row does what it says.
Section {
	id: page

	readonly property string tile: Control.options
	readonly property var own: Settings.control.custom.find(other => other.name === tile) ?? null
	readonly property var about: ({
			wifi: { title: Tr.t("Wi-Fi"), icon: "wifi" },
			wired: { title: Tr.t("Wired"), icon: "ethernet" },
			drives: { title: Tr.t("Drives"), icon: "drive" },
			phone: { title: Tr.t("Phone"), icon: "phone" },
			screenshot: { title: Tr.t("Screenshot"), icon: "image" },
			bluetooth: { title: Tr.t("Bluetooth"), icon: "bluetooth" },
			night: { title: Tr.t("Night light"), icon: "sunset" },
			awake: { title: Tr.t("Keep awake"), icon: "coffee" },
			power: { title: Tr.t("Power"), icon: "bolt" },
			airplane: { title: Tr.t("Airplane mode"), icon: "plane" },
			vpn: { title: "VPN", icon: "shield" },
			record: { title: Tr.t("Record"), icon: "video" },
			hotspot: { title: Tr.t("Hotspot"), icon: "hotspot" },
			game: { title: Tr.t("Game mode"), icon: "gamepad" }
		})[tile] ?? { title: tile, icon: own && own.icon in Theme.icons ? own.icon : "play" }
	// The groups of rows: { title, rows: [{ text, subtext, icon, check, enabled,
	// does }] }, `does` being what a click on the row does.
	readonly property var groups: ownGroups(tile).concat([placeGroup(tile)])

	// A row that's one of a choice: checked while it's the one.
	function pick(text, chosen, does, subtext) {
		return { text, subtext: subtext ?? "", icon: "", check: chosen, does };
	}

	function ownGroups(name) {
		if (name === "record") {
			const area = Settings.recording.area;
			const audio = Settings.recording.audio;
			return [{
					title: Tr.t("What's recorded"),
					rows: [
						pick("The screen", area !== "region" || !Recorder.picks, () => Settings.set("recording", "area", "screen")),
						Object.assign(pick("A part of it", area === "region" && Recorder.picks, () => Settings.set("recording", "area", "region"), Recorder.picks ? "Picked as it starts" : "It needs slurp, which isn't here"), { enabled: Recorder.picks })
					]
				}, {
					title: Tr.t("With the sound of"),
					rows: [
						pick("Nothing", audio === "none", () => Settings.set("recording", "audio", "none")),
						pick("What plays", audio === "system", () => Settings.set("recording", "audio", "system")),
						pick("The mic", audio === "mic", () => Settings.set("recording", "audio", "mic"))
					]
				}, {
					title: Tr.t("The videos"),
					rows: [{ text: Tr.t("Open their folder"), subtext: Recorder.folder.replace(Quickshell.env("HOME"), "~"), icon: "file", does: () => {
								Env.act("open folder", () => Niri.spawn(["xdg-open", Recorder.folder]));
								Control.leave();
							} }]
				}];
		}
		if (name === "screenshot") {
			const delay = Settings.screenshots.delay;
			const take = (kind, text, subtext) => ({ text, subtext, icon: "image", does: () => {
					Control.leave();
					Screenshots.take(kind);
				} });
			return [{
					title: Tr.t("Take one"),
					rows: [take("area", "A part of the screen", "Picked by niri"), take("screen", "The screen", delay ? `In ${delay} s` : ""), take("window", "The window in focus", delay ? `In ${delay} s` : "")]
				}, {
					title: Tr.t("Of the screen and a window, wait first"),
					rows: [0, 3, 5, 10].map(seconds => pick(seconds ? `${seconds} seconds` : "Not at all", delay === seconds, () => Settings.set("screenshots", "delay", seconds)))
				}];
		}
		if (name === "night") {
			const own = Settings.nightLight;
			const warmth = [3000, 3500, 4000, 4500, 5000];
			return [{
					title: Tr.t("When"),
					rows: [
						pick("All the time", own.mode === "always", () => Settings.set("nightLight", "mode", "always")),
						pick("From, until", own.mode === "schedule", () => Settings.set("nightLight", "mode", "schedule"), `${own.from} to ${own.until}`),
						pick("By the sun", own.mode === "sun", () => Settings.set("nightLight", "mode", "sun"), own.latitude || own.longitude ? "Where the settings say you are" : "Where you are goes in the settings"),
						{ text: Tr.t("Not at all"), subtext: own.mode === "always" ? "Until it's turned on" : "Not tonight, nor after, until it's turned on", icon: "close", check: false, enabled: own.on, does: () => NightLight.stop() }
					]
				}, {
					title: Tr.t("How warm"),
					rows: (warmth.includes(own.temperature) ? warmth : warmth.concat([own.temperature]).sort((a, b) => a - b)).map(kelvin => pick(`${kelvin} K`, own.temperature === kelvin, () => Settings.set("nightLight", "temperature", kelvin), kelvin === 3000 ? "The warmest here" : kelvin === 5000 ? "Close to daylight" : ""))
				}];
		}
		if (name === "awake") {
			const minutes = [30, 60, 120, 240];
			return [{
					title: Tr.t("For how long"),
					rows: minutes.map(span => ({ text: span < 60 ? `${span} minutes` : span === 60 ? "An hour" : `${span / 60} hours`, subtext: "From now", icon: "coffee", check: false, does: () => Awake.set(true, Date.now() + span * 60000) })).concat([
						pick("Until it's turned off", Awake.on && Awake.until === 0, () => Awake.set(true, 0)),
						pick("Not now", !Awake.on, () => Awake.set(false, 0))
					])
				}];
		}
		if (name === "power")
			return [{
					title: Tr.t("Profile"),
					rows: Power.choices.map(choice => pick(choice.text, Power.profile === choice.profile, () => Power.set(choice.profile)))
				}];
		const pages = { wifi: "The networks", wired: "What it has", drives: "What's plugged in", phone: "What it does", bluetooth: "The devices", vpn: "The connections", hotspot: "How a phone joins it" };
		if (pages[name])
			return [{
					title: "",
					rows: [{ text: pages[name], subtext: `As the arrow on the tile has ${name === "hotspot" ? "it" : "them"}`, icon: "chevron", does: () => Control.unfolded = name }]
				}];
		return [];
	}

	function placeGroup(name) {
		const at = Control.shown.indexOf(name);
		return {
			title: Tr.t("The tile"),
			rows: [
				pick("A whole row", Settings.control.wide.includes(name), () => Control.setWide(name, !Settings.control.wide.includes(name)), "Or half of one, beside another"),
				pick("Small tiles", Settings.control.size === "small", () => Settings.set("control", "size", Settings.control.size === "small" ? "large" : "small"), "All of them, a line each"),
				{ text: Tr.t("Earlier"), subtext: Tr.t("A place up among the tiles"), icon: "back", enabled: at > 0, does: () => Control.moveTile(name, -1) },
				{ text: Tr.t("Later"), subtext: Tr.t("A place down among the tiles"), icon: "chevron", enabled: at >= 0 && at < Control.shown.length - 1, does: () => Control.moveTile(name, 1) },
				{ text: Tr.t("Out of the panel"), subtext: Tr.t("The Control page of the settings brings it back"), icon: "eyeOff", does: () => {
						Control.hideTile(name);
						Control.unfolded = "";
					} },
				{ text: Tr.t("More in the settings"), subtext: Tr.t("Its page there"), icon: "gear", does: () => {
						Control.leave();
						Settings.pageWanted(name === "night" || name === "record" ? "Display" : "Control");
					} }
			]
		};
	}

	name: "options"
	icon: about.icon
	title: about.title
	summary: Tr.t("What else it can do")
	switches: false

	Repeater {
		model: page.groups

		Column {
			required property var modelData

			width: parent.width

			Text {
				width: parent.width
				visible: text !== ""
				leftPadding: Theme.u(10)
				topPadding: Theme.u(6)
				bottomPadding: Theme.u(4)
				text: modelData.title
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Rows {
				values: modelData.rows
				// As tall as it needs: the panel scrolls where it's more than the screen.
				room: Theme.u(2000)
				onActivated: (index, row) => row.does()

				delegate: Entry {
					id: row

					readonly property var option: modelData ?? ({})

					text: option.text ?? ""
					subtext: option.subtext ?? ""
					pickable: option.enabled !== false
					opacity: option.enabled === false ? 0.5 : 1

					Icon {
						name: row.option.check ? "check" : row.option.icon || "check"
						visible: !!row.option.check || !!row.option.icon
						color: row.option.check ? Theme.colors.accent : Theme.colors.subtext
					}
				}
			}
		}
	}
}
