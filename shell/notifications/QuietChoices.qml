import QtQuick
import qs
import qs.ui

// For how long `app` keeps quiet, as its quiet button asks: an hour, eight, or
// until it's let speak again.
Flow {
	id: choices

	required property string app
	property bool allowed: true

	visible: allowed && NotificationStore.quietAsked === app
	height: visible ? implicitHeight : 0
	topPadding: Theme.u(2)
	bottomPadding: Theme.u(6)
	spacing: Theme.u(6)

	Repeater {
		model: [
			{ text: "For an hour", span: 3600000 },
			{ text: "For 8 hours", span: 28800000 },
			{ text: "Until I say", span: 0 }
		]

		Button {
			required property var modelData

			height: Theme.u(26)
			activeFocusOnTab: false
			text: modelData.text
			onClicked: NotificationStore.quietFor(choices.app, modelData.span)
		}
	}
}
