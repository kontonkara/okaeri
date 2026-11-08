import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// What's playing, or was last, while there's a player, or only while one plays, as
// Settings.media.show says: its title, its artist and title or only the icon. A
// click shows it on a card with its buttons, the middle button pauses it and the
// wheel moves along the list.
Button {
	id: button

	readonly property var own: Settings.media
	readonly property var player: Media.player
	readonly property string title: player?.trackTitle || player?.identity || ""
	// One paused from its card stays until the card goes.
	readonly property bool wanted: !!player && (own.show !== "playing" || player.isPlaying || card.visible)

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	longest: Theme.u(own.width)
	scrolls: own.scroll
	takesWheel: true
	activeFocusOnTab: false
	icon: "music"
	text: own.label === "none" ? "" : own.label === "both" && player?.trackArtist ? `${player.trackArtist} — ${title}` : title
	tip: [player?.trackArtist ?? "", player?.trackTitle ?? ""].filter(part => part !== "").join(" — ")
	ink: player?.isPlaying ? Theme.colors.text : Theme.colors.subtext
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
		panelWidth: Theme.u(360)

		Loader {
			width: parent.width
			active: card.visible

			sourceComponent: MediaCard {}
		}
	}
}
