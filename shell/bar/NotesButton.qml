import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// Things to do and a note: how many are left to do, and a click shows them, to
// add to, tick off and write in.
BarButton {
	id: button

	readonly property bool wanted: true

	icon: "notes"
	text: Notes.open > 0 ? String(Notes.open) : ""
	tip: Notes.open === 0 ? "Nothing to do" : Notes.open === 1 ? "One thing to do" : `${Notes.open} things to do`
	onClicked: flip()

	// On this bar's screen, not the one in focus: a click can come from another.
	function flip() {
		card.middle = Panels.middleOf(button);
		if (card.shown)
			card.hide();
		else
			card.show(button.QsWindow.window.screen);
	}

	// `okaeri notes toggle`, for a key.
	Connections {
		target: Panels

		function onPartWanted(name, screen) {
			if (name !== "notes" || Panels.answered || (screen !== "" && screen !== button.QsWindow.window?.screen?.name))
				return;
			Panels.answered = true;
			button.flip();
		}
	}

	Panel {
		id: card

		align: "top"
		panelWidth: Theme.u(340)

		Loader {
			width: parent.width
			active: card.visible
			focus: true

			sourceComponent: NotesCard {}
		}
	}
}
