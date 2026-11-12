import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui

// One entry of the history whole, in the list's place: its text, which can be
// selected, or its picture, and what can be done with it. Enter copies it and
// Shift+Enter pastes it, or the other way round by the settings, as in the
// list; Ctrl+O opens the first link in it, Ctrl+S saves the picture, Ctrl+P
// pins it, Delete removes it, and Escape or Left goes back to the list.
FocusScope {
	id: look

	required property var entry
	property real room: Theme.u(300)
	readonly property bool picture: !!entry.picture
	// What it says, to as much as is shown: an entry can be a whole file.
	property string whole: ""
	readonly property int most: 100000
	readonly property string link: whole.match(/\b(?:https?|ftp):\/\/[^\s<>"'`]+/)?.[0]?.replace(/[.,;:!?)\]}]+$/, "") ?? ""
	// Where its picture is decoded to, for as long as it shows.
	readonly property string file: entry.pinned ? entry.file : `${Clipboard.pictures}/look-${entry.id}-${Date.now()}`

	signal back
	signal picked(bool paste)
	signal removed

	height: Math.min(room, Math.max(Theme.u(200), body.implicitHeight + actions.height + Theme.u(10)))

	Component.onDestruction: {
		if (picture && !entry.pinned)
			Quickshell.execDetached(["rm", "-f", "--", file]);
	}

	Keys.onPressed: event => {
		const control = !!(event.modifiers & Qt.ControlModifier);
		if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left || event.key === Qt.Key_Backspace)
			look.back();
		else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
			look.picked(!!(event.modifiers & Qt.ShiftModifier) !== Settings.clipboard.paste);
		else if (control && event.key === Qt.Key_O && link)
			open();
		else if (control && event.key === Qt.Key_S && picture)
			save();
		else if (control && event.key === Qt.Key_P)
			pinOrNot();
		else if (event.key === Qt.Key_Delete)
			look.removed();
		else
			return;
		event.accepted = true;
	}

	function open() {
		const url = link;
		Env.act("clipboard open link", () => Qt.openUrlExternally(url));
	}

	// To Settings.clipboard.saveTo, or the Pictures folder, by the time it was saved.
	function save() {
		const folder = Clipboard.saveFolder;
		const name = `${folder}/Clipboard ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.${(entry.subtext ?? "png").split(",")[0].toLowerCase() || "png"}`;
		saver.name = name;
		saver.exec(entry.pinned ? ["sh", "-c", 'mkdir -p "$1" && cp -- "$2" "$3"', "sh", folder, entry.file, name]
			: ["sh", "-c", 'mkdir -p "$1" && cliphist -db-path "$2" decode "$3" >"$4"', "sh", folder, Clipboard.database, entry.id, name]);
	}

	function pinOrNot() {
		if (entry.pinned)
			Clipboard.unpin(entry);
		else
			Clipboard.pin(entry);
		look.back();
	}

	Process {
		id: reader

		running: !look.picture
		command: look.entry.pinned ? ["head", "-c", String(look.most), "--", look.entry.file]
			: ["sh", "-c", 'cliphist -db-path "$1" decode "$2" | head -c "$3"', "sh", Clipboard.database, look.entry.id, String(look.most)]

		stdout: StdioCollector {
			onStreamFinished: look.whole = text
		}
	}

	Process {
		id: decoder

		running: look.picture && !look.entry.pinned
		command: ["sh", "-c", 'mkdir -p "${3%/*}" && cliphist -db-path "$1" decode "$2" >"$3"', "sh", Clipboard.database, look.entry.id, look.file]
		onExited: code => {
			if (code === 0)
				image.source = `file://${look.file}`;
		}
	}

	Process {
		id: saver

		property string name

		onExited: code => {
			// For tests: where it went.
			console.info("okaeri: clipboard: saved", code === 0 ? name : "nothing");
			if (code === 0)
				Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=image-x-generic", "Picture saved", name]);
		}
	}

	Item {
		id: body

		anchors.top: parent.top
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: actions.top
		anchors.bottomMargin: Theme.u(10)
		implicitHeight: look.picture ? Theme.u(260) : words.contentHeight + Theme.u(16)

		Rectangle {
			anchors.fill: parent
			radius: Math.max(0, Theme.cardRadius - Theme.u(4))
			color: Theme.hover
		}

		Image {
			id: image

			anchors.fill: parent
			anchors.margins: Theme.u(6)
			visible: look.picture
			asynchronous: true
			cache: false
			source: look.picture && look.entry.pinned ? `file://${look.file}` : ""
			fillMode: Image.PreserveAspectFit
		}

		Flickable {
			id: words

			anchors.fill: parent
			anchors.margins: Theme.u(8)
			visible: !look.picture
			clip: true
			contentWidth: width
			contentHeight: shown.implicitHeight
			boundsBehavior: Flickable.StopAtBounds

			TextEdit {
				id: shown

				width: words.width
				readOnly: true
				selectByMouse: true
				textFormat: TextEdit.PlainText
				wrapMode: TextEdit.Wrap
				text: look.whole
				color: Theme.colors.text
				selectionColor: Theme.colors.accent
				selectedTextColor: Theme.colors.background
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(1)
			}
		}
	}

	Flow {
		id: actions

		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		spacing: Theme.u(6)

		Button {
			height: Theme.u(30)
			flat: true
			icon: "back"
			tip: "Back · Escape"
			onClicked: look.back()
		}

		Button {
			objectName: "copy"
			height: Theme.u(30)
			icon: "copy"
			text: "Copy"
			onClicked: look.picked(false)
		}

		Button {
			height: Theme.u(30)
			icon: "clipboard"
			text: "Paste"
			onClicked: look.picked(true)
		}

		Button {
			visible: look.link !== ""
			height: Theme.u(30)
			icon: "link"
			text: "Open link"
			tip: `${look.link} · Ctrl+O`
			onClicked: look.open()
		}

		Button {
			visible: look.picture
			height: Theme.u(30)
			icon: "download"
			text: "Save"
			tip: `To ${Clipboard.saveFolder.replace(Quickshell.env("HOME"), "~")} · Ctrl+S`
			onClicked: look.save()
		}

		Button {
			height: Theme.u(30)
			flat: true
			icon: "pin"
			tip: look.entry.pinned ? "Unpin · Ctrl+P" : "Pin · Ctrl+P"
			ink: look.entry.pinned ? Theme.colors.accent : Theme.colors.text
			onClicked: look.pinOrNot()
		}

		Button {
			height: Theme.u(30)
			flat: true
			icon: "trash"
			tip: "Remove · Delete"
			onClicked: look.removed()
		}
	}
}
