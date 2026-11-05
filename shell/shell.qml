import QtQuick
import Quickshell
import qs.bar
import qs.clipboard
import qs.control
import qs.launcher
import qs.notifications
import qs.osd
import qs.polkit
import qs.session

ShellRoot {
	Variants {
		model: Quickshell.screens

		Bar {
			required property var modelData

			screen: modelData
		}
	}

	NotificationCenter {}

	ClipboardPanel {}

	ControlCenter {}

	Launcher {}

	Osd {}

	PolkitDialog {}

	SessionMenu {}

	LazyLoader {
		active: Quickshell.env("OKAERI_GALLERY") === "1"

		Gallery {}
	}
}
