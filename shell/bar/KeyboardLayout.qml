import QtQuick
import qs
import qs.services
import qs.ui

// The keyboard layout, when there's more than one: its name's first letters, and
// a click goes to the next.
Button {
	readonly property bool wanted: Niri.layouts.length > 1

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	activeFocusOnTab: false
	text: Niri.layoutLabel
	onClicked: Env.act("layout next", () => Niri.nextLayout())
}
