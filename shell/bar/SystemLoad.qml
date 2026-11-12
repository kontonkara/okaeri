import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// How busy the processor is, how much memory is in use, how warm the processor
// is and how fast the network goes, each as Settings.system says, in red when
// it's hot. The pointer on it says it in full, with the swap and the disk, and a
// click shows how each has gone over the last while.
BarButton {
	id: button

	readonly property var own: Settings.system
	readonly property bool hot: System.temperature >= 85
	readonly property var parts: [
		own.cpu && System.cpu >= 0 ? `${System.cpu}%` : "",
		own.memory && System.memory >= 0 ? `${System.memory}%` : "",
		own.temperature && System.temperature >= 0 ? `${System.temperature}°` : "",
		own.network ? `↓${System.rate(System.down)} ↑${System.rate(System.up)}` : ""
	].filter(part => part !== "")
	readonly property bool wanted: parts.length > 0

	function gib(bytes) {
		return (bytes / 1073741824).toFixed(1);
	}

	visible: wanted
	icon: "chip"
	text: parts.join(stacked ? "\n" : "  ")
	ink: hot ? Theme.colors.error : Theme.colors.text
	tip: [
		System.cpu >= 0 ? `Processor ${System.cpu}%` : "",
		System.memory >= 0 ? `Memory ${gib(System.memoryUsed)} of ${gib(System.memoryTotal)} GiB` : "",
		System.temperature >= 0 ? `${System.temperature} °C` : "",
		System.swap >= 0 ? `Swap ${System.swap}%` : "",
		System.disk >= 0 ? `Disk ${System.disk}%` : "",
		`Down ${System.rate(System.down)}/s, up ${System.rate(System.up)}/s`
	].filter(part => part !== "").join(" · ")

	Component.onCompleted: System.users += 1
	Component.onDestruction: System.users -= 1

	onClicked: flip()

	// On this bar's screen, not the one in focus: a click can come from another.
	function flip() {
		load.middle = Panels.middleOf(button);
		if (load.shown)
			load.hide();
		else
			load.show(button.QsWindow.window.screen);
	}

	// `okaeri load toggle`, for a key.
	Connections {
		target: Panels

		function onPartWanted(name, screen) {
			if (name !== "load" || Panels.answered || (screen !== "" && screen !== button.QsWindow.window?.screen?.name))
				return;
			Panels.answered = true;
			button.flip();
		}
	}

	Panel {
		id: load

		align: "top"
		panelWidth: Theme.u(320)

		Loader {
			width: parent.width
			active: load.visible

			sourceComponent: LoadCard {}
		}
	}
}
