import QtQuick
import qs
import qs.clipboard
import qs.ui

// The clipboard history's button on the bar.
Button {
	height: Theme.u(28)
	flat: true
	activeFocusOnTab: false
	icon: "clipboard"
	onClicked: Clipboard.toggle()
}
