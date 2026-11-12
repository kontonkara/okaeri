import QtQuick
import qs
import qs.services
import qs.ui

// While Caps Lock is on, its sign, and Num Lock's too if Settings.locks.show is
// "both": with neither there's nothing here.
Item {
	id: keys

	readonly property bool caps: Locks.ready && Locks.caps
	readonly property bool num: Locks.ready && Locks.num && Settings.locks.show === "both"
	readonly property bool wanted: caps || num

	implicitWidth: grid.implicitWidth
	implicitHeight: grid.implicitHeight
	visible: wanted

	// The tip covers it all, and among the signs it would be one of them.
	Grid {
		id: grid

		columns: Settings.barSide ? 1 : 1000
		padding: Theme.u(6)
		spacing: Theme.u(6)

		Icon {
			visible: keys.caps
			name: "capsLock"
			size: Theme.barIcon
		}

		Icon {
			visible: keys.num
			name: "numLock"
			size: Theme.barIcon
		}
	}

	Tip {
		text: [keys.caps ? "Caps Lock" : "", keys.num ? "Num Lock" : ""].filter(part => part !== "").join(" and ") + " on"
	}
}
