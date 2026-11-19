import QtQuick
import qs

// For layer.effect: the theme's text, and its dimmer text, as `to` in what it's
// over; the rest, an accent or an app's icon, keeps its own colors.
ShaderEffect {
	property color to: Theme.colors.text
	readonly property color text: Theme.colors.text
	readonly property color subtext: Theme.colors.subtext
	readonly property real dim: 0.7

	fragmentShader: Qt.resolvedUrl("shaders/recolor.frag.qsb")
}
