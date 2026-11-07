import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.ui

// How the tray shows, and what it leaves out.
Flickable {
	id: page

	function show(id, wanted) {
		const others = Settings.tray.hidden.filter(other => other !== id);
		Settings.set("tray", "hidden", wanted ? others : others.concat([id]));
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
			text: "In a drawer"
			subtext: "Behind a button on the bar"
			checked: Settings.tray.drawer
			onToggled: wanted => Settings.set("tray", "drawer", wanted)
		}

		Repeater {
			model: ScriptModel {
				values: SystemTray.items.values
			}

			Setting {
				required property var modelData

				text: modelData.title || modelData.id
				image: modelData.icon
				checked: !Settings.tray.hidden.includes(modelData.id)
				onToggled: wanted => page.show(modelData.id, wanted)
			}
		}
	}
}
