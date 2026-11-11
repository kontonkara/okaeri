import QtQuick
import Quickshell
import qs
import qs.bar
import qs.clipboard
import qs.control
import qs.hooks
import qs.idle
import qs.keys
import qs.launcher
import qs.notifications
import qs.osd
import qs.polkit
import qs.session
import qs.settings
import qs.wallpaper

ShellRoot {
	Variants {
		model: Quickshell.screens.filter(screen => Settings.barOn(screen))

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

	SettingsWindow {}

	Keys {}

	Idle {}

	Hooks {}

	Wallpaper {}

	LazyLoader {
		active: Quickshell.env("OKAERI_GALLERY") === "1"

		Gallery {}
	}
}
