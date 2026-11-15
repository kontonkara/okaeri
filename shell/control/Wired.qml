pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.services

// The wired network, where the machine has a plug for one: whether it's up, and
// what nmcli says of it while its page is open, its address, its gateway and
// the like, as { text, value }. A click on its switch takes it up or down.
// Without a plug, or with no cable in it, there's no tile.
Singleton {
	id: wired

	readonly property string tool: "nmcli"
	// The first there is: one that's up, if any.
	readonly property var devices: Networking.devices.values.filter(device => device.type === DeviceType.Wired)
	readonly property var device: devices.find(device => device.connected) ?? devices[0] ?? null
	readonly property bool connected: !!device && !!device.connected
	readonly property string name: device?.name ?? ""
	// "100 (connected)" as nmcli has it, in its own words.
	property string state
	// With no cable in it, or before nmcli said, there's nothing to take up.
	readonly property bool plugged: connected || (state !== "" && !/unavailable|unmanaged/.test(state))
	property var details: []
	readonly property string summary: !device ? "" : connected ? ((device.linkSpeed ?? 0) > 0 ? `${device.linkSpeed} Mb/s` : "Connected") : plugged ? "Off" : "No cable"
	// What the last try said, if it failed.
	property string failure

	// What nmcli shows of the device, a line each as KEY:value.
	function read(text) {
		const found = {};
		text.split("\n").forEach(line => {
			const at = line.indexOf(":");
			if (at < 0)
				return;
			const key = line.slice(0, at).replace(/\[\d+\]$/, "");
			const value = line.slice(at + 1).replace(/\\:/g, ":");
			if (value !== "" && value !== "--")
				found[key] = (found[key] ?? []).concat([value]);
		});
		state = (found["GENERAL.STATE"] ?? [""])[0];
		const speed = (device?.linkSpeed ?? 0) > 0 ? [`${device.linkSpeed} Mb/s`] : [];
		details = [
			{ text: "Connection", value: found["GENERAL.CONNECTION"] },
			{ text: "Speed", value: speed },
			{ text: "Address", value: found["IP4.ADDRESS"] },
			{ text: "Gateway", value: found["IP4.GATEWAY"] },
			{ text: "DNS", value: found["IP4.DNS"] },
			{ text: "IPv6", value: found["IP6.ADDRESS"] },
			{ text: "Hardware", value: found["GENERAL.HWADDR"] }
		].filter(row => row.value && row.value.length > 0).map(row => ({ text: row.text, value: row.value.join(", ") }));
	}

	function look() {
		if (name !== "")
			showing.running = true;
	}

	function setEnabled(wanted) {
		if (name === "")
			return;
		failure = "";
		Env.act(`wired ${wanted ? "up" : "down"}`, () => {
			changing.command = [tool, "device", wanted ? "connect" : "disconnect", name];
			changing.running = true;
		});
	}

	onNameChanged: look()
	onConnectedChanged: look()

	Process {
		id: showing

		command: [wired.tool, "-t", "-f", "GENERAL.STATE,GENERAL.CONNECTION,GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS", "device", "show", wired.name]
		stdout: StdioCollector {
			onStreamFinished: wired.read(text)
		}
	}

	// What it says when it fails is why.
	Process {
		id: changing

		stderr: StdioCollector {
			id: said
		}
		onExited: code => {
			if (code !== 0)
				wired.failure = said.text.trim().split("\n").pop().replace(/^Error: /, "") || "Couldn't connect";
			wired.look();
		}
	}

	Timer {
		interval: 5000
		running: Control.open && wired.name !== ""
		repeat: true
		triggeredOnStart: true
		onTriggered: wired.look()
	}
}
