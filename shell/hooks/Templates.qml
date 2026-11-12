import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

// The palette in other apps' files, as matugen and pywal have it:
// Settings.hooks.templates, each a template file `from` and the file it's
// written `to`, with "~" for the home folder. A `from` that isn't a whole path is
// one of the shell's own, in its templates folder. In a template {{accent}} is
// that color as #rrggbb, {{accent.strip}} the same without the #, {{accent.rgb}}
// as "r, g, b", and so for every color of the palette; {{mode}} is light or dark.
// What it doesn't know it leaves as it is. A file is written as the colors
// settle, which Hooks says, as its template changes, and as the shell starts,
// and only when that changes what's in it.
Scope {
	id: templates

	readonly property string home: Quickshell.env("HOME")
	// The shell's own folder: what's written there changes nothing of the machine's.
	readonly property string ownFolder: `${Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"}/okaeri/`
	// Not before the colors are the ones to keep: the first paint() says they are.
	property bool ready: false
	// Each template and its file as text, for Variants to tell one from another:
	// one with no file to write, or with a file another one writes, isn't there.
	readonly property var list: {
		const all = Array.isArray(Settings.hooks.templates) ? Settings.hooks.templates : [];
		const pairs = [];
		all.forEach(own => {
			const named = where(own?.from ?? "");
			const from = named.startsWith("/") ? named : Quickshell.shellPath(`templates/${named}`);
			const to = where(own?.to ?? "");
			if (named && to.startsWith("/") && from !== to && !pairs.some(pair => pair[1] === to))
				pairs.push([from, to]);
		});
		return pairs.map(pair => JSON.stringify(pair));
	}

	// `path` as it's typed, with "~" for the home folder.
	function where(path) {
		return `${path}`.trim().replace(/^~(?=\/|$)/, home);
	}

	// Every file as the colors are now.
	function paint() {
		ready = true;
		const all = renderers.instances;
		for (let at = 0; at < all.length; at++)
			all[at].render();
	}

	// `text` with the palette's colors in it, and the mode.
	function fill(text) {
		const colors = Theme.colors;
		return text.replace(/\{\{\s*([\w-]+)(?:\.(\w+))?\s*\}\}/g, (whole, name, form) => {
			if (name === "mode" && form === undefined)
				return Theme.light ? "light" : "dark";
			if (!Object.keys(colors).includes(name) || ![undefined, "strip", "rgb"].includes(form))
				return whole;
			try {
				const color = Qt.color(`${colors[name]}`);
				const parts = [color.r, color.g, color.b].map(part => Math.round(part * 255));
				if (form === "rgb")
					return parts.join(", ");
				const hex = parts.map(part => (part < 16 ? "0" : "") + part.toString(16)).join("");
				return form === "strip" ? hex : `#${hex}`;
			} catch (error) {
				return whole;
			}
		});
	}

	Variants {
		id: renderers

		model: templates.list

		Scope {
			id: one

			required property string modelData
			readonly property var pair: JSON.parse(modelData)
			// Written at once in the shell's own folder, and elsewhere as a change to
			// the machine, which a test only logs.
			readonly property bool own: pair[1].startsWith(templates.ownFolder) && !pair[1].includes("/../")
			// What the file has now is known: what's in it, or that it isn't there.
			property bool known: false
			// The template was read, and is there to fill.
			property bool read: false

			function render() {
				if (!templates.ready || !known || !read)
					return;
				const text = templates.fill(templateFile.text());
				if (text === writtenFile.text())
					return;
				if (own)
					writtenFile.setText(text);
				else
					Env.act(`template ${templates.list.indexOf(modelData) + 1}`, () => writtenFile.setText(text));
			}

			FileView {
				id: templateFile

				path: one.pair[0]
				watchChanges: true
				printErrors: false
				onFileChanged: reload()
				onLoaded: {
					one.read = true;
					one.render();
				}
				onLoadFailed: {
					one.read = false;
					console.warn(`okaeri: no template ${path}`);
				}
			}

			// Written as setText() is called, not a moment later: the colors' command
			// runs after it, and can have the app read the file again.
			FileView {
				id: writtenFile

				path: one.pair[1]
				blockWrites: true
				printErrors: false
				onLoaded: {
					one.known = true;
					one.render();
				}
				onLoadFailed: {
					one.known = true;
					one.render();
				}
				onSaveFailed: console.warn(`okaeri: can't write ${path}`)
			}
		}
	}
}
