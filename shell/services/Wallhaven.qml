pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Pictures from Wallhaven, looked for only when asked: those safe for work, as
// large as the screen in focus or larger, the best fits first. One that's taken
// goes into the wallpaper folder by curl, then up as the wallpaper.
Singleton {
	id: wallhaven

	readonly property string api: Quickshell.env("OKAERI_WALLHAVEN_URL") || "https://wallhaven.cc"
	// What was asked, and what it found: { id, thumb, full, size, kind }.
	property string asked
	property var found: []
	property bool looking: false
	property string trouble
	// The id of one being fetched, and where it's to go.
	property string taking
	property string target

	// Pictures that have `query`, or with "" the most liked of late.
	function search(query) {
		asked = query.trim();
		looking = true;
		trouble = "";
		const screen = Niri.focusedScreen;
		const least = screen ? `&atleast=${Math.round(screen.width * (screen.devicePixelRatio || 1))}x${Math.round(screen.height * (screen.devicePixelRatio || 1))}` : "";
		const request = new XMLHttpRequest();
		request.onreadystatechange = () => {
			if (request.readyState !== XMLHttpRequest.DONE)
				return;
			looking = false;
			if (request.status !== 200) {
				trouble = request.status ? `Wallhaven said ${request.status}` : "Wallhaven didn't answer";
				found = [];
				return;
			}
			try {
				found = (JSON.parse(request.responseText).data ?? []).map(one => ({ id: String(one.id), thumb: one.thumbs?.small ?? "", full: one.path ?? "", size: one.resolution ?? "", kind: one.file_type ?? "" })).filter(one => one.full);
			} catch (error) {
				trouble = "Wallhaven's answer can't be read";
				found = [];
			}
		};
		const sorting = asked ? "relevance" : "toplist";
		request.open("GET", `${api}/api/v1/search?q=${encodeURIComponent(asked)}&categories=110&purity=100&sorting=${sorting}${least}`);
		request.send();
	}

	// Into the folder, and up: a name of its own, so it's found again.
	function take(one, folder, then) {
		const ext = one.full.match(/\.(\w+)$/)?.[1] ?? "jpg";
		target = `${folder}/wallhaven-${one.id}.${ext}`;
		taking = one.id;
		trouble = "";
		fetching.then = then;
		Env.act(`wallpaper download ${one.id}`, () => fetching.exec(["sh", "-c", 'mkdir -p "${2%/*}" && curl -fsSL --max-time 120 -o "$2.part" "$1" && mv "$2.part" "$2"', "sh", one.full, target]));
	}

	Process {
		id: fetching

		property var then: null

		stderr: StdioCollector {
			id: fetchSaid
		}
		onExited: code => {
			wallhaven.taking = "";
			if (code !== 0) {
				wallhaven.trouble = fetchSaid.text.trim().split("\n").pop() || "It didn't come";
				return;
			}
			if (then)
				then(wallhaven.target);
		}
	}
}
