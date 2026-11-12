import QtQuick
import qs
import qs.services
import qs.ui

// The keyboard layout, when there's more than one: its name's first letters, and
// a click goes to the next, a right click to the one before, and the wheel
// either way.
BarButton {
	readonly property bool wanted: Niri.layouts.length > 1

	visible: wanted
	text: Niri.layoutLabel
	tip: Niri.layouts[Niri.layout] ?? ""
	onClicked: Env.act("layout next", () => Niri.nextLayout())
	onRightClicked: Env.act("layout previous", () => Niri.previousLayout())
	takesWheel: true
	onScrolled: steps => {
		if (steps < 0)
			Env.act("layout next", () => Niri.nextLayout());
		else
			Env.act("layout previous", () => Niri.previousLayout());
	}
}
