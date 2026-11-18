import QtQuick
import qs
import qs.services
import qs.ui

// The drives plugged in: a click on one opens it, mounted first where it isn't,
// and the button beside one that can be ejected makes it safe to pull out, a
// second click sure of that.
Section {
	id: section

	name: "drives"
	wanted: Drives.list.length > 0
	icon: "drive"
	title: "Drives"
	summary: Drives.list.length === 1 ? Drives.nameOf(Drives.list[0]) : `${Drives.list.length} plugged in`
	switches: false

	Rows {
		values: Drives.list
		room: section.roomInside
		empty: "Nothing plugged in"
		onActivated: (index, drive) => Drives.open(drive)

		delegate: Entry {
			id: row

			// One that went is null here for a moment, as the row goes.
			readonly property var drive: modelData ?? ({ device: "", size: 0 })
			readonly property bool wrong: Drives.failure !== "" && Drives.failedOn === drive.object

			text: Drives.nameOf(drive)
			subtext: wrong ? Drives.failure : [Drives.sizeOf(drive.size), drive.mount ? drive.mount.replace(/^.*\//, "In ") : "Not mounted"].join(" · ")
			failed: wrong
			action: drive.ejectable ? "Eject" : drive.mount ? "Unmount" : ""
			// Pulled out after that, so a second click, soon after the first.
			risky: drive.ejectable
			onActed: drive.ejectable ? Drives.eject(drive) : Drives.unmount(drive)

			Icon {
				name: "drive"
				color: row.drive.mount ? Theme.colors.text : Theme.colors.subtext
			}
		}
	}
}
