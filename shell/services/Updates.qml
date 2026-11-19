pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// What there is to update, by the package managers there are: pacman's
// checkupdates, apt, dnf and flatpak, each that's there asked and the names it
// gives counted. Asked as a part on a bar counts itself in, and again every
// Settings.updates.every hours by the clock, which a sleep doesn't stop.
Singleton {
	id: updates

	// Each a name and what lists one update a line, with nothing else: with
	// OKAERI_UPDATES_FILE, as a test has it, that file's lines alone.
	readonly property string file: Quickshell.env("OKAERI_UPDATES_FILE") ?? ""
	readonly property var sources: file ? [{ name: "test", tool: "cat", list: `cat '${file}' 2>/dev/null` }] : [
		{ name: "pacman", tool: "checkupdates", list: "checkupdates 2>/dev/null" },
		{ name: "apt", tool: "apt", list: "apt list --upgradable 2>/dev/null | grep /" },
		{ name: "dnf", tool: "dnf", list: "dnf -q check-update 2>/dev/null | grep -E '^[^ ]+\\.[^ ]+ +[^ ]+ +[^ ]+$'" },
		{ name: "flatpak", tool: "flatpak", list: "flatpak remote-ls --updates --columns=application 2>/dev/null" }
	]
	property int users: 0
	// { source: [names] } of those there are, and when it last looked.
	property var found: ({})
	property double looked: 0
	property bool looking: false
	readonly property var there: Object.keys(found)
	readonly property int count: there.reduce((all, source) => all + found[source].length, 0)

	function look() {
		if (scan.running)
			return;
		looking = true;
		scan.running = true;
	}

	// The command of Settings.updates.command, for a click.
	function run() {
		if (Settings.updates.command)
			Env.act("updates run", () => Quickshell.execDetached(["sh", "-c", Settings.updates.command]));
	}

	onUsersChanged: {
		if (users > 0 && looked === 0)
			look();
	}

	Timer {
		interval: 60 * 1000
		repeat: true
		running: updates.users > 0
		onTriggered: {
			if (Date.now() - updates.looked >= Math.max(1, Settings.updates.every) * 60 * 60 * 1000)
				updates.look();
		}
	}

	// A line a source that's there: its name, a tab, and the names it gave, a
	// space apart.
	Process {
		id: scan

		command: ["sh", "-c", updates.sources.map(source => `if command -v ${source.tool} >/dev/null 2>&1; then printf '%s\\t' ${source.name}; { ${source.list}; } | awk '{ print $1 }' | sed 's|/.*||' | tr '\\n' ' '; echo; fi`).join("\n")]
		stdout: StdioCollector {
			onStreamFinished: {
				const found = {};
				text.split("\n").filter(line => line.includes("\t")).forEach(line => {
					const [name, names] = line.split("\t");
					found[name] = names.split(" ").filter(one => one !== "");
				});
				updates.found = found;
				updates.looked = Date.now();
				updates.looking = false;
			}
		}
	}

	// `okaeri updates look`, after an update, and what there is, as JSON.
	IpcHandler {
		target: "updates"

		function look(): void {
			updates.look();
		}

		function list(): string {
			return JSON.stringify(updates.found);
		}
	}
}
