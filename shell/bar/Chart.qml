import QtQuick
import QtQuick.Shapes
import qs

// A line of `values` over time, the newest at its right end: from nothing at its
// foot to `full` at its head, with room for `count` of them.
Rectangle {
	id: chart

	property var values: []
	property real full: 100
	property int count: 60
	property color ink: Theme.colors.accent
	// Each value's place: across by its turn, up by how much of `full` it is.
	readonly property var points: values.map((value, at) => Qt.point(
		width - (values.length - 1 - at) * width / Math.max(1, count - 1),
		height - 1 - Math.max(0, Math.min(1, value / Math.max(1, full))) * (height - 2)))

	implicitHeight: Theme.u(44)
	radius: Math.max(0, Theme.cardRadius - Theme.u(4))
	color: Theme.hover
	clip: true

	Shape {
		anchors.fill: parent
		visible: chart.values.length > 1
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			strokeColor: chart.ink
			strokeWidth: Math.max(1.5, Theme.u(1.5))
			fillColor: "transparent"
			capStyle: ShapePath.RoundCap
			joinStyle: ShapePath.RoundJoin

			PathPolyline {
				path: chart.points
			}
		}
	}
}
