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

			Pick {
				text: "Speed"
				subtext: "Of all that moves"
				enabled: Theme.animate
				options: [
					{ value: "quick", text: "Quick" },
					{ value: "normal", text: "As it is" },
					{ value: "slow", text: "Slow" }
				]
				value: Theme.values.speed ?? "normal"
				onChosen: value => Theme.set("speed", value)
			}

			Pick {
				text: "Panels come"
				subtext: "As they open, and go the same way"
				enabled: Theme.animate
				options: [
					{ value: "grow", text: "Growing" },
					{ value: "fade", text: "Fading in" },
					{ value: "slide", text: "Sliding in" }
				]
				value: Theme.panelMotion
				onChosen: value => Theme.set("panelMotion", value)
			}

			Pick {
				text: "Notifications come"
				enabled: Theme.animate
				options: [
					{ value: "slide", text: "Sliding in" },
					{ value: "fade", text: "Fading in" },
					{ value: "grow", text: "Growing" }
				]
				value: Theme.toastMotion
				onChosen: value => Theme.set("toastMotion", value)
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

			Pick {
				text: "The bar"
				subtext: Settings.bar.look === "islands" ? "Each group of its parts on its own, the desktop between" : "One piece across the screen"
				options: [
					{ value: "whole", text: "Whole" },
					{ value: "islands", text: "Islands" }
				]
				value: Settings.bar.look
				onChosen: value => Settings.set("bar", "look", value)
			}

			Pick {
				text: "Tiles of the control center"
				subtext: Settings.control.size === "small" ? "A line each, with no summary" : "With what they're at under their names"
				options: [
					{ value: "large", text: "Large" },
					{ value: "small", text: "Small" }
				]
				value: Settings.control.size
				onChosen: value => Settings.set("control", "size", value)
			}

			// Past the largest it's round: what's small is, all the way, and a card
			// has the corners it has by default. That's no number in the theme.
			Choice {
				text: "Corners"
				values: [0, 4, 6, 8, 10, 12, 14, 16, 20, 1000]
				value: Theme.values.radius ?? 1000
				none: "Square"
				most: "Round"
				unit: " px"
				onChosen: value => Theme.set("radius", value === 1000 ? null : value)
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
			width: parent.width
			title: "Text"

			Field {
				text: "Font"
				subtext: "A family by its name, as the system has it: empty is the system's own"
				placeholder: Qt.application.font.family
				value: Theme.values.font || ""
				onKept: value => Theme.set("font", value)
			}

			Pick {
				text: "Weight"
				subtext: "Of what stands out: the clock, a title"
				options: [
					{ value: 400, text: "Regular" },
					{ value: 500, text: "Medium" },
					{ value: 600, text: "Semibold" },
					{ value: 700, text: "Bold" }
				]
				value: Theme.values.fontWeight
				onChosen: value => Theme.set("fontWeight", value)
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
				subtext: Theme.values.auto === "sun" ? "From sunrise to sunset, where the night light or the weather is set for" : Theme.timed ? "" : "Or by a key: okaeri theme toggle"
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
