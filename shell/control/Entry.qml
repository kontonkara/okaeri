import QtQuick
import qs
import qs.ui

// A row of Rows, in the look of List's: what's put in it in front, `text` and
// `subtext`, in the error color when `failed`, a button when there's an
// `action`, and `below` under all that.
Item {
	id: entry

	required property var modelData
	required property int index

	readonly property var view: ListView.view
	property string text
	property string subtext
	property bool failed: false
	property bool pickable: true
	property string action
	property alias below: under.data
	default property alias front: front.data

	signal acted

	width: view.width
	height: line.height + under.height

	Item {
		id: line

		width: parent.width
		height: entry.view.rowHeight

		Rectangle {
			anchors.fill: parent
			radius: Math.max(0, Theme.cardRadius - Theme.u(4))
			color: pointer.containsMouse && entry.pickable ? Theme.hover : "transparent"

			Behavior on color {
				enabled: Theme.animate

				ColorAnimation {
					duration: 120
				}
			}
		}

		Item {
			id: front

			x: Theme.u(8)
			anchors.verticalCenter: parent.verticalCenter
			width: Theme.u(18)
			height: Theme.u(18)
		}

		Column {
			anchors.left: front.right
			anchors.leftMargin: Theme.u(14)
			anchors.right: button.visible ? button.left : parent.right
			anchors.rightMargin: Theme.u(8)
			anchors.verticalCenter: parent.verticalCenter

			// Anyone nearby picks the names: never markup, and one line.
			Text {
				width: parent.width
				text: entry.text
				textFormat: Text.PlainText
				maximumLineCount: 1
				color: Theme.colors.text
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}

			Text {
				width: parent.width
				text: entry.subtext
				color: entry.failed ? Theme.colors.error : Theme.colors.subtext
				elide: Text.ElideRight
				font.family: Theme.font
				font.pixelSize: Theme.fontSize - Theme.u(2)
			}
		}

		// The pointer has a highlight of its own: the list's goes with the
		// current row, and a new current row takes the keys from a field.
		MouseArea {
			id: pointer

			anchors.fill: parent
			hoverEnabled: true
			cursorShape: entry.pickable ? Qt.PointingHandCursor : Qt.ArrowCursor
			onClicked: entry.view.activate(entry.index)
		}

		Button {
			id: button

			anchors.right: parent.right
			anchors.rightMargin: Theme.u(5)
			anchors.verticalCenter: parent.verticalCenter
			height: Theme.u(28)
			visible: entry.action !== ""
			flat: true
			text: entry.action
			onClicked: entry.acted()
		}
	}

	Item {
		id: under

		y: line.height
		width: parent.width
		height: childrenRect.height
	}
}
