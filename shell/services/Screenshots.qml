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

	// What edits a picture, as found: satty or swappy, "" for neither. With
	// Settings.screenshots.editor that goes instead. And whether there's a
	// tesseract, for the text in one, by `reader`, which a test has its own of.
	readonly property var editors: ["satty", "swappy"]
	readonly property string reader: "tesseract"
	property string editor
	property bool reads: false
	readonly property bool edits: own.editor !== "" || editor !== ""

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

	// In the editor: what's saved there goes back into the same file.
	function edit(file) {
		const command = own.editor ? ["sh", "-c", `${own.editor} "$1"`, "sh", file] : editor === "satty" ? ["satty", "--filename", file, "--output-filename", file] : ["swappy", "-f", file, "-o", file];
		Env.act("screenshot edit", () => Quickshell.execDetached(command));
	}

	// The text in picture `file`, in Settings.screenshots.languages, onto the
	// clipboard, and said so.
	function readText(file) {
		Env.act("screenshot text", () => reading.exec([reader, file, "stdout", "-l", own.languages || "eng"]));
	}

	// The same of a part of the screen picked by niri: a picture of its own for
	// that, waited for as niri takes it, and gone after. niri says nothing of it.
	function textOffScreen() {
		const file = `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/okaeri-text-${Date.now()}.png`;
		Env.act("screenshot text area", () => {
			Niri.screenshot("area", file, false);
			reading.exec(["sh", "-c", 'for i in $(seq 1200); do if [ -s "$1" ]; then sleep 0.3; "$2" "$1" stdout -l "$3" 2>/dev/null; code=$?; rm -f "$1"; exit $code; fi; sleep 0.1; done; exit 3', "sh", file, reader, own.languages || "eng"]);
		});
	}

	// niri's word of one taken for its text alone.
	function forText(notification) {
		return notification.appName === "niri" && String(notification.image ?? "").includes("/okaeri-text-");
	}

	function gotText(code, text) {
		const found = text.trim();
		// None picked, in the end.
		if (code === 3)
			return;
		if (!found) {
			Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=dialog-information", "No text there", code === 0 ? "" : `${reader} said no`]);
			return;
		}
		Quickshell.execDetached(["wl-copy", "--", found]);
		Quickshell.execDetached(["notify-send", "--app-name=okaeri", "--icon=edit-copy", "Copied the text", found.length > 200 ? `${found.slice(0, 200)}…` : found]);
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

	// What there is to edit and read with.
	Process {
		running: true
		command: ["sh", "-c", 'for tool; do command -v "$tool" >/dev/null 2>&1 && echo "$tool"; done', "sh"].concat(screenshots.editors, [screenshots.reader])
		stdout: StdioCollector {
			onStreamFinished: {
				const there = text.split("\n");
				screenshots.editor = screenshots.editors.find(tool => there.includes(tool)) ?? "";
				screenshots.reads = there.includes(screenshots.reader);
			}
		}
	}

	Process {
		id: reading

		stdout: StdioCollector {
			id: read
		}
		onExited: code => screenshots.gotText(code, read.text)
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
