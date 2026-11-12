pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Codes a phone's camera reads, drawn by qrencode where it's there, a picture
// each in okaeri's own part of the runtime directory, which is the user's alone.
// Whether it's there is `available`, once that's `known`.
Singleton {
	id: qr

	readonly property string tool: "qrencode"
	property bool available: false
	property bool known: false
	readonly property string folder: `${Quickshell.env("XDG_RUNTIME_DIR")}/okaeri`

	Process {
		running: true
		command: ["sh", "-c", `command -v ${qr.tool}`]
		onExited: code => {
			qr.available = code === 0;
			qr.known = true;
		}
	}
}
