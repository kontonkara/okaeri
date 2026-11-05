import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// What the volume or the brightness just became, for a moment, at the bottom
// of the screen in focus. Clicks and keys go to what's under it.
PanelWindow {
	id: osd

	readonly property var icons: ({
		volume: "volume",
		mute: "volumeOff",
		brightness: "sun"
	})
	readonly property real rise: Theme.u(8)
	property string kind: "volume"
	property real level: 0
	property bool shown: false

	function show(kind, level) {
		if (!Object.keys(icons).includes(kind)) {
			console.info(`okaeri: no osd "${kind}", it's one of ${Object.keys(icons).join(", ")}`);
			return;
		}
		osd.kind = kind;
		osd.level = level;
		screen = Niri.focusedScreen;
		shown = true;
		visible = true;
		hold.restart();
	}

	function showVolume() {
		show(Audio.muted ? "mute" : "volume", Audio.volume);
	}

	anchors.bottom: true
	margins.bottom: Theme.u(48) - rise
	implicitWidth: card.width
	implicitHeight: Math.ceil(card.height + rise)
	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	mask: Region {}
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "okaeri-osd"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	// quickshell ipc call -- osd show volume 0.5, the kind being volume, mute or
	// brightness. Without the --, `show` is a command of quickshell's own.
	IpcHandler {
		target: "osd"

		function show(kind: string, level: real): void {
			osd.show(kind, level);
		}
	}

	Watch {
		value: Audio.volume
		ready: Audio.ready
		device: Audio.sink
		onMoved: osd.showVolume()
	}

	Watch {
		value: Audio.muted
		ready: Audio.ready
		device: Audio.sink
		onMoved: osd.showVolume()
	}

	Watch {
		value: Brightness.level
		ready: Brightness.available
		device: Brightness.device
		onMoved: osd.show("brightness", Brightness.level)
	}

	Timer {
		id: hold

		interval: 1500
		onTriggered: osd.shown = false
	}

	Card {
		id: card

		color: Theme.colors.background
		opacity: osd.shown ? 1 : 0
		transform: Translate {
			y: osd.shown ? 0 : osd.rise

			Behavior on y {
				enabled: Theme.animate

				NumberAnimation {
					duration: 160
					easing.type: Easing.OutCubic
				}
			}
		}

		Behavior on opacity {
			enabled: Theme.animate

			NumberAnimation {
				duration: 160
				easing.type: Easing.OutCubic
			}
		}

		onOpacityChanged: {
			if (opacity === 0)
				osd.visible = false;
		}

		Row {
			spacing: Theme.u(10)

			Icon {
				anchors.verticalCenter: parent.verticalCenter
				name: osd.icons[osd.kind]
				color: osd.kind === "mute" ? Theme.colors.subtext : Theme.colors.text
			}

			Slider {
				anchors.verticalCenter: parent.verticalCenter
				value: osd.level
				interactive: false
				enabled: osd.kind !== "mute"

				Behavior on value {
					enabled: Theme.animate && osd.shown

					NumberAnimation {
						duration: 120
						easing.type: Easing.OutCubic
					}
				}
			}
		}
	}
}
