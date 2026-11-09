import QtQuick
import qs
import qs.services
import qs.ui

// How busy the processor is, how much memory is in use and how warm the
// processor is, each as Settings.system says, in red when it's hot. The pointer
// on it says it in full.
Button {
	id: button

	readonly property var own: Settings.system
	readonly property bool hot: System.temperature >= 85
	readonly property var parts: [
		own.cpu && System.cpu >= 0 ? `${System.cpu}%` : "",
		own.memory && System.memory >= 0 ? `${System.memory}%` : "",
		own.temperature && System.temperature >= 0 ? `${System.temperature}°` : ""
	].filter(part => part !== "")
	readonly property bool wanted: parts.length > 0

	function gib(bytes) {
		return (bytes / 1073741824).toFixed(1);
	}

	height: Theme.u(28)
	visible: wanted
	flat: true
	pad: Theme.u(6)
	iconSize: Theme.barIcon
	activeFocusOnTab: false
	icon: "chip"
	text: parts.join("  ")
	ink: hot ? Theme.colors.error : Theme.colors.text
	tip: [
		System.cpu >= 0 ? `Processor ${System.cpu}%` : "",
		System.memory >= 0 ? `Memory ${gib(System.memoryUsed)} of ${gib(System.memoryTotal)} GiB` : "",
		System.temperature >= 0 ? `${System.temperature} °C` : ""
	].filter(part => part !== "").join(" · ")

	Component.onCompleted: System.users += 1
	Component.onDestruction: System.users -= 1
}
