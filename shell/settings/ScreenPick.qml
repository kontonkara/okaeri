import QtQuick
import Quickshell
import qs

// A line to pick which screen something shows on: the one in focus, or one by
// its name, the one picked kept there while it's not connected.
Pick {
	options: [{ value: "", text: Tr.t("The one in focus") }].concat([...new Set(Quickshell.screens.map(screen => screen.name).concat(value ? [value] : []))].map(name => ({ value: name, text: Quickshell.screens.some(screen => screen.name === name) ? name : Tr.f("%1, not connected", name) })))
	valueWidth: Theme.u(160)
}
