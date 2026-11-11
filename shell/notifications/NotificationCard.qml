import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.ui

// One notification: its picture, where it's from, when, what it says, how far
// along, its actions and a way to close it. A click on it goes to where it came
// from, and a right click closes it; with the keys on it Enter or Space is its
// default action. A long text opens up, and in the history it can be copied and,
// where the app takes that, answered. niri's word of a screenshot shows the picture
// whole, and a click opens it.
Card {
	id: card

	required property var notification
	// With the close button: a toast goes by a right click.
	property bool closable: true
	// What only the history has room for, or use.
	readonly property bool inHistory: closable
	property bool expanded: false
	// How much of it is said: "all", only its "title", or "none" but who it's from,
	// for a toast that others may see.
	property string says: "all"
	// With its app's name: under a heading that says it, there's no need.
	property bool showsApp: true

	readonly property var defaultAction: notification.actions.find(a => a.identifier === "default") || null
	readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")
	readonly property bool critical: NotificationStore.critical(notification)
	readonly property real side: Theme.u(40)
	// What the top line leaves for the close button.
	readonly property real beside: closable ? close.width + copy.width + quieter.width + Theme.u(4) : 0
	// How far along, 0 to 100, if it's that kind.
	readonly property int progress: notification.hints?.value ?? -1

	// It closed with the keys on it.
	signal keysLost

	// The picture it came with and its app's icon, as names, paths or image
	// URLs. The entries load after the first lookup: `values` has this come
	// back when they're there.
	readonly property var icons: {
		const name = notification.desktopEntry || notification.appName;
		const entry = name && DesktopEntries.applications.values.length ? DesktopEntries.heuristicLookup(name) : null;
		return [notification.image, notification.appIcon, entry ? entry.icon : ""].map(plain);
	}
	// The first path there, and the path that was read: see source().
	readonly property string file: icons.find(icon => icon.startsWith("/")) || ""
	property string fileRead
	readonly property string picture: icons.map(source).find(url => url !== "") || ""
	readonly property bool shot: notification.appName === "niri" && file !== ""

	function plain(icon) {
		const name = (icon || "").replace("image://icon/", "");
		if (!name.startsWith("file://"))
			return name;
		try {
			return decodeURIComponent(name.slice(7));
		} catch (error) {
			return name.slice(7);
		}
	}

	// What an Image can load of one of the icons. The icon loader says first if
	// it's a picture at all: an Image would warn, and for an icon the theme
	// lacks Qt would draw its placeholder. It opens a path here and now, and on
	// a pipe that never returns, so a path has to have been read first. In a URL
	// its name stays as it is, and nothing comes from a network.
	function source(icon) {
		if (!icon || icon.startsWith("image://"))
			return icon;
		if (icon.startsWith("/") && icon !== fileRead)
			return "";
		const found = Quickshell.iconPath(icon, true);
		return found && icon.startsWith("/") ? `file://${encodeURI(icon).replace(/[?#]/g, encodeURIComponent)}` : found;
	}

	// Where the keys can go on it, in order. None of these is on Tab's way: it
	// would go by the order a list made its cards in, so the list uses this.
	function stops() {
		const pressable = [];
		for (let i = 0; i < actions.count; i++)
			pressable.push(actions.itemAt(i));
		return (defaultAction ? [card] : []).concat(pressable, [close]);
	}

	// Text from an app is never markup here.
	component Line: Text {
		width: parent.width
		visible: text !== ""
		textFormat: Text.PlainText
		wrapMode: Text.Wrap
		elide: Text.ElideRight
		font.family: Theme.font
		font.pixelSize: Theme.fontSize
	}

	border.width: 0

	Keys.onPressed: event => {
		if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
			NotificationStore.invoke(notification, defaultAction);
			event.accepted = true;
		}
	}

	// So that it can leave with its text on when it's gone already.
	RetainableLock {
		object: card.notification.isPast ? null : card.notification
		locked: true
	}

	// Off to the side, and it only reads a file.
	FileView {
		path: card.file
		printErrors: false
		onLoaded: card.fileRead = path
	}

	// On its way out nothing on it can be used any more.
	Connections {
		target: card.notification

		function onClosed() {
			if (card.stops().some(stop => stop.activeFocus))
				card.keysLost();
			card.enabled = false;
		}
	}

	// Over the fill: a border of its own would have a fill to see through stop short
	// of it, and show as a light line.
	Rectangle {
		parent: card
		anchors.fill: parent
		radius: card.radius
		color: "transparent"
		border.width: Math.max(1, Theme.u(card.critical ? 2 : 1))
		border.color: card.critical ? Theme.colors.error : Theme.border
	}

	// On its edge, not around it: the list would cut that off.
	FocusRing {
		parent: card
		anchors.fill: parent
		anchors.margins: 0
		visible: card.activeFocus
		cornerRadius: card.radius
	}

	Item {
		width: parent.width
		height: Math.max(card.side, words.implicitHeight)

		MouseArea {
			anchors.fill: parent
			anchors.margins: -card.padding
			acceptedButtons: Qt.LeftButton | Qt.RightButton
			cursorShape: Qt.PointingHandCursor
			onClicked: event => {
				if (event.button === Qt.RightButton)
					card.notification.dismiss();
				else if (card.shot)
					NotificationStore.open(card.notification, card.file);
				else
					NotificationStore.activate(card.notification);
			}
		}

		ClippingRectangle {
			visible: !card.shot
			width: card.side
			height: card.side
			radius: Math.max(0, Theme.cardRadius - Theme.u(4))
			color: Theme.hover

			Image {
				id: image

				anchors.fill: parent
				source: card.picture
				sourceSize: Qt.size(card.side, card.side)
				fillMode: Image.PreserveAspectCrop
				asynchronous: true
			}

			Icon {
				anchors.centerIn: parent
				visible: image.status !== Image.Ready
				name: "bell"
				color: Theme.colors.subtext
			}
		}

		Column {
			id: words

			x: card.shot ? 0 : card.side + Theme.u(12)
			width: parent.width - x
			spacing: Theme.u(3)

			Line {
				id: app

				width: parent.width - card.beside
				text: [card.showsApp ? card.notification.appName : "", NotificationStore.repeatsOf(card.notification) > 1 ? `×${NotificationStore.repeatsOf(card.notification)}` : "", card.inHistory ? NotificationStore.when(card.notification) : ""].filter(part => part !== "").join(" · ")
				wrapMode: Text.NoWrap
				maximumLineCount: 1
				color: Theme.colors.subtext
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Line {
				id: summary

				width: parent.width - (app.visible ? 0 : card.beside)
				text: card.says === "none" ? "New notification" : card.notification.summary
				maximumLineCount: 2
				color: Theme.colors.text
				font.weight: Theme.fontWeight
			}

			Line {
				id: body

				width: parent.width - (app.visible || summary.visible ? 0 : card.beside)
				text: card.says === "all" ? card.notification.body : ""
				maximumLineCount: card.expanded ? 200 : 5
				color: Theme.colors.subtext
				font.pixelSize: Theme.fontSize - Theme.u(1)
			}

			Button {
				height: Theme.u(24)
				visible: body.truncated || card.expanded
				flat: true
				pad: Theme.u(6)
				activeFocusOnTab: false
				text: card.expanded ? "Less" : "More"
				ink: Theme.colors.subtext
				onClicked: card.expanded = !card.expanded
			}

			Item {
				width: parent.width
				height: Theme.u(10)
				visible: card.progress >= 0

				Rectangle {
					anchors.verticalCenter: parent.verticalCenter
					width: parent.width
					height: Theme.u(4)
					radius: Theme.round(height)
					color: Theme.hover

					Rectangle {
						width: parent.width * Math.min(100, card.progress) / 100
						height: parent.height
						radius: parent.radius
						color: Theme.colors.accent
					}
				}
			}

			TextField {
				id: answer

				width: parent.width
				implicitHeight: Theme.u(30)
				visible: card.inHistory && !!card.notification.hasInlineReply
				placeholder: card.notification.inlineReplyPlaceholder || "Reply"
				onAccepted: {
					if (text !== "") {
						NotificationStore.reply(card.notification, text);
						text = "";
					}
				}
				// A field lets Enter through, and it'd do what the card does for it.
				Keys.onPressed: event => {
					if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
						event.accepted = true;
				}
			}

			Flow {
				width: parent.width
				topPadding: Theme.u(6)
				visible: card.buttons.length > 0 && (card.inHistory || Settings.notifications.actions)
				spacing: Theme.u(6)

				Repeater {
					id: actions

					model: card.buttons

					Button {
						id: action

						required property var modelData

						implicitWidth: label.width + Theme.u(28)
						height: Theme.u(28)
						activeFocusOnTab: false
						onClicked: NotificationStore.invoke(card.notification, modelData)

						// The button's own text would take markup.
						Line {
							id: label

							anchors.verticalCenter: parent.verticalCenter
							width: Math.min(implicitWidth, words.width - Theme.u(28))
							text: action.modelData.text
							wrapMode: Text.NoWrap
							maximumLineCount: 1
							color: action.ink
							font.weight: Theme.fontWeight
						}
					}
				}
			}

			// A frame of a set shape: the toast doesn't jump as the file loads.
			Item {
				width: parent.width
				height: frame.y + frame.height
				visible: card.shot

				ClippingRectangle {
					id: frame

					y: Theme.u(6)
					width: parent.width
					height: Math.round(width * 9 / 16)
					radius: Math.max(0, Theme.cardRadius - Theme.u(4))
					color: Theme.hover

					Image {
						anchors.fill: parent
						source: card.shot ? card.picture : ""
						sourceSize.width: width
						fillMode: Image.PreserveAspectFit
						asynchronous: true
					}
				}
			}
		}

		// Beside its app's name, where no heading has that: not made for a toast.
		Loader {
			id: quieter

			anchors.top: parent.top
			anchors.right: copy.left
			anchors.topMargin: -Theme.u(6)
			active: card.inHistory && card.showsApp

			sourceComponent: QuietButton {
				height: Theme.u(26)
				iconSize: Theme.u(16)
				app: card.notification.appName
			}
		}

		Button {
			id: copy

			visible: card.inHistory
			anchors.top: parent.top
			anchors.right: close.left
			anchors.topMargin: -Theme.u(6)
			height: Theme.u(26)
			flat: true
			activeFocusOnTab: false
			icon: "copy"
			iconSize: Theme.u(16)
			ink: Theme.colors.subtext
			onClicked: NotificationStore.copy(card.notification)
		}

		Button {
			id: close

			visible: card.closable

			anchors.top: parent.top
			anchors.right: parent.right
			anchors.topMargin: -Theme.u(6)
			anchors.rightMargin: -Theme.u(6)
			height: Theme.u(26)
			flat: true
			activeFocusOnTab: false
			icon: "close"
			ink: Theme.colors.subtext
			onClicked: card.notification.dismiss()
		}
	}
}
