import QtQuick
import Quickshell
import qs.bar
import qs.control
import qs.launcher
import qs.notifications
import qs.osd

ShellRoot {
	Variants {
		model: Quickshell.screens

		Bar {
			required property var modelData

			screen: modelData
		}
	}

	NotificationCenter {}

	ControlCenter {}

	Launcher {}

	Osd {}

	LazyLoader {
		active: Quickshell.env("OKAERI_GALLERY") === "1"

		Gallery {}
	}
}
