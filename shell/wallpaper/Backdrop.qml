import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs

// The wallpaper blurred, for the compositor to put behind its overview. It's read
// small and drawn once, so it costs little and nothing after that. In niri it
// takes a layer rule for okaeri-backdrop, with place-within-backdrop.
PanelWindow {
	id: window

	required property var modelData
	required property string source

	screen: modelData
	anchors {
		top: true
		left: true
		right: true
		bottom: true
	}
	color: Theme.colors.background
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Background
	WlrLayershell.namespace: "okaeri-backdrop"
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	Image {
		id: small

		anchors.fill: parent
		visible: false
		asynchronous: true
		cache: false
		fillMode: Image.PreserveAspectCrop
		source: window.source
		sourceSize: Qt.size(window.width / 4, window.height / 4)
	}

	MultiEffect {
		anchors.fill: parent
		source: small
		autoPaddingEnabled: false
		blurEnabled: true
		blur: 1
		blurMax: 64
		blurMultiplier: 2
	}
}
