import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The screens: how each is driven, scaled, turned and placed. How the night
// light warms them and when, which is turned on and off in the control center,
// whether external monitors' brightness is there too, how the screen is
// recorded, and where screenshots go.
Flickable {
	id: page

	readonly property var own: Settings.nightLight

	contentHeight: stack.height
	clip: true
	boundsBehavior: Flickable.StopAtBounds

	Glide {
		view: page
	}

	component Field: Item {
		id: field

		required property string text
		property string holds
		property string words
		property string subtext
		property alias value: input.text
		property string placeholder
		// For more than a number or a time.
		property bool wide: false
		// Whether what's typed is one to keep.
		property var valid: value => true

		signal kept(string value)

		width: parent.width
		height: Theme.u(40)

		Column {
			anchors.left: parent.left
			anchors.right: input.left
			anchors.rightMargin: Theme.u(12)
			anchors.verticalCenter: parent.verticalCenter

			Text {
				width: parent.width
				text: field.text
				color: Theme.colors.text
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}

			Text {
				width: parent.width
				visible: text !== ""
				text: field.subtext
				color: Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}
		}

		TextField {
			id: input

			objectName: "field"
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			implicitWidth: Theme.u(field.wide ? 220 : 120)
			implicitHeight: Theme.u(32)
			placeholder: field.placeholder
			keeps: true
			wrong: !field.valid(text.trim())
			onAccepted: {
				if (field.valid(text.trim()))
					field.kept(text.trim());
			}
		}

		Mark {
			holds: field.holds
		}
	}

	Column {
		id: stack

		width: parent.width
		spacing: Math.round(Theme.u(10))

		// The screens niri has: how each is driven, how large what's on it is, how
		// it's turned and where it is beside the others. What can leave one dark is
		// tried out, and goes back by itself unless it's kept.
		Card {
			width: parent.width
			title: "Screens"
			visible: Object.keys(Niri.outputs).length > 0

			Item {
				width: parent.width
				height: Theme.u(40)
				visible: !!Screens.trial

				Text {
					anchors.left: parent.left
					anchors.right: answers.left
					anchors.rightMargin: Theme.u(12)
					anchors.verticalCenter: parent.verticalCenter
					text: `Keep this? It goes back in ${Screens.left} s`
					color: Theme.colors.text
					elide: Text.ElideRight
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
				}

				Row {
					id: answers

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: Theme.u(6)

					Button {
						objectName: "back"
						height: Theme.u(30)
						flat: true
						text: "Back"
						onClicked: Screens.dropTrial()
					}

					Button {
						objectName: "keep"
						height: Theme.u(30)
						filled: true
						text: "Keep"
						onClicked: Screens.keepTrial()
					}
				}
			}

			Repeater {
				model: Object.keys(Niri.outputs).sort()

				Column {
					id: screen

					required property string modelData
					readonly property var output: Niri.outputs[modelData] ?? { modes: [], mode: -1, vrr: {}, scale: 1, transform: "Normal" }
					readonly property bool lit: output.mode >= 0
					// The others that are on, to be beside.
					readonly property var others: Object.keys(Niri.outputs).filter(name => name !== modelData && Niri.outputs[name].mode >= 0)
					readonly property var scales: [0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3].concat([0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3].includes(output.scale) ? [] : [output.scale]).sort((a, b) => a - b)

					// Where it'd be beside `other`, on `side` of it.
					function placed(other, side) {
						const there = Niri.outputs[other];
						return side === "right" ? { x: there.x + there.width, y: there.y }
							: side === "left" ? { x: there.x - output.width, y: there.y }
							: side === "above" ? { x: there.x, y: there.y - output.height }
							: { x: there.x, y: there.y + there.height };
					}

					width: parent.width

					Text {
						width: parent.width
						topPadding: Theme.u(4)
						bottomPadding: Theme.u(4)
						text: [screen.modelData, [screen.output.make, screen.output.model].filter(part => !!part).join(" ")].filter(part => !!part).join(" · ")
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: Theme.colors.subtext
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(2)
					}

					Pick {
						text: "Resolution"
						visible: screen.lit
						valueWidth: Theme.u(190)
						options: screen.output.modes.map(mode => ({ value: `${mode.width}x${mode.height}@${mode.rate.toFixed(3)}`, text: `${mode.width}×${mode.height} · ${Math.round(mode.rate)} Hz` }))
						value: Screens.now(screen.output, "mode")
						onChosen: value => Screens.tryOut(screen.modelData, "mode", value)
					}

					Pick {
						text: "Scale"
						subtext: "How large what's on it is"
						visible: screen.lit
						valueWidth: Theme.u(190)
						options: screen.scales.map(scale => ({ value: scale, text: `${Math.round(scale * 100)}%` }))
						value: screen.output.scale
						onChosen: value => Screens.tryOut(screen.modelData, "scale", value)
					}

					Pick {
						text: "Turned"
						visible: screen.lit
						valueWidth: Theme.u(190)
						options: [
							{ value: "normal", text: "Not turned" },
							{ value: "90", text: "A quarter left" },
							{ value: "180", text: "Upside down" },
							{ value: "270", text: "A quarter right" }
						]
						value: Screens.now(screen.output, "transform")
						onChosen: value => Screens.tryOut(screen.modelData, "transform", value)
					}

					Setting {
						text: "Adaptive sync"
						subtext: "Its refresh keeps pace with what's drawn"
						visible: screen.lit && !!screen.output.vrr.supported
						checked: !!screen.output.vrr.on
						onToggled: wanted => Screens.set(screen.modelData, "vrr", wanted)
					}

					Pick {
						text: "Where it is"
						visible: screen.lit && screen.others.length > 0
						valueWidth: Theme.u(190)
						options: [{ value: "", text: "Where it was put" }].concat(...screen.others.map(other => [
								{ value: `left:${other}`, text: `Left of ${other}` },
								{ value: `right:${other}`, text: `Right of ${other}` },
								{ value: `above:${other}`, text: `Above ${other}` },
								{ value: `below:${other}`, text: `Below ${other}` }
							]))
						value: {
							for (const other of screen.others) {
								for (const side of ["left", "right", "above", "below"]) {
									const at = screen.placed(other, side);
									if (at.x === screen.output.x && at.y === screen.output.y)
										return `${side}:${other}`;
								}
							}
							return "";
						}
						onChosen: value => {
							if (value)
								Screens.set(screen.modelData, "position", screen.placed(value.split(":")[1], value.split(":")[0]));
						}
					}

					Setting {
						text: "On"
						subtext: screen.lit ? "With the others on" : "Off for now"
						visible: screen.others.length > 0 || !screen.lit
						checked: screen.lit
						onToggled: wanted => Screens.tryOut(screen.modelData, "on", wanted)
					}
				}
			}
		}

		Card {
			width: parent.width
			title: "Night light"

			Text {
				width: parent.width
				visible: !NightLight.available
				wrapMode: Text.WordWrap
				text: "It needs wlsunset, which isn't here."
				color: Theme.colors.error
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Pick {
				holds: "nightLight.mode"
				words: "blue light redshift gammastep warm"
				text: "When"
				subtext: "Once it's on, in the control center"
				options: [
					{ value: "always", text: "All the time" },
					{ value: "schedule", text: "From, until" },
					{ value: "sun", text: "By the sun" }
				]
				value: page.own.mode
				onChosen: value => Settings.set("nightLight", "mode", value)
			}

			Choice {
				holds: "nightLight.temperature"
				text: "How warm"
				subtext: "Lower is warmer; daylight is 6500 K"
				values: [2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000]
				value: page.own.temperature
				unit: " K"
				onChosen: value => Settings.set("nightLight", "temperature", value)
			}

			Field {
				visible: page.own.mode === "schedule"
				holds: "nightLight.from"
				text: "From"
				subtext: "As 24-hour time"
				placeholder: "20:00"
				value: page.own.from
				valid: value => /^([01]?\d|2[0-3]):[0-5]\d$/.test(value)
				onKept: value => Settings.set("nightLight", "from", value)
			}

			Field {
				visible: page.own.mode === "schedule"
				holds: "nightLight.until"
				text: "Until"
				subtext: "As 24-hour time"
				placeholder: "07:00"
				value: page.own.until
				valid: value => /^([01]?\d|2[0-3]):[0-5]\d$/.test(value)
				onKept: value => Settings.set("nightLight", "until", value)
			}

			Field {
				visible: page.own.mode === "sun"
				holds: "nightLight.latitude"
				text: "Latitude"
				subtext: "North is above 0"
				placeholder: "52.5"
				value: String(page.own.latitude)
				valid: value => value !== "" && !isNaN(Number(value)) && Math.abs(Number(value)) <= 90
				onKept: value => Settings.set("nightLight", "latitude", Number(value))
			}

			Field {
				visible: page.own.mode === "sun"
				holds: "nightLight.longitude"
				text: "Longitude"
				subtext: "East is above 0"
				placeholder: "13.4"
				value: String(page.own.longitude)
				valid: value => value !== "" && !isNaN(Number(value)) && Math.abs(Number(value)) <= 180
				onKept: value => Settings.set("nightLight", "longitude", Number(value))
			}
		}

		Card {
			width: parent.width
			title: "External monitors"

			Setting {
				holds: "display.ddc"
				text: "Their brightness"
				subtext: Ddc.available ? "In the control center, by DDC/CI: it needs /dev/i2c-* to be yours" : "It needs ddcutil, which isn't here"
				enabled: Ddc.available
				checked: Settings.display.ddc
				onToggled: wanted => Settings.set("display", "ddc", wanted)
			}
		}

		Card {
			width: parent.width
			title: "Recording the screen"

			Text {
				width: parent.width
				visible: !Recorder.available
				wrapMode: Text.WordWrap
				text: "It needs wf-recorder, which isn't here."
				color: Theme.colors.error
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}

			Pick {
				holds: "recording.area"
				text: "What's recorded"
				subtext: Recorder.picks ? "Started in the control center, or by `okaeri record toggle`" : "A part of it needs slurp, which isn't here"
				options: [
					{ value: "screen", text: "The screen" },
					{ value: "region", text: "A part of it" }
				]
				value: Settings.recording.area
				onChosen: value => Settings.set("recording", "area", value)
			}

			Pick {
				holds: "recording.audio"
				text: "With the sound of"
				options: [
					{ value: "none", text: "Nothing" },
					{ value: "system", text: "What plays" },
					{ value: "mic", text: "The mic" }
				]
				value: Settings.recording.audio
				onChosen: value => Settings.set("recording", "audio", value)
			}

			Field {
				holds: "recording.folder"
				text: "Where the videos go"
				subtext: "A folder: empty is Videos"
				placeholder: "~/Videos"
				wide: true
				value: Settings.recording.folder
				onKept: value => Settings.set("recording", "folder", value.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
			}
		}

		// Where screenshots go, and how long a screen or a window waits for one.
		Card {
			width: parent.width
			title: "Screenshots"

			Field {
				holds: "screenshots.folder"
				words: "screenshot capture print"
				text: "Where they go"
				subtext: "Empty for where niri's config says"
				placeholder: "~/Pictures/Screenshots"
				wide: true
				value: Settings.screenshots.folder
				onKept: value => Settings.set("screenshots", "folder", value.trim())
			}

			Choice {
				holds: "screenshots.delay"
				text: "Of the screen or a window, wait"
				subtext: "From the control center and the launcher"
				values: [0, 3, 5, 10]
				none: "Not at all"
				value: Settings.screenshots.delay
				onChosen: value => Settings.set("screenshots", "delay", value)
			}

			Setting {
				holds: "screenshots.pointer"
				text: "With the pointer"
				checked: Settings.screenshots.pointer
				onToggled: wanted => Settings.set("screenshots", "pointer", wanted)
			}

			Field {
				holds: "screenshots.editor"
				words: "screenshot annotate draw satty swappy"
				text: "Edit with"
				subtext: Screenshots.editor ? `Empty for ${Screenshots.editor}, found here` : "A command the picture goes to the end of"
				placeholder: Screenshots.editor || "satty --filename"
				wide: true
				value: Settings.screenshots.editor
				onKept: value => Settings.set("screenshots", "editor", value.trim())
			}

			Field {
				holds: "screenshots.languages"
				words: "screenshot ocr text recognize tesseract"
				text: "The text in them is in"
				subtext: Screenshots.reads ? "Tesseract's languages, as eng+rus" : "It takes tesseract, with its languages"
				placeholder: "eng"
				value: Settings.screenshots.languages
				onKept: value => Settings.set("screenshots", "languages", value.trim() || "eng")
			}
		}
	}
}
