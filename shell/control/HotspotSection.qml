import QtQuick
import qs
import qs.ui

// The hotspot: on or off, and how a phone joins it, by its name and password or
// the code its camera reads. Those two are the settings', on the Control page,
// and take effect as it next goes up.
Section {
	id: section

	name: "hotspot"
	wanted: !!Wifi.device
	icon: "hotspot"
	title: Tr.t("Hotspot")
	summary: Hotspot.summary
	checked: Hotspot.on
	canSwitch: !Wifi.blocked && Wifi.hasTool
	onToggled: wanted => Hotspot.set(wanted)

	WifiShare {
		file: "share-hotspot.png"
		active: section.unfolded
		name: Hotspot.ssid
		key: Hotspot.password
		note: Hotspot.password === "" ? "Made up as it first goes on" : ""
	}

	Button {
		height: Theme.u(30)
		flat: true
		text: Tr.t("Change them in the settings")
		tip: Tr.t("On the Control page, a click on its tile there")
		onClicked: {
			Control.leave();
			Settings.pageWanted("Control");
		}
	}
}
