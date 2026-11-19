pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// Plugins: folders in okaeri/plugins of the config directory, each with its
// plugin.json, { name, description, bar, background }, the last two QML files
// of the folder's, either or both. A bar's part goes on the bar by the folder's
// name as any part does; a background one runs with the shell, for what has no
// place of its own, an IpcHandler say. Their code is the shell's own, with all it
// can do: none runs until Settings.plugins.enabled names it.
Singleton {
	id: plugins

	readonly property string folder: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/okaeri/plugins`
	// { id, name, description, bar, background, on, trouble }, by the folder's
	// name, bar and background as URLs or "".
	property var list: []
	readonly property var running: list.filter(plugin => plugin.on && !plugin.trouble)

	function look() {
		scan.running = true;
	}

	function find(id) {
		return running.find(plugin => plugin.id === id) ?? null;
	}

	// The URL of the bar's part of plugin `id` that runs, or "".
	function barOf(id) {
		return find(id)?.bar ?? "";
	}

	function enable(id, wanted) {
		const others = Settings.plugins.enabled.filter(other => other !== id);
		Settings.set("plugins", "enabled", wanted ? others.concat([id]) : others);
	}

	function open() {
		Env.act("plugins open", () => Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && exec xdg-open "$1"', "sh", folder]));
	}

	// A line a plugin: its folder's name, a tab, and its plugin.json on one line.
	function read(text) {
		const found = [];
		for (const line of text.split("\n")) {
			const tab = line.indexOf("\t");
			if (tab < 0)
				continue;
			const id = line.slice(0, tab);
			const file = name => name && !String(name).includes("..") ? `file://${folder}/${id}/${name}` : "";
			try {
				const about = JSON.parse(line.slice(tab + 1));
				found.push({ id, name: String(about.name || id), description: String(about.description || ""), bar: file(about.bar), background: file(about.background), on: Settings.plugins.enabled.includes(id), trouble: "" });
			} catch (error) {
				found.push({ id, name: id, description: "", bar: "", background: "", on: false, trouble: "Its plugin.json can't be read" });
			}
		}
		list = found.sort((a, b) => a.name.localeCompare(b.name));
	}

	Component.onCompleted: look()

	// As one's turned on or off.
	Connections {
		target: Settings

		function onPluginsChanged() {
			plugins.list = plugins.list.map(plugin => Object.assign({}, plugin, { on: Settings.plugins.enabled.includes(plugin.id) }));
		}
	}

	Process {
		id: scan

		command: ["sh", "-c", 'for dir in "$1"/*/; do [ -f "$dir/plugin.json" ] || continue; name=${dir%/}; printf "%s\\t" "${name##*/}"; tr "\\n\\t" "  " <"$dir/plugin.json"; echo; done', "sh", plugins.folder]
		stdout: StdioCollector {
			onStreamFinished: plugins.read(text)
		}
	}

	// A folder that comes or goes is looked at again; and the folder for them too,
	// which may come only after the shell started: watched from the one above it.
	FolderListModel {
		id: inside

		folder: Settings.url(plugins.folder)
		showFiles: false
		onCountChanged: plugins.look()
	}

	FolderListModel {
		folder: Settings.url(plugins.folder.replace(/\/[^/]*$/, ""))
		showFiles: false
		onCountChanged: {
			inside.folder = "";
			inside.folder = Settings.url(plugins.folder);
			plugins.look();
		}
	}

	// `okaeri plugins list`, and `look` after a plugin.json changed.
	IpcHandler {
		target: "plugins"

		function list(): string {
			return JSON.stringify(plugins.list.map(plugin => ({ id: plugin.id, name: plugin.name, on: plugin.on, bar: plugin.bar !== "", background: plugin.background !== "", trouble: plugin.trouble })));
		}

		function look(): void {
			plugins.look();
		}
	}
}
