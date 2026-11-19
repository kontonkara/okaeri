import QtQuick
import qs
import qs.clipboard
import qs.ui

// The clipboard history's button on the bar.
BarButton {
	icon: "clipboard"
	tip: Tr.t("Clipboard")
	onClicked: Clipboard.toggle()
}
