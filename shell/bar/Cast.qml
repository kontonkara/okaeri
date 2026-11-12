import QtQuick
import qs
import qs.services
import qs.ui

// While something is showing the screen or a window: an icon, and a click to stop
// all of it. niri can only stop PipeWire's, so the others have just the icon.
// The pointer on it says what each shows, and to which app.
BarButton {
	readonly property var shown: Niri.casts.filter(c => c.is_active)
	// An app can hold a few, and a session a few streams.
	readonly property var sessions: shown.filter(c => c.kind === "PipeWire").map(c => c.session_id).filter((s, i, all) => all.indexOf(s) === i)
	readonly property bool wanted: shown.length > 0
	// Each as "what → who": the screen by its name or the window by its title, and
	// the app that has it by its window.
	readonly property string about: shown.map(cast => {
		const target = cast.target ?? {};
		const what = target.Output ? target.Output.name : target.Window ? (Niri.windows.find(window => window.id === target.Window.id)?.title ?? "A window") : "The screen";
		const who = cast.pid ? Niri.windows.find(window => window.pid === cast.pid)?.app_id ?? "" : "";
		return who ? `${what} → ${who}` : what;
	}).filter((line, at, all) => all.indexOf(line) === at).join(", ")

	visible: wanted
	enabled: sessions.length > 0
	opacity: 1
	icon: "cast"
	text: enabled && !stacked ? "Stop" : ""
	tip: `${about || "The screen is shared"}${enabled ? ": a click stops it" : ""}`
	ink: Theme.colors.error
	onClicked: {
		for (const session of sessions)
			Env.act(`cast stop ${session}`, () => Niri.stopCast(session));
	}
}
