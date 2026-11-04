import QtQuick
import QtQuick.Shapes
import qs

// A line icon: `name` (one of Theme.icons), stroked in `color`, `size`
// pixels square.
Shape {
	id: icon

	property string name
	property color color: Theme.colors.text
	property real size: Theme.u(18)

	width: size
	height: size
	preferredRendererType: Shape.CurveRenderer

	ShapePath {
		strokeColor: icon.color
		strokeWidth: Math.max(1.5, icon.size / 10)
		fillColor: "transparent"
		capStyle: ShapePath.RoundCap
		joinStyle: ShapePath.RoundJoin
		scale: Qt.size(icon.size / 24, icon.size / 24)

		PathSvg {
			path: Theme.icons[icon.name] || ""
		}
	}
}
