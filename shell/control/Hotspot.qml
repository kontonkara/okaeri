pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.services

// A hotspot on the Wi-Fi device, by NetworkManager, for phones and the like to
// get online through this machine: on while that device is an access point,
// which NetworkManager says as it happens. It goes by Settings.hotspot's name,
// or the machine's, and its password, which where there's none is made up once
// and kept there. A switch takes it up or down by nmcli, and what that said last
// when it failed is `failure`. What goes to Env.act leaves out the name and the
// password: it ends up in logs.
Singleton {
	id: hotspot

	// NetworkManager's name for it: a connection of okaeri's own, made anew each
	// time it goes up, so that none is left over with another name in it.
	readonly property string connection: "okaeri-hotspot"
	readonly property bool on: !!Wifi.device && Wifi.device.mode === WifiDeviceMode.AccessPoint
	// The machine's name, as uname has it.
	property string host
	readonly property string ssid: Settings.hotspot.name || host || "okaeri"
	readonly property string password: Settings.hotspot.password
	readonly property bool busy: changing.running || making.running
	// Which way it's going, while it's busy.
	property bool going: false
	property string failure
	readonly property string summary: {
		if (!Wifi.hasTool)
			return "It needs nmcli, which isn't here";
		if (busy)
			return going ? "Starting..." : "Stopping...";
		return failure || (on ? ssid : "Off");
	}

	function set(wanted) {
		if (busy || wanted === on || !Wifi.hasTool)
			return;
		failure = "";
		going = wanted;
		if (!wanted)
			Env.act("hotspot off", () => run([Wifi.tool, "connection", "down", "id", connection]));
		else if (password === "")
			making.running = true;
		else
			begin(password);
	}

	// Up with `key`: the last one of its own goes first, and nmcli makes it
	// anew.
	function begin(key) {
		const device = Wifi.device?.name ?? "";
		Env.act("hotspot on", () => run(["sh", "-c", 'tool=$1 name=$2; shift 2; "$tool" connection delete id "$name" >/dev/null 2>&1; exec "$tool" device wifi hotspot con-name "$name" "$@"', "sh", Wifi.tool, connection].concat(device ? ["ifname", device] : [], ["ssid", ssid, "password", key])));
	}

	function run(command) {
		changing.command = command;
		changing.running = true;
	}

	// What it says when it fails is why.
	Process {
		id: changing

		stderr: StdioCollector {
			id: said
		}
		onExited: code => {
			if (code !== 0)
				hotspot.failure = said.text.trim().split("\n").pop().replace(/^Error: /, "") || (hotspot.going ? "Couldn't start it" : "Couldn't stop it");
		}
	}

	// Twelve letters and digits from the kernel's randomness, none that reads
	// like another.
	Process {
		id: making

		command: ["sh", "-c", "LC_ALL=C tr -dc abcdefghjkmnpqrstuvwxyz23456789 </dev/urandom | head -c 12"]
		stdout: StdioCollector {
			onStreamFinished: {
				const key = text.trim();
				if (key.length < 12) {
					hotspot.failure = "Couldn't make up a password";
					return;
				}
				Settings.set("hotspot", "password", key);
				hotspot.begin(key);
			}
		}
	}

	Process {
		running: true
		command: ["uname", "-n"]
		stdout: StdioCollector {
			onStreamFinished: hotspot.host = text.trim()
		}
	}
}
