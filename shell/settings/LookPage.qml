import QtQuick
import qs
import qs.ui

// What everything is drawn with, as much of it as a line can say: this goes over
// theme.json, in a file of the shell's own.
Flickable {
	id: page

	contentHeight: column.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	Glide {
		view: page
	}

	Column {
		id: column

		width: parent.width
		spacing: Math.round(Theme.u(10))

		Card {
			width: parent.width
			title: "Glass"

			Setting {
				text: "Blur behind panels"
				subtext: "And behind this window"
				checked: Theme.blur
				onToggled: wanted => Theme.set("blur", wanted)
			}

			Setting {
				text: "Blur behind the bar"
				subtext: "The wallpaper's, which costs next to nothing"
				checked: Theme.barBlur
				onToggled: wanted => Theme.set("barBlur", wanted)
			}

			Choice {
				text: "How solid it stays"
				values: [30, 40, 50, 60, 70, 80, 90]
				value: Theme.values.opacity
				unit: "%"
				onChosen: value => Theme.set("opacity", value)
			}
		}

		Card {
			width: parent.width
			title: "Motion"

			Setting {
				text: "Animations"
				subtext: "Panels, and lists gliding on after the wheel and the fingers"
				checked: Theme.animate
				onToggled: wanted => Theme.set("animations", wanted)
			}
		}

		Card {
			width: parent.width
			title: "Shape"

			Choice {
				text: "Height of the bar"
				values: [26, 28, 30, 32, 34, 36, 38, 40, 44, 48]
				value: Theme.values.barHeight
				unit: " px"
				onChosen: value => Theme.set("barHeight", value)
			}

			Choice {
				text: "Icons on the bar"
				values: [12, 14, 16, 18, 20, 22]
				value: Theme.values.barIcon
				unit: " px"
				onChosen: value => Theme.set("barIcon", value)
			}

			Choice {
				text: "Gap around the bar"
				values: [0, 2, 4, 6, 8, 10, 12]
				value: Theme.values.barMargin
				none: "None"
				unit: " px"
				onChosen: value => Theme.set("barMargin", value)
			}

			Choice {
				text: "Corners"
				values: [0, 4, 6, 8, 10, 12, 14, 16, 20]
				value: Theme.values.radius ?? 14
				none: "Square"
				unit: " px"
				onChosen: value => Theme.set("radius", value)
			}

			Choice {
				text: "Size of the text"
				values: [11, 12, 13, 14, 15, 16, 18]
				value: Theme.values.fontSize
				unit: " px"
				onChosen: value => Theme.set("fontSize", value)
			}

			Choice {
				text: "Size of everything"
				values: [80, 90, 100, 110, 125, 150, 175, 200]
				value: Math.round(Theme.values.scale * 100)
				unit: "%"
				onChosen: value => Theme.set("scale", value / 100)
			}
		}
	}
}
