import QtQuick
import Quickshell
import Quickshell.Io
import qs

// A network for a phone to join: its name and its password, and beside them the
// code a phone's camera reads for both, drawn while `active` and there only as
// long. `open` is one with no password; `note` goes in the password's place, in
// the error color when `failed`. The picture is `file` in Qr.folder. What the
// code says goes to qrencode by its environment and its input, not as an
// argument, which anyone on the machine could read.
Item {
	id: share

	required property string file
	property bool active: false
	property string name
	property string key
	property bool open: false
	property string note
	property bool failed: false
	// What the code says, once there's all it takes.
	readonly property string says: name !== "" && (open || key !== "") ? Wifi.code(name, open ? "" : key) : ""
	readonly property string path: `${Qr.folder}/${file}`
	readonly property bool wanted: active && Qr.available && says !== ""
	// The picture once it's drawn, and whether one may be on the disk.
	property string picture
	property bool made: false
	// Another was asked for while one was being drawn.
	property bool again: false
	// Even, or what's in its middle would sit on half a pixel.
	readonly property int side: Math.round(Theme.u(68)) * 2

	function draw() {
		picture = "";
		if (coder.running) {
			again = true;
			return;
		}
		if (!wanted) {
			clear();
			return;
		}
		made = true;
		coder.environment = {
			OKAERI_QR: says
		};
		coder.running = true;
	}

	function clear() {
		if (made)
			Quickshell.execDetached(["rm", "-f", path]);
		made = false;
	}

	width: parent.width
	height: Math.max(square.height, words.height) + Theme.u(12)

	onWantedChanged: draw()
	onSaysChanged: draw()
	// A panel opened at its page has it wanted from the start: that's no change.
	Component.onCompleted: draw()
	Component.onDestruction: clear()

	// Black on white, as any phone reads it, with a whole number of pixels to each
	// of its squares, so that none of them blurs; or what keeps it from being
	// there.
	Rectangle {
		id: square

		x: Theme.u(8)
		y: Math.round((parent.height - height) / 2)
		width: share.side
		height: share.side
		radius: Math.max(0, Theme.cardRadius - Theme.u(6))
		color: drawn.visible ? "white" : Theme.hover

		Image {
			id: drawn

			// How many pixels to a square of it.
			readonly property int step: implicitWidth > 0 ? Math.max(1, Math.floor(square.width / implicitWidth)) : 1

			x: Math.round((parent.width - width) / 2)
			y: Math.round((parent.height - height) / 2)
			width: implicitWidth * step
			height: implicitHeight * step
			visible: status === Image.Ready && share.picture !== ""
			source: share.picture ? Settings.url(share.picture) : ""
			cache: false
			smooth: false
		}

		Text {
			x: Theme.u(8)
			y: Math.round((parent.height - height) / 2)
			width: parent.width - Theme.u(16)
			visible: Qr.known && !Qr.available
			horizontalAlignment: Text.AlignHCenter
			wrapMode: Text.WordWrap
			text: "The code needs qrencode, which isn't here."
			color: Theme.colors.subtext
			font.family: Theme.font
			font.pixelSize: Theme.fontSize - Theme.u(2)
		}
	}

	// Anyone nearby picks the names, and a password can be anything too: never
	// markup, all of it in sight.
	Column {
		id: words

		anchors.left: square.right
		anchors.leftMargin: Theme.u(12)
		anchors.right: parent.right
		anchors.rightMargin: Theme.u(8)
		y: Math.round((parent.height - height) / 2)
		spacing: Theme.u(8)

		Column {
			width: parent.width

			Text {
				width: parent.width
				text: "Its name"
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Text {
				width: parent.width
				text: share.name
				textFormat: Text.PlainText
				wrapMode: Text.WrapAnywhere
				maximumLineCount: 2
				elide: Text.ElideRight
				color: Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}
		}

		Column {
			width: parent.width

			Text {
				width: parent.width
				text: "Its password"
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Text {
				width: parent.width
				text: share.open ? "None: it's open" : share.note || share.key
				textFormat: Text.PlainText
				wrapMode: Text.WrapAnywhere
				maximumLineCount: 3
				elide: Text.ElideRight
				color: share.failed ? Theme.colors.error : share.open || share.note ? Theme.colors.subtext : Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}
		}
	}

	Process {
		id: coder

		command: ["sh", "-c", 'mkdir -p "${2%/*}" && printf %s "$OKAERI_QR" | "$1" -t PNG -s 1 -m 2 -o "$2"', "sh", Qr.tool, share.path]
		onExited: code => {
			if (share.again) {
				share.again = false;
				share.draw();
			} else if (code === 0 && share.wanted) {
				share.picture = share.path;
			} else if (!share.wanted) {
				share.clear();
			}
		}
	}
}
