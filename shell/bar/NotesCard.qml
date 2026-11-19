import QtQuick
import qs
import qs.services
import qs.ui

// What's to do, done ones after the rest: a new one by its field and Enter, a
// click on one's box ticks it off or back, its other button takes it away; and
// the note under them, kept as it's typed.
Column {
	id: card

	spacing: Theme.u(10)

	TextField {
		width: parent.width
		focus: true
		icon: "plus"
		placeholder: "Something to do"
		onAccepted: {
			Notes.add(text);
			text = "";
		}
	}

	Column {
		width: parent.width
		visible: Notes.todos.length > 0

		Repeater {
			model: Notes.todos

			Item {
				id: row

				required property var modelData
				required property int index

				width: parent.width
				height: Theme.u(32)

				Button {
					id: tick

					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					height: Theme.u(28)
					flat: true
					icon: row.modelData.done ? "check" : "box"
					iconSize: Theme.u(16)
					ink: row.modelData.done ? Theme.colors.accent : Theme.colors.subtext
					tip: row.modelData.done ? "Not done after all" : "Done"
					onClicked: Notes.toggle(row.index)
				}

				Text {
					anchors.left: tick.right
					anchors.leftMargin: Theme.u(4)
					anchors.right: away.left
					anchors.verticalCenter: parent.verticalCenter
					text: row.modelData.text
					textFormat: Text.PlainText
					elide: Text.ElideRight
					color: row.modelData.done ? Theme.colors.subtext : Theme.colors.text
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
					font.strikeout: row.modelData.done
				}

				Button {
					id: away

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					height: Theme.u(28)
					flat: true
					icon: "trash"
					iconSize: Theme.u(16)
					tip: "Away with it"
					onClicked: Notes.remove(row.index)
				}
			}
		}
	}

	Button {
		height: Theme.u(30)
		visible: Notes.todos.some(todo => todo.done)
		flat: true
		icon: "trash"
		text: "Clear what's done"
		onClicked: Notes.clearDone()
	}

	// The note: as tall as it is, up to a point, and then it scrolls.
	Rectangle {
		width: parent.width
		height: Math.max(Theme.u(90), Math.min(Theme.u(260), writing.contentHeight + Theme.u(20)))
		radius: Math.max(0, Theme.cardRadius - Theme.u(4))
		color: Theme.hover

		Flickable {
			id: page

			anchors.fill: parent
			anchors.margins: Theme.u(10)
			contentHeight: writing.contentHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			TextEdit {
				id: writing

				width: page.width
				text: Notes.note
				wrapMode: TextEdit.Wrap
				selectByMouse: true
				color: Theme.colors.text
				selectionColor: Theme.colors.accent
				selectedTextColor: Theme.colors.background
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				onTextChanged: Notes.write(text)
				// The line typed on stays in sight.
				onCursorRectangleChanged: {
					if (cursorRectangle.y < page.contentY)
						page.contentY = cursorRectangle.y;
					else if (cursorRectangle.y + cursorRectangle.height > page.contentY + page.height)
						page.contentY = cursorRectangle.y + cursorRectangle.height - page.height;
				}
			}

			Text {
				visible: writing.text === ""
				text: "A note"
				color: Theme.colors.subtext
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
			}
		}
	}
}
