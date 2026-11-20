pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// What apps say of themselves for their icons, by the LauncherEntry signal on
// the session bus, as a download, a build or a copy goes: how far along it is,
// a count, and that they ask to be looked at. By the app's desktop id, its
// .desktop file's name without .desktop; heard while the dock is on and shows
// them, by busctl.
Singleton {
	id: badges

	// { id: { progress, count, urgent } }: progress from 0 to 1, -1 with none
	// shown, and count 0 with none.
	property var entries: ({})
	readonly property bool listening: Settings.dock.on && (Settings.dock.progress || Object.values(Settings.dock.screens ?? {}).some(own => own?.progress))
	readonly property string bus: "busctl"

	// What app { id, entry } said, or null.
	function of(app) {
		const ids = [app?.id, app?.entry?.id].filter(id => !!id).map(id => String(id).toLowerCase());
		const key = Object.keys(entries).find(id => ids.includes(id));
		return key ? entries[key] : null;
	}

	// A line of busctl's: a signal, as JSON.
	function heard(line) {
		let message;
		try {
			message = JSON.parse(line);
		} catch (error) {
			return;
		}
		const [uri, said] = message?.payload?.data ?? [];
		if (typeof uri !== "string" || !said || typeof said !== "object")
			return;
		take(uri, said);
	}

	// What `uri`, application://<id>.desktop, said: each a { type, data }.
	function take(uri, said) {
		const id = uri.replace(/^application:\/\//, "").replace(/\.desktop$/, "").toLowerCase();
		if (!id)
			return;
		const value = key => said[key]?.data;
		const was = entries[id] ?? { progress: -1, count: 0, urgent: false, progressShown: false, countShown: false, at: 0, number: 0 };
		const now = Object.assign({}, was);
		if (value("progress") !== undefined)
			now.at = Math.max(0, Math.min(1, Number(value("progress")) || 0));
		if (value("progress-visible") !== undefined)
			now.progressShown = !!value("progress-visible");
		if (value("count") !== undefined)
			now.number = Math.max(0, Math.round(Number(value("count")) || 0));
		if (value("count-visible") !== undefined)
			now.countShown = !!value("count-visible");
		if (value("urgent") !== undefined)
			now.urgent = !!value("urgent");
		now.progress = now.progressShown ? now.at : -1;
		now.count = now.countShown ? now.number : 0;
		const all = Object.assign({}, entries);
		all[id] = now;
		entries = all;
		// For tests.
		console.info("okaeri: badges:", id, JSON.stringify({ progress: now.progress, count: now.count, urgent: now.urgent }));
	}

	// What's heard is gone with the dock.
	onListeningChanged: {
		if (!listening)
			entries = {};
	}

	Process {
		running: badges.listening
		command: [badges.bus, "--user", "--json=short", "--match", "type='signal',interface='com.canonical.Unity.LauncherEntry',member='Update'", "monitor"]
		stdout: SplitParser {
			onRead: line => badges.heard(line)
		}
	}

	// `okaeri badges list`.
	IpcHandler {
		target: "badges"

		function list(): string {
			return JSON.stringify(badges.entries);
		}
	}
}
