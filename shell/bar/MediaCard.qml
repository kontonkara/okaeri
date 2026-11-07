import QtQuick
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// What's playing, or was last, with a way to pause it and move along the list.
Card {
	id: card

	readonly property var player: Media.player

	width: parent.width
	padding: Theme.u(6)

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
				text: card.player?.trackArtist || card.player?.identity || ""
				textFormat: Text.PlainText
				maximumLineCount: 1
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}
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
}
