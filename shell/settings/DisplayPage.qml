import QtQuick
import qs
import qs.services
import qs.ui

// How the night light warms the screens and when: it's turned on and off in the
// control center.
Column {
	id: page

	readonly property var own: Settings.nightLight

	spacing: Math.round(Theme.u(10))

	component Field: Item {
		id: field

		required property string text
		property string subtext
		property alias value: input.text
		property string placeholder
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
			implicitWidth: Theme.u(120)
			implicitHeight: Theme.u(32)
			placeholder: field.placeholder
			onAccepted: {
				if (field.valid(text.trim()))
					field.kept(text.trim());
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

}
