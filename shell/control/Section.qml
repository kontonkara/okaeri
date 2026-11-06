import QtQuick
import qs
import qs.ui

// A card that folds, unless `folds` is off: `icon`, `title` and `summary`, a
// switch that says toggled(wanted), unless `switches` is off, and under them
// what's put in it. One section of the panel is unfolded at a time, the one
// Control.unfolded names, and only while on.
Card {
	id: section

	required property string name
	property string icon
	property string title
	property string summary
	property bool checked: false
	property bool canSwitch: true
	property bool switches: true
	property bool folds: true
	property bool takesWheel: false
	readonly property bool unfolded: checked && Control.unfolded === name
	readonly property real foldedHeight: header.height + padding * 2
	default property alias folded: rows.data

	signal toggled(bool wanted)
	// Notches of the wheel, with `takesWheel`.
	signal scrolled(int steps)

	width: parent.width
	padding: Theme.u(6)

	Column {
		width: parent.width

		Item {
			id: header

			width: parent.width
			height: Theme.u(44)

			Button {
				id: fold

				anchors.fill: parent
				radius: Math.max(0, Theme.cardRadius - Theme.u(4))
				flat: true
				takesWheel: section.takesWheel
				onScrolled: steps => section.scrolled(steps)
				onClicked: {
					if (section.checked && section.folds)
						Control.unfolded = section.unfolded ? "" : section.name;
				}

				Item {
					width: fold.width
					height: fold.height

					Icon {
						id: glyph

						x: Theme.u(8)
						anchors.verticalCenter: parent.verticalCenter
						name: section.icon
						color: section.checked ? Theme.colors.text : Theme.colors.subtext
					}

					Column {
						anchors.left: glyph.right
						anchors.leftMargin: Theme.u(14)
						anchors.right: chevron.left
						anchors.rightMargin: Theme.u(8)
						anchors.verticalCenter: parent.verticalCenter

						Text {
							width: parent.width
							text: section.title
							color: Theme.colors.text
							elide: Text.ElideRight
							font.family: Theme.font
							font.pixelSize: Theme.fontSize
							font.weight: Theme.fontWeight
						}

						// It can be a name, which anyone nearby picks.
						Text {
							width: parent.width
							text: section.summary
							textFormat: Text.PlainText
							maximumLineCount: 1
							color: Theme.colors.subtext
							elide: Text.ElideRight
							font.family: Theme.font
							font.pixelSize: Theme.fontSize - Theme.u(2)
						}
					}

					Icon {
						id: chevron

						anchors.right: parent.right
						anchors.rightMargin: Theme.u(section.switches ? 58 : 14)
						anchors.verticalCenter: parent.verticalCenter
						visible: section.checked && section.folds
						name: "chevron"
						size: Theme.u(16)
						color: Theme.colors.subtext
						rotation: section.unfolded ? 90 : 0

						Behavior on rotation {
							enabled: Theme.animate

							NumberAnimation {
								duration: 160
								easing.type: Easing.OutCubic
							}
						}
					}
				}
			}

			Toggle {
				anchors.right: parent.right
				anchors.rightMargin: Theme.u(8)
				anchors.verticalCenter: parent.verticalCenter
				visible: section.switches
				enabled: section.canSwitch
				checked: section.checked
				onToggled: wanted => section.toggled(wanted)
			}
		}

		Item {
			width: parent.width
			height: section.unfolded ? rows.height : 0
			visible: height > 0
			clip: true

			Behavior on height {
				enabled: Theme.animate

				NumberAnimation {
					duration: 160
					easing.type: Easing.OutCubic
				}
			}

			Column {
				id: rows

				width: parent.width
			}
		}
	}
}
