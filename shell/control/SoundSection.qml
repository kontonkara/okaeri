import QtQuick
import qs
import qs.services
import qs.ui

// Where the sound goes, with more than one place for it, a click moving it
// there, the sound cards that can work in more ways than one, a click showing
// those ways under it to pick from, and the volume of each app playing, with a
// way to mute it and, with more than one output, to send it to one of its own.
Section {
	id: section

	// The id of the card whose ways are shown, -1 for none: one at a time.
	property int opened: -1
	// The app whose outputs are shown under it, by its place in the list, -1 for
	// none: one at a time too.
	property int routing: -1

	// A way picked for `card`: the one it's in already is left as it is, as a
	// change cuts the sound for a moment.
	function pick(card, profile) {
		opened = -1;
		if (profile !== card.profile)
			Audio.setProfile(card, profile);
	}

	name: "sound"
	icon: "volume"
	title: Tr.t("Sound")
	summary: Audio.sink?.description ?? ""
	switches: false
	// A screen may have come since the last time.
	onUnfoldedChanged: {
		opened = -1;
		routing = -1;
		if (unfolded) {
			Audio.checkScreens();
			Audio.lookCards();
		}
	}

	Heading {
		visible: Audio.outputs.length > 1
		text: Tr.t("Output")
	}

	Rows {
		visible: Audio.outputs.length > 1
		values: Audio.outputs
		room: section.roomInside / 2
		onActivated: (index, node) => Audio.use(node)

		delegate: Entry {
			id: row

			// One that went away is null here for a moment, as the row goes.
			readonly property var node: modelData ?? ({})
			readonly property bool current: node === Audio.sink

			text: node.description ?? ""
			subtext: node.nickname ?? ""
			pickable: !current

			Icon {
				name: row.current ? "check" : "volume"
				color: row.current ? Theme.colors.text : Theme.colors.subtext
			}
		}
	}

	Heading {
		visible: Audio.cards.length > 0
		text: Tr.t("Cards")
	}

	Rows {
		visible: Audio.cards.length > 0
		values: Audio.cards
		room: section.roomInside / 3
		onActivated: (index, card) => section.opened = section.opened === card.id ? -1 : card.id

		delegate: Entry {
			id: cardRow

			readonly property var card: modelData ?? ({})
			// The page, for the list of its ways: in that list `section` is its own.
			readonly property var page: section
			// Its ways, under it, by its id: a card read again is another
			// object.
			readonly property bool open: card.id !== undefined && section.opened === card.id

			text: card.name ?? ""
			subtext: card.profiles?.find(profile => profile.index === card.profile)?.text ?? Tr.t("Off")
			// Its ways come into sight. Opened by the keys, the keys go on to
			// them, from the one it's in, and back as it folds.
			onOpenChanged: {
				if (open) {
					if (view.activeFocus) {
						ways.currentIndex = card.profiles.findIndex(profile => profile.index === card.profile);
						ways.forceActiveFocus();
					}
					Qt.callLater(() => view.positionViewAtIndex(index, ListView.Contain));
				} else if (ways.activeFocus) {
					view.forceActiveFocus();
				}
			}

			Icon {
				name: "chip"
				color: Theme.colors.subtext
			}

			// Each of them, the one it's in with a check. Rows of their own,
			// lined up under the card's name, and nothing to scroll: the page's
			// list does that. They're there all along, only folded: a card read
			// again is a row made anew. Each is a row high, so they're as tall as
			// that many rows: a list kept folded has made few of them to measure.
			below: List {
				id: ways

				x: Theme.u(30)
				width: cardRow.width - x - Theme.u(5)
				height: cardRow.open ? count * rowHeight : 0
				visible: cardRow.open
				interactive: false
				rowHeight: cardRow.view.rowHeight
				model: (cardRow.card.profiles ?? []).map(profile => ({ text: profile.text, check: profile.index === cardRow.card.profile, profile: profile.index }))
				onActivated: (index, entry) => cardRow.page.pick(cardRow.card, entry.profile)
			}
		}
	}

	Heading {
		text: Tr.t("Apps")
	}

	Text {
		width: parent.width
		visible: Audio.nodes.length === 0
		leftPadding: Theme.u(10)
		bottomPadding: Theme.u(8)
		text: Tr.t("Nothing plays")
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}

	Repeater {
		model: Audio.nodes
		onCountChanged: section.routing = -1

		Column {
			id: app

			required property var modelData
			required property int index
			// The page, for the list of its outputs: in that list `section` is its own.
			readonly property var page: section
			// Where it plays now, and whether its outputs are shown.
			readonly property var going: Audio.outputOf(modelData)
			readonly property bool open: section.routing === index

			width: parent.width

			Level {
				// Its output said only where it's not where the rest go.
				label: Audio.streamName(app.modelData) + (Audio.outputs.length > 1 && app.going && app.going !== Audio.sink ? ` · ${app.going.description}` : "")
				value: app.modelData.audio.volume
				more: Audio.outputs.length > 1 ? "headphones" : ""
				moreShown: app.open
				onMoved: wanted => Audio.changeStream(app.modelData, wanted)
				onMoreWanted: section.routing = app.open ? -1 : app.index

				Button {
					anchors.centerIn: parent
					height: Theme.u(28)
					flat: true
					icon: app.modelData.audio.muted ? "volumeOff" : "volume"
					iconSize: Theme.u(16)
					ink: app.modelData.audio.muted ? Theme.colors.subtext : Theme.colors.text
					onClicked: Audio.toggleStream(app.modelData)
				}
			}

			// Where the rest go, which follows the default, and each other output,
			// the one it plays to with a check, lined up under its name.
			List {
				x: Theme.u(40)
				width: parent.width - x - Theme.u(5)
				height: app.open ? count * rowHeight : 0
				visible: app.open
				interactive: false
				model: [{ text: Tr.t("Where the rest go"), subtext: Audio.sink?.description ?? "", check: !app.going || app.going === Audio.sink, output: null }].concat(Audio.outputs.filter(node => node !== Audio.sink).map(node => ({ text: node.description, subtext: node.nickname, check: app.going === node, output: node })))
				onActivated: (index, entry) => {
					app.page.routing = -1;
					if (!entry.check || !entry.output)
						Audio.route(app.modelData, entry.output);
				}
			}
		}
	}

	component Heading: Text {
		width: parent.width
		leftPadding: Theme.u(10)
		topPadding: Theme.u(6)
		bottomPadding: Theme.u(4)
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
	}
}
