import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// What's playing, or was last, while there's a player: a click shows it on a card
// with its buttons, the middle button pauses it and the wheel moves along the list.
Button {
	id: button

	readonly property bool wanted: !!Media.player

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	longest: Theme.u(200)
	takesWheel: true
	activeFocusOnTab: false
	icon: "music"
	text: Media.player?.trackTitle || Media.player?.identity || ""
	ink: Media.player?.isPlaying ? Theme.colors.text : Theme.colors.subtext
	onClicked: {
		card.middle = Panels.middleOf(button);
		card.toggle();
	}
	onMiddleClicked: Media.toggle()
	onScrolled: steps => steps > 0 ? Media.previous() : Media.next()
	onWantedChanged: {
		if (!wanted)
			card.hide();
	}

	Panel {
		id: card

		align: "top"
		panelWidth: Theme.u(340)

		Loader {
			width: parent.width
			active: card.visible

			sourceComponent: MediaCard {}
		}
	}
}
