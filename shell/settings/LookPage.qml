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
				subtext: "And behind this window and the on-screen display"
				checked: Theme.blur
				onToggled: wanted => Theme.set("blur", wanted)
			}

			Setting {
				text: "Blur behind notifications"
				subtext: "The ones that pop up"
				checked: Theme.toastBlur
				onToggled: wanted => Theme.set("toastBlur", wanted)
			}

			Setting {
				text: "Blur behind the bar"
				subtext: "The wallpaper's, which costs next to nothing"
				checked: Theme.barBlur
				onToggled: wanted => Theme.set("barBlur", wanted)
			}

			Setting {
				text: "Windows in the blur too"
				subtext: "Not only the wallpaper: costs more, and takes a line in niri's config"
				checked: Theme.realBlur
				onToggled: wanted => Theme.set("realBlur", wanted)
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
				subtext: "With none it's against the screen's top, square there"
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

		Card {
			id: colors

			// The palettes by the names they show under.
			readonly property var palettes: Theme.palettes.map(name => ({ value: name, text: name.split("-").map(word => word[0].toUpperCase() + word.slice(1)).join(" ") }))
			readonly property var hours: Array.from({ length: 24 }, (hour, at) => ({ value: `${String(at).padStart(2, "0")}:00`, text: `${String(at).padStart(2, "0")}:00` }))

			width: parent.width
			title: "Colors"

			Pick {
				text: "Palette"
				subtext: Theme.own.extends ? "" : "With your own colors, where the file has them"
				visible: !Theme.timed
				valueWidth: Theme.u(150)
				options: [{ value: "", text: "As the file says" }].concat(colors.palettes)
				value: Theme.own.extends ?? ""
				onChosen: value => Theme.set("extends", value || undefined)
			}

			Pick {
				text: "Another by day"
				subtext: Theme.values.auto === "sun" ? "From sunrise to sunset, where the night light or the weather is set for" : ""
				valueWidth: Theme.u(150)
				options: [
					{ value: "off", text: "No" },
					{ value: "time", text: "By the clock" },
					{ value: "sun", text: "By the sun" }
				]
				value: Theme.values.auto
				onChosen: value => Theme.set("auto", value)
			}

			Pick {
				text: "By day"
				visible: Theme.timed
				valueWidth: Theme.u(150)
				options: colors.palettes
				value: Theme.values.day
				onChosen: value => Theme.set("day", value)
			}

			Pick {
				text: "By night"
				visible: Theme.timed
				valueWidth: Theme.u(150)
				options: colors.palettes
				value: Theme.values.night
				onChosen: value => Theme.set("night", value)
			}

			Pick {
				text: "Day is from"
				visible: Theme.values.auto === "time"
				valueWidth: Theme.u(150)
				options: colors.hours
				value: Theme.values.dayFrom
				onChosen: value => Theme.set("dayFrom", value)
			}

			Pick {
				text: "Night is from"
				visible: Theme.values.auto === "time"
				valueWidth: Theme.u(150)
				options: colors.hours
				value: Theme.values.nightFrom
				onChosen: value => Theme.set("nightFrom", value)
			}

			Setting {
				text: "The accent from the wallpaper"
				subtext: "Its most vivid color, where it has one to speak of"
				checked: !!Theme.values.wallpaperAccent
				onToggled: wanted => Theme.set("wallpaperAccent", wanted)
			}
		}
	}
}
