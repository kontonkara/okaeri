pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the shell does, as Theme is how it looks: settings.json (it has every
// key), and the user's okaeri/settings.json over it, which takes effect as it's
// saved. Sections merge key by key.
Singleton {
	id: settings

	FileView {
		id: defaultsFile

		path: Quickshell.shellPath("settings.json")
		blockLoading: true
	}

	FileView {
		id: userFile

		path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/okaeri/settings.json`
		blockLoading: true
		watchChanges: true
		printErrors: false
		onFileChanged: reload()
		onLoaded: settings.user = Theme.parse(text(), path)
		onLoadFailed: settings.user = {}
	}

	readonly property var defaults: Theme.parse(defaultsFile.text(), defaultsFile.path)
	property var user: ({})

	readonly property var session: Object.assign({}, defaults.session, user.session)
	readonly property var idle: Object.assign({}, defaults.idle, user.idle)
	readonly property var wallpaper: Object.assign({}, defaults.wallpaper, user.wallpaper)
	readonly property var tray: Object.assign({}, defaults.tray, user.tray)
	readonly property var bar: Object.assign({}, defaults.bar, user.bar)
	readonly property var notifications: Object.assign({}, defaults.notifications, user.notifications)
}
