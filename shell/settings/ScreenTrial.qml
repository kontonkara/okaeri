import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// What a change to a screen that can leave it dark asks before it stays: in the
// middle of each screen that's on, over everything, what changed and how long
// till it goes back by itself. Enter keeps it and Escape takes it back, as the
// buttons do; the keys go to the screen in focus.
Scope {
	id: trial

	// What changed, in words.
	function about(change) {
		if (!change)
			return "";
		const value = change.after;
		const what = change.key === "mode" ? (() => {
				const [size, rate] = String(value).split("@");
				return `${size.replace("x", "×")} at ${Math.round(Number(rate))} Hz`;
			})()
			: change.key === "scale" ? `Scaled to ${Math.round(value * 100)}%`
			: change.key === "transform" ? (value === "normal" ? "Not turned" : `Turned ${value}°`)
			: change.key === "on" ? (value ? "On" : "Off")
			: "Changed";
		return `${change.name}: ${what}`;
	}

	Variants {
		model: Screens.trial ? Quickshell.screens : []

		PanelWindow {
			id: window

			required property var modelData
			readonly property bool keyed: modelData.name === (Niri.focusedScreen?.name ?? Quickshell.screens[0]?.name)

			screen: modelData
			anchors {
				top: true
				bottom: true
				left: true
				right: true
			}
			color: "transparent"
			exclusionMode: ExclusionMode.Ignore
			WlrLayershell.layer: WlrLayer.Overlay
			WlrLayershell.namespace: "okaeri-trial"
			WlrLayershell.keyboardFocus: keyed ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
			mask: Region {
				item: card
			}

			Card {
				id: card

				anchors.centerIn: parent
				width: Theme.u(380)
				focus: true
				color: Theme.panel
				title: "Keep this?"
				Keys.onReturnPressed: Screens.keepTrial()
				Keys.onEnterPressed: Screens.keepTrial()
				Keys.onEscapePressed: Screens.dropTrial()

				Text {
					width: parent.width
					text: trial.about(Screens.trial)
					textFormat: Text.PlainText
					wrapMode: Text.Wrap
					color: Theme.colors.text
					font.family: Theme.font
					font.pixelSize: Theme.fontSize + Theme.u(1)
				}

				Text {
					width: parent.width
					text: `It goes back in ${Screens.left} s`
					color: Theme.colors.subtext
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
					font.features: {
						"tnum": 1
					}
				}

				Row {
					anchors.right: parent.right
					spacing: Theme.u(6)

					Button {
						height: Theme.u(32)
						flat: true
						text: "Back"
						tip: "Escape"
						onClicked: Screens.dropTrial()
					}

					Button {
						height: Theme.u(32)
						filled: true
						text: "Keep"
						tip: "Enter"
						onClicked: Screens.keepTrial()
					}
				}
			}
		}
	}
}
