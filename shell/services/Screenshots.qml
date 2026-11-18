pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs

// Screenshots, as niri takes them: of a part of the screen picked by niri's own
// picker, of the screen in focus, or of the window in focus, those two after
// Settings.screenshots.delay seconds. They go to Settings.screenshots.folder, or
// where niri's config says, and on the clipboard. The latest are those of that
// folder, or of the one the last of niri's notices said it was in.
Singleton {
	id: screenshots

	readonly property var own: Settings.screenshots
	// Where niri put the last one it said it took, kept across starts.
	property string learned
	readonly property string folder: (own.folder || learned || "~/Pictures/Screenshots").replace(/^~(?=\/|$)/, Quickshell.env("HOME"))
	// The kind asked for, waiting out the delay, and how long that still is.
	property string pending
	property int left: 0
	// The newest first: paths.
	readonly property var latest: {
		const found = [];
		for (let at = 0; at < Math.min(shots.count, 12); at++)
			found.push(shots.get(at, "filePath"));
		return found;
	}

	// "area", "screen" or "window": a moment on in any case, for what asked for it,
	// a panel or the launcher, to be gone.
	function take(kind) {
		pending = kind;
		left = kind === "area" ? 0 : own.delay;
		waiting.interval = 300;
		waiting.restart();
	}

	function shoot(kind) {
		const path = own.folder ? `${folder}/Screenshot ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss")}.png` : "";
		Niri.screenshot(kind, path, own.pointer);
	}

	// From niri's notice of one: where it went.
	function saw(file) {
		const where = file.replace(/\/[^/]*$/, "");
		if (!where || where === learned)
			return;
		learned = where;
		kept.setText(JSON.stringify({ folder: where }) + "\n");
	}

	// Onto the clipboard again, a picture.
	function copy(file) {
		Env.act("screenshot copy", () => Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png <"$1"', "sh", file]));
	}

	function open(file) {
		Env.act("screenshot open", () => Quickshell.execDetached(["xdg-open", file]));
	}

	Timer {
		id: waiting

		interval: 300
		onTriggered: {
			if (screenshots.left > 0) {
				screenshots.left -= 1;
				interval = 1000;
				restart();
				return;
			}
			interval = 300;
			screenshots.shoot(screenshots.pending);
			screenshots.pending = "";
		}
	}

	FileView {
		id: kept

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/screenshots.json`
		printErrors: false
		onLoaded: {
			try {
				screenshots.learned = JSON.parse(text()).folder ?? "";
			} catch (error) {}
		}
	}

	FolderListModel {
		id: shots

		folder: Settings.url(screenshots.folder)
		nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
		caseSensitive: false
		showDirs: false
		sortField: FolderListModel.Time
	}

	// `okaeri screenshot area`, `screen` or `window`.
	IpcHandler {
		target: "screenshot"

		function take(kind: string): void {
			if (["area", "screen", "window"].includes(kind))
				screenshots.take(kind);
			else
				console.info(`okaeri: no screenshot of "${kind}": it's area, screen or window`);
		}
	}
}
