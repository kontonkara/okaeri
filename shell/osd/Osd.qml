import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// What the volume, the microphone, the brightness, the keyboard layout or a lock
// key just became, for a moment, at the bottom of the screen in focus. Clicks and
// keys go to what's under it.
PanelWindow {
	id: osd

	readonly property var icons: ({
		volume: "volume",
		mute: "volumeOff",
		brightness: "sun",
		mic: "mic",
		micMute: "micOff",
		layout: "keyboard",
		caps: "capsLock",
		num: "numLock"
	})
	readonly property real rise: Theme.u(8)
	property string kind: "volume"
	property real level: 0
	readonly property bool lock: kind === "caps" || kind === "num"
	readonly property bool off: kind === "mute" || kind === "micMute" || (lock && level === 0)
	// What it says in words, if that's what it shows and not a level.
	readonly property string label: kind === "layout" ? Niri.layoutLabel
		: lock ? `${kind === "caps" ? "Caps Lock" : "Num Lock"} ${off ? "off" : "on"}`
		: ""
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

	function showMic() {
		show(Audio.micMuted ? "micMute" : "mic", Audio.micVolume);
	}

	function showLayout() {
		show("layout", 0);
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

	// quickshell ipc call -- osd show volume 0.5, the kind one of `icons`.
	// Without the --, `show` is a command of quickshell's own.
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

	Watch {
		value: Audio.micMuted
		ready: Audio.micReady
		device: Audio.source
		onMoved: osd.showMic()
	}

	Watch {
		value: Niri.layout
		ready: Niri.layouts.length > 1
		device: Niri.layouts.join()
		onMoved: osd.showLayout()
	}

	Watch {
		value: Locks.caps
		ready: Locks.ready
		device: Locks.device
		onMoved: osd.show("caps", Locks.caps ? 1 : 0)
	}

	Watch {
		value: Locks.num
		ready: Locks.ready
		device: Locks.device
		onMoved: osd.show("num", Locks.num ? 1 : 0)
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
				color: osd.off ? Theme.colors.subtext : Theme.colors.text
			}

			Text {
				anchors.verticalCenter: parent.verticalCenter
				visible: osd.label !== ""
				text: osd.label
				color: Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				font.weight: Theme.fontWeight
			}

			Slider {
				anchors.verticalCenter: parent.verticalCenter
				value: osd.level
				interactive: false
				visible: osd.label === ""
				enabled: !osd.off

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
