import QtQuick
import qs
import qs.services
import qs.ui

// While something is showing the screen or a window: an icon, and a click to stop
// all of it. niri can only stop PipeWire's, so the others have just the icon.
Button {
	readonly property var shown: Niri.casts.filter(c => c.is_active)
	// An app can hold a few, and a session a few streams.
	readonly property var sessions: shown.filter(c => c.kind === "PipeWire").map(c => c.session_id).filter((s, i, all) => all.indexOf(s) === i)
	readonly property bool wanted: shown.length > 0

	height: Theme.u(28)
	visible: wanted
	enabled: sessions.length > 0
	opacity: 1
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	icon: "cast"
	text: enabled ? "Stop" : ""
	ink: Theme.colors.error
	onClicked: {
		for (const session of sessions)
			Env.act(`cast stop ${session}`, () => Niri.stopCast(session));
	}
}
