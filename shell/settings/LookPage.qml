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
			title: Tr.t("Glass")

			Setting {
				holds: "theme.blur"
				text: Tr.t("Blur behind panels")
				subtext: Tr.t("And behind this window and the on-screen display")
				checked: Theme.blur
				onToggled: wanted => Theme.set("blur", wanted)
			}

			Setting {
				holds: "theme.toastBlur"
				text: Tr.t("Blur behind notifications")
				subtext: Tr.t("The ones that pop up")
				checked: Theme.toastBlur
				onToggled: wanted => Theme.set("toastBlur", wanted)
			}

			Setting {
				holds: "theme.barBlur"
				text: Tr.t("Blur behind the bar")
				subtext: Tr.t("The wallpaper's, which costs next to nothing")
				checked: Theme.barBlur
				onToggled: wanted => Theme.set("barBlur", wanted)
			}

			Setting {
				holds: "theme.realBlur"
				text: Tr.t("Windows in the blur too")
				subtext: Tr.t("Not only the wallpaper: costs more, and takes a line in niri's config")
				checked: Theme.realBlur
				onToggled: wanted => Theme.set("realBlur", wanted)
			}

			Choice {
				holds: "theme.opacity"
				text: Tr.t("How solid it stays")
				values: [30, 40, 50, 60, 70, 80, 90]
				value: Theme.values.opacity
				unit: "%"
				onChosen: value => Theme.set("opacity", value)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Motion")

			Setting {
				holds: "theme.animations"
				words: "motion effects transitions"
				text: Tr.t("Animations")
				subtext: Tr.t("Panels, and lists gliding on after the wheel and the fingers")
				checked: Theme.animate
				onToggled: wanted => Theme.set("animations", wanted)
			}

			Pick {
				holds: "theme.speed"
				text: Tr.t("Speed")
				subtext: Tr.t("Of all that moves")
				enabled: Theme.animate
				options: [
					{ value: "quick", text: Tr.t("Quick") },
					{ value: "normal", text: Tr.t("As it is") },
					{ value: "slow", text: Tr.t("Slow") }
				]
				value: Theme.values.speed ?? "normal"
				onChosen: value => Theme.set("speed", value)
			}

			Pick {
				holds: "theme.panelMotion"
				text: Tr.t("Panels come")
				subtext: Tr.t("As they open, and go the same way")
				enabled: Theme.animate
				options: [
					{ value: "grow", text: Tr.t("Growing") },
					{ value: "fade", text: Tr.t("Fading in") },
					{ value: "slide", text: Tr.t("Sliding in") }
				]
				value: Theme.panelMotion
				onChosen: value => Theme.set("panelMotion", value)
			}

			Pick {
				holds: "theme.toastMotion"
				text: Tr.t("Notifications come")
				enabled: Theme.animate
				options: [
					{ value: "slide", text: Tr.t("Sliding in") },
					{ value: "fade", text: Tr.t("Fading in") },
					{ value: "grow", text: Tr.t("Growing") }
				]
				value: Theme.toastMotion
				onChosen: value => Theme.set("toastMotion", value)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Shape")

			Choice {
				holds: "theme.barHeight"
				text: Tr.t("Height of the bar")
				values: [26, 28, 30, 32, 34, 36, 38, 40, 44, 48]
				value: Theme.values.barHeight
				unit: " px"
				onChosen: value => Theme.set("barHeight", value)
			}

			Choice {
				holds: "theme.barIcon"
				text: Tr.t("Icons on the bar")
				values: [12, 14, 16, 18, 20, 22]
				value: Theme.values.barIcon
				unit: " px"
				onChosen: value => Theme.set("barIcon", value)
			}

			Choice {
				holds: "theme.barMargin"
				text: Tr.t("Gap around the bar")
				subtext: Tr.t("With none it's against the screen's top, square there")
				values: [0, 2, 4, 6, 8, 10, 12]
				value: Theme.values.barMargin
				none: Tr.t("None")
				unit: " px"
				onChosen: value => Theme.set("barMargin", value)
			}

			Pick {
				holds: "bar.look"
				text: Tr.t("The bar")
				subtext: Settings.bar.look === "islands" ? Tr.t("Each group of its parts on its own, the desktop between") : Tr.t("One piece across the screen")
				options: [
					{ value: "whole", text: Tr.t("Whole") },
					{ value: "islands", text: Tr.t("Islands") }
				]
				value: Settings.bar.look
				onChosen: value => Settings.set("bar", "look", value)
			}

			Pick {
				holds: "control.size"
				text: Tr.t("Tiles of the control center")
				subtext: Settings.control.size === "small" ? Tr.t("A line each, with no summary") : Tr.t("With what they're at under their names")
				options: [
					{ value: "large", text: Tr.t("Large") },
					{ value: "small", text: Tr.t("Small") }
				]
				value: Settings.control.size
				onChosen: value => Settings.set("control", "size", value)
			}

			// Past the largest it's round: what's small is, all the way, and a card
			// has the corners it has by default. That's no number in the theme.
			Choice {
				holds: "theme.radius"
				words: "rounded"
				text: Tr.t("Corners")
				values: [0, 4, 6, 8, 10, 12, 14, 16, 20, 1000]
				value: Theme.values.radius ?? 1000
				none: Tr.t("Square")
				most: "Round"
				unit: " px"
				onChosen: value => Theme.set("radius", value === 1000 ? null : value)
			}

			Choice {
				holds: "theme.fontSize"
				text: Tr.t("Size of the text")
				values: [11, 12, 13, 14, 15, 16, 18]
				value: Theme.values.fontSize
				unit: " px"
				onChosen: value => Theme.set("fontSize", value)
			}

			Choice {
				holds: "theme.scale"
				words: "zoom dpi bigger smaller"
				text: Tr.t("Size of everything")
				values: [80, 90, 100, 110, 125, 150, 175, 200]
				value: Math.round(Theme.values.scale * 100)
				unit: "%"
				onChosen: value => Theme.set("scale", value / 100)
			}
		}

		Card {
			width: parent.width
			title: Tr.t("Text")

			Field {
				holds: "theme.font"
				words: "typeface"
				text: Tr.t("Font")
				subtext: Tr.t("A family by its name, as the system has it: empty is the system's own")
				placeholder: Qt.application.font.family
				value: Theme.values.font || ""
				onKept: value => Theme.set("font", value)
			}

			Pick {
				holds: "theme.fontWeight"
				text: Tr.t("Weight")
				subtext: Tr.t("Of what stands out: the clock, a title")
				options: [
					{ value: 400, text: Tr.t("Regular") },
					{ value: 500, text: Tr.t("Medium") },
					{ value: 600, text: Tr.t("Semibold") },
					{ value: 700, text: Tr.t("Bold") }
				]
				value: Theme.values.fontWeight
				onChosen: value => Theme.set("fontWeight", value)
			}
		}

		// Looks kept by a name: all this page set, to have again by a click, or by
		// `okaeri theme look <name>`.
		Card {
			width: parent.width
			title: Tr.t("Looks kept")

			Field {
				text: Tr.t("Keep this look as")
				subtext: Tr.t("All that's set on this page, by a name")
				words: "preset profile theme save"
				placeholder: "evening"
				fieldWidth: Theme.u(160)
				value: ""
				onKept: value => Theme.keepLook(value.trim())
			}

			Repeater {
				model: Object.keys(Theme.looks).sort()

				Item {
					required property string modelData

					width: parent.width
					height: Theme.u(34)

					Text {
						anchors.left: parent.left
						anchors.right: use.left
						anchors.rightMargin: Theme.u(12)
						anchors.verticalCenter: parent.verticalCenter
						text: parent.modelData
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: Theme.colors.text
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Button {
						id: use

						anchors.right: drop.left
						anchors.rightMargin: Theme.u(6)
						anchors.verticalCenter: parent.verticalCenter
						height: Theme.u(28)
						text: Tr.t("Use")
						onClicked: Theme.useLook(parent.modelData)
					}

					Button {
						id: drop

						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						height: Theme.u(28)
						flat: true
						icon: "trash"
						tip: Tr.t("Forget it")
						onClicked: Theme.dropLook(parent.modelData)
					}
				}
			}
		}

		Card {
			id: colors

			// The palettes by the names they show under.
			readonly property var palettes: Theme.palettes.map(name => ({ value: name, text: name.split("-").map(word => word[0].toUpperCase() + word.slice(1)).join(" "), colors: dots(name) }))
			// An accent of one's own, as one of these or any other.
			readonly property var swatches: ["#e06c75", "#f0a35e", "#e5c07b", "#98c379", "#56b6c2", "#61afef", "#a98bf0", "#f28cbf"]

			// What a palette looks like, as dots under its name.
			function dots(name) {
				const all = Theme.colorsOf(name);
				return ["background", "surface", "text", "accent", "error"].map(key => all[key]);
			}

			function paint(accent) {
				Theme.set("accent", accent || undefined);
				if (accent && Theme.values.wallpaperAccent)
					Theme.set("wallpaperAccent", false);
			}
			readonly property var hours: Array.from({ length: 24 }, (hour, at) => ({ value: `${String(at).padStart(2, "0")}:00`, text: `${String(at).padStart(2, "0")}:00` }))

			width: parent.width
			title: Tr.t("Colors")

			Pick {
				holds: "theme.extends"
				words: "theme dark light mode colours scheme"
				text: Tr.t("Palette")
				subtext: Theme.own.extends ? "" : Tr.t("With your own colors, where the file has them")
				visible: !Theme.timed
				valueWidth: Theme.u(150)
				options: [{ value: "", text: Tr.t("As the file says"), colors: colors.dots("") }].concat(colors.palettes)
				value: Theme.own.extends ?? ""
				onChosen: value => Theme.set("extends", value || undefined)
			}

			Pick {
				holds: "theme.auto"
				words: "dark mode light mode automatic schedule"
				text: Tr.t("Another by day")
				subtext: Theme.values.auto === "sun" ? Tr.t("From sunrise to sunset, where the night light or the weather is set for") : Theme.timed ? "" : Tr.t("Or by a key: okaeri theme toggle")
				valueWidth: Theme.u(150)
				options: [
					{ value: "off", text: Tr.t("No") },
					{ value: "time", text: Tr.t("By the clock") },
					{ value: "sun", text: Tr.t("By the sun") }
				]
				value: Theme.values.auto
				onChosen: value => Theme.set("auto", value)
			}

			Pick {
				holds: "theme.day"
				text: Tr.t("By day")
				visible: Theme.timed
				valueWidth: Theme.u(150)
				options: colors.palettes
				value: Theme.values.day
				onChosen: value => Theme.set("day", value)
			}

			Pick {
				holds: "theme.night"
				text: Tr.t("By night")
				visible: Theme.timed
				valueWidth: Theme.u(150)
				options: colors.palettes
				value: Theme.values.night
				onChosen: value => Theme.set("night", value)
			}

			Pick {
				holds: "theme.dayFrom"
				text: Tr.t("Day is from")
				visible: Theme.values.auto === "time"
				valueWidth: Theme.u(150)
				options: colors.hours
				value: Theme.values.dayFrom
				onChosen: value => Theme.set("dayFrom", value)
			}

			Pick {
				holds: "theme.nightFrom"
				text: Tr.t("Night is from")
				visible: Theme.values.auto === "time"
				valueWidth: Theme.u(150)
				options: colors.hours
				value: Theme.values.nightFrom
				onChosen: value => Theme.set("nightFrom", value)
			}

			// The palette's own first, then those of the list: a click on one has it,
			// over any palette, the wallpaper's too.
			Item {
				// For the search and the mark, as a line has them.
				readonly property string text: Tr.t("Accent")
				readonly property string subtext: Tr.t("Of your own")
				readonly property string words: "colour highlight swatch"
				readonly property string holds: "theme.accent"

				width: parent.width
				height: Theme.u(40)

				Mark {
					holds: parent.holds
				}

				Column {
					anchors.left: parent.left
					anchors.right: swatches.left
					anchors.rightMargin: Theme.u(12)
					anchors.verticalCenter: parent.verticalCenter

					Text {
						width: parent.width
						text: Tr.t("Accent")
						color: Theme.colors.text
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Text {
						width: parent.width
						text: Theme.values.wallpaperAccent && Theme.vivid ? Tr.t("The wallpaper's, as below") : Theme.accent ? Tr.t("Your own, over the palette's") : Tr.t("The palette's")
						color: Theme.colors.subtext
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(2)
					}
				}

				Row {
					id: swatches

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: Theme.u(6)

					Repeater {
						model: [""].concat(colors.swatches)

						Rectangle {
							required property string modelData
							readonly property bool on: Theme.accent === modelData

							objectName: `swatch-${modelData || "palette"}`
							width: Theme.u(22)
							height: width
							radius: Theme.round(height)
							color: modelData || Theme.palette.accent
							border.width: on ? Theme.u(2.5) : 1
							border.color: on ? Theme.colors.text : Qt.alpha(Theme.colors.text, 0.3)

							// The palette's own has a line through it.
							Rectangle {
								anchors.centerIn: parent
								visible: parent.modelData === ""
								width: parent.width * 0.8
								height: Math.max(1, Theme.u(1.5))
								rotation: -45
								color: Theme.colors.background
							}

							MouseArea {
								anchors.fill: parent
								cursorShape: Qt.PointingHandCursor
								onClicked: colors.paint(parent.modelData)
							}
						}
					}
				}
			}

			Field {
				text: Tr.t("Or any other")
				subtext: Tr.t("As #rrggbb; empty for the palette's")
				placeholder: "#rrggbb"
				fieldWidth: Theme.u(120)
				value: Theme.accent
				onKept: value => {
					const wanted = value.trim().replace(/^([0-9a-fA-F]{6})$/, "#$1");
					if (wanted === "" || /^#[0-9a-fA-F]{6}$/.test(wanted))
						colors.paint(wanted.toLowerCase());
				}
			}

			// Two keys in one line: the accent alone, or with it all the rest.
			Pick {
				holds: "theme.wallpaperAccent"
				words: "material you matugen pywal generate scheme"
				text: Tr.t("From the wallpaper")
				subtext: Tr.t("By its most vivid color, where it has one to speak of")
				valueWidth: Theme.u(150)
				options: [
					{ value: "none", text: Tr.t("Nothing") },
					{ value: "accent", text: Tr.t("The accent") },
					{ value: "all", text: Tr.t("All the colors") }
				]
				value: Theme.values.wallpaperPalette ? "all" : Theme.values.wallpaperAccent ? "accent" : "none"
				onChosen: value => {
					Theme.set("wallpaperAccent", value !== "none");
					Theme.set("wallpaperPalette", value === "all");
				}
			}
		}

		// The language okaeri's own words are in.
		Card {
			width: parent.width

			Pick {
				holds: "language.name"
				words: "language translation russian english"
				text: Tr.t("Language")
				subtext: Tr.t("Of okaeri's own words")
				options: [
					{ value: "", text: Tr.t("The system's") },
					{ value: "en", text: "English" },
					{ value: "ru", text: "Русский" }
				]
				value: Settings.language.name
				onChosen: value => Settings.set("language", "name", value)
			}
		}
	}
}
