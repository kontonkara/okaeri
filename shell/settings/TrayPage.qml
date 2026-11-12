import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.ui

// How the tray shows, and what it leaves out. With the drawer an app's icon can
// stay on the bar beside its button.
Flickable {
	id: page

	readonly property var places: [
		{ value: "drawer", text: "In the drawer" },
		{ value: "bar", text: "On the bar" },
		{ value: "hidden", text: "Hidden" }
	]

	function show(id, wanted) {
		const others = Settings.tray.hidden.filter(other => other !== id);
		Settings.set("tray", "hidden", wanted ? others : others.concat([id]));
	}

	function placeOf(id) {
		return Settings.tray.hidden.includes(id) ? "hidden" : Settings.tray.pinned.includes(id) ? "bar" : "drawer";
	}

	function place(id, where) {
		show(id, where !== "hidden");
		const others = Settings.tray.pinned.filter(other => other !== id);
		Settings.set("tray", "pinned", where === "bar" ? others.concat([id]) : others);
	}

	contentHeight: card.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	Glide {
		view: page
	}

	Card {
		id: card

		width: parent.width

		Setting {
			holds: "tray.drawer"
			text: "In a drawer"
			subtext: "Behind a button on the bar"
			checked: Settings.tray.drawer
			onToggled: wanted => Settings.set("tray", "drawer", wanted)
		}

		Setting {
			holds: "tray.passive"
			text: "Quiet ones too"
			subtext: "Those that say there's nothing to see now"
			checked: Settings.tray.passive
			onToggled: wanted => Settings.set("tray", "passive", wanted)
		}

		Repeater {
			model: ScriptModel {
				values: SystemTray.items.values
			}

			Column {
				required property var modelData

				width: parent.width

				Setting {
					visible: !Settings.tray.drawer
					text: modelData.title || modelData.id
					image: modelData.icon
					checked: !Settings.tray.hidden.includes(modelData.id)
					onToggled: wanted => page.show(modelData.id, wanted)
				}

				Pick {
					visible: Settings.tray.drawer
					text: modelData.title || modelData.id
					image: modelData.icon
					options: page.places
					value: page.placeOf(modelData.id)
					onChosen: value => page.place(modelData.id, value)
				}
			}
		}
	}
}
