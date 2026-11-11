import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// How the night light warms the screens and when, which is turned on and off in
// the control center, whether external monitors' brightness is there too, and
// how the screen is recorded.
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

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			implicitWidth: Theme.u(field.wide ? 220 : 120)
			implicitHeight: Theme.u(32)
			placeholder: field.placeholder
			onAccepted: {
				if (field.valid(text.trim()))
					field.kept(text.trim());
			}
		}
	}

	Column {
		id: stack

		width: parent.width
		spacing: Math.round(Theme.u(10))

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
				text: "How warm"
				subtext: "Lower is warmer; daylight is 6500 K"
				values: [2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000]
				value: page.own.temperature
				unit: " K"
				onChosen: value => Settings.set("nightLight", "temperature", value)
			}

			Field {
				visible: page.own.mode === "schedule"
				text: "From"
				subtext: "As 24-hour time, Enter to keep"
				placeholder: "20:00"
				value: page.own.from
				valid: value => /^([01]?\d|2[0-3]):[0-5]\d$/.test(value)
				onKept: value => Settings.set("nightLight", "from", value)
			}

			Field {
				visible: page.own.mode === "schedule"
				text: "Until"
				subtext: "As 24-hour time, Enter to keep"
				placeholder: "07:00"
				value: page.own.until
				valid: value => /^([01]?\d|2[0-3]):[0-5]\d$/.test(value)
				onKept: value => Settings.set("nightLight", "until", value)
			}

			Field {
				visible: page.own.mode === "sun"
				text: "Latitude"
				subtext: "North is above 0, Enter to keep"
				placeholder: "52.5"
				value: String(page.own.latitude)
				valid: value => value !== "" && !isNaN(Number(value)) && Math.abs(Number(value)) <= 90
				onKept: value => Settings.set("nightLight", "latitude", Number(value))
			}

			Field {
				visible: page.own.mode === "sun"
				text: "Longitude"
				subtext: "East is above 0, Enter to keep"
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
				text: "Where the videos go"
				subtext: "A folder, Enter to keep: empty is Videos"
				placeholder: "~/Videos"
				wide: true
				value: Settings.recording.folder
				onKept: value => Settings.set("recording", "folder", value.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))
			}
		}
	}
}
