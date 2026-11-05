import QtQuick
import Quickshell
import qs.bar
import qs.notifications

ShellRoot {
	Variants {
		model: Quickshell.screens

		Bar {
			required property var modelData

			screen: modelData
		}
	}

	NotificationCenter {}

	LazyLoader {
		active: Quickshell.env("OKAERI_GALLERY") === "1"

		Gallery {}
	}
}
