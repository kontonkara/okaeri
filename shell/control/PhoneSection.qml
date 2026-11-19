import QtQuick
import qs
import qs.services
import qs.ui

// The phones in reach through KDE Connect, and what's done to one: rung to be
// found, pinged, or sent what's on the clipboard.
Section {
	id: section

	// Each phone's three, its name on them where there's more than one.
	readonly property var doings: Phone.devices.reduce((all, device) => {
		const many = Phone.devices.length > 1;
		return all.concat([
			{ device, what: "ring", text: many ? Tr.f("Ring %1", device.name) : Tr.t("Ring it"), subtext: Tr.t("To find it, though it's quiet"), icon: "bell" },
			{ device, what: "ping", text: many ? Tr.f("Ping %1", device.name) : Tr.t("Ping it"), subtext: Tr.t("It says so"), icon: "phone" },
			{ device, what: "send-clipboard", text: many ? Tr.f("Send %1 what's copied", device.name) : Tr.t("Send it what's copied"), subtext: Tr.t("To its clipboard"), icon: "clipboard" }
		]);
	}, [])

	name: "phone"
	wanted: Phone.devices.length > 0
	icon: "phone"
	title: Phone.devices.length === 1 ? Phone.devices[0].name : Tr.t("Phones")
	summary: Phone.devices.map(device => device.charge >= 0 ? `${device.charge}%${device.charging ? ", charging" : ""}` : "In reach").join(" · ")
	switches: false

	Rows {
		values: section.doings
		room: section.roomInside
		empty: Tr.t("None in reach")
		onActivated: (index, doing) => Phone.ask(doing.device, doing.what)

		delegate: Entry {
			id: row

			// One that went is null here for a moment, as the row goes.
			readonly property var doing: modelData ?? ({})

			text: doing.text ?? ""
			subtext: doing.subtext ?? ""

			Icon {
				name: row.doing.icon ?? "phone"
				color: Theme.colors.text
			}
		}
	}
}
