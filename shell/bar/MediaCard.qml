import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// What's playing, or was last, with a way to pause it and move along the list,
// how far in it is, to move to another point by, shuffle and repeat, where the
// player has those, and with more than one player a list to pick another. A
// click on the cover or the title brings up the player's window.
Card {
	id: card

	readonly property var player: Media.player
	readonly property bool timed: (player?.positionSupported ?? false) && player.lengthSupported && player.length > 0
	// Where the pointer holds the slider, in seconds, while it does.
	property real held: -1

	width: parent.width
	padding: Theme.u(6)

	// Players don't say where they are as they go: it's asked for anew.
	Timer {
		running: card.visible && card.timed && (card.player?.isPlaying ?? false)
		interval: 1000
		repeat: true
		triggeredOnStart: true
		onTriggered: card.player.positionChanged()
	}

	Item {
		width: parent.width
		height: Theme.u(52)

		ClippingRectangle {
			id: cover

			anchors.verticalCenter: parent.verticalCenter
			width: parent.height
			height: parent.height
			radius: Math.max(0, Theme.cardRadius - Theme.u(4))
			color: Theme.hover

			Image {
				id: art

				anchors.fill: parent
				source: card.player?.trackArtUrl ?? ""
				sourceSize: Qt.size(width, height)
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
			}

			Icon {
				anchors.centerIn: parent
				visible: art.status !== Image.Ready
				name: "music"
				color: Theme.colors.subtext
			}
		}

		Column {
			id: words

			anchors.left: cover.right
			anchors.leftMargin: Theme.u(12)
			anchors.right: buttons.left
			anchors.rightMargin: Theme.u(8)
			anchors.verticalCenter: parent.verticalCenter

			// Whatever a player says: never markup, and one line.
			Text {
				width: parent.width
				text: card.player?.trackTitle || card.player?.identity || ""
				textFormat: Text.PlainText
				maximumLineCount: 1
				color: Theme.colors.text
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				font.weight: Theme.fontWeight
			}

			Text {
				width: parent.width
				text: [card.player?.trackArtist || card.player?.identity || "", card.player?.trackAlbum ?? ""].filter(part => part !== "").join(" · ")
				textFormat: Text.PlainText
				maximumLineCount: 1
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}
		}

		MouseArea {
			anchors.left: cover.left
			anchors.right: words.right
			height: parent.height
			enabled: card.player?.canRaise ?? false
			cursorShape: Qt.PointingHandCursor
			onClicked: Media.raise()
		}

		Row {
			id: buttons

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter

			Button {
				height: Theme.u(30)
				flat: true
				enabled: card.player?.canGoPrevious ?? false
				icon: "previous"
				onClicked: Media.previous()
			}

			Button {
				height: Theme.u(30)
				flat: true
				enabled: card.player?.canTogglePlaying ?? false
				icon: card.player?.isPlaying ? "pause" : "play"
				onClicked: Media.toggle()
			}

			Button {
				height: Theme.u(30)
				flat: true
				enabled: card.player?.canGoNext ?? false
				icon: "next"
				onClicked: Media.next()
			}
		}
	}

	// Shuffle, how far in it is, and repeat.
	Item {
		width: parent.width
		height: Theme.u(30)
		visible: card.timed || shuffle.visible || loop.visible

		Button {
			id: shuffle

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(30)
			flat: true
			visible: card.player?.shuffleSupported ?? false
			enabled: card.player?.canControl ?? false
			icon: "shuffle"
			ink: card.player?.shuffle ? Theme.colors.accent : Theme.colors.subtext
			onClicked: Media.shuffle()
		}

		Row {
			anchors.left: shuffle.right
			anchors.right: loop.left
			anchors.leftMargin: Theme.u(4)
			anchors.rightMargin: Theme.u(4)
			anchors.verticalCenter: parent.verticalCenter
			visible: card.timed
			spacing: Theme.u(8)

			Time {
				id: gone

				text: Media.clock(card.held >= 0 ? card.held : card.player?.position ?? 0)
			}

			Slider {
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - gone.width - total.width - parent.spacing * 2
				enabled: card.player?.canSeek ?? false
				value: (card.held >= 0 ? card.held : card.player?.position ?? 0) / (card.player?.length || 1)
				// Ten seconds a notch or a key.
				step: 10 / (card.player?.length || 1)
				onMoved: wanted => {
					if (pressed)
						card.held = wanted * card.player.length;
					else
						Media.seekTo(wanted * card.player.length);
				}
				onReleased: {
					if (card.held >= 0)
						Media.seekTo(card.held);
					card.held = -1;
				}
			}

			Time {
				id: total

				text: Media.clock(card.player?.length ?? 0)
			}
		}

		Button {
			id: loop

			readonly property int mode: card.player?.loopState ?? MprisLoopState.None

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(30)
			flat: true
			visible: card.player?.loopSupported ?? false
			enabled: card.player?.canControl ?? false
			icon: mode === MprisLoopState.Track ? "repeatOne" : "repeat"
			ink: mode === MprisLoopState.None ? Theme.colors.subtext : Theme.colors.accent
			onClicked: Media.loop()
		}
	}

	// The others there are, to pick for the keys and the bar.
	Column {
		width: parent.width
		visible: Media.players.length > 1

		Repeater {
			model: Media.players

			Button {
				required property var modelData
				readonly property bool current: modelData === card.player

				width: parent.width
				height: Theme.u(30)
				flat: !current
				atStart: true
				pad: Theme.u(8)
				longest: width - Theme.u(42)
				icon: modelData.isPlaying ? "volume" : "pause"
				iconSize: Theme.u(14)
				text: [modelData.identity, modelData.trackTitle].filter(part => !!part).join(" · ")
				ink: current ? Theme.colors.text : Theme.colors.subtext
				onClicked: Media.pick(modelData)
			}
		}
	}

	component Time: Text {
		anchors.verticalCenter: parent.verticalCenter
		color: Theme.colors.subtext
		font.family: Theme.font
		font.pixelSize: Theme.fontSize - Theme.u(2)
		font.features: {
			"tnum": 1
		}
	}
}
