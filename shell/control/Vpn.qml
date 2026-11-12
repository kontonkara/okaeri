pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The VPNs NetworkManager has, WireGuard ones too, as nmcli says: { name, id,
// kind, on, busy }, those that are up first, looked at as the panel opens and
// every few seconds while it's open. A click takes one up or down. Without
// nmcli, or with none set up there, there's nothing here and no tile. What goes
// to Env.act leaves out names: it ends up in logs.
Singleton {
	id: vpn

	readonly property string tool: "nmcli"
	property var connections: []
	readonly property var up: connections.filter(connection => connection.on)
	// The one a switch takes up: the last that was up, or the first there is.
	property string last
	readonly property var preferred: connections.find(connection => connection.id === last) ?? connections[0] ?? null
	// What the last try said, if it failed, and for which.
	property string failure
	property string failedId

	// One line of nmcli's terse output, apart at the colons it didn't escape.
	function fields(line) {
		return line.replace(/\\:/g, "\u0000").split(":").map(field => field.replace(/\u0000/g, ":").replace(/\\\\/g, "\\"));
	}

	function read(text) {
		const found = text.split("\n").filter(line => line !== "").map(fields).filter(parts => parts[2] === "vpn" || parts[2] === "wireguard").map(parts => ({
			name: parts[0],
			id: parts[1],
			kind: parts[2] === "wireguard" ? "WireGuard" : "VPN",
			on: parts[3] === "activated",
			busy: parts[3] === "activating" || parts[3] === "deactivating"
		}));
		connections = found.sort((a, b) => b.on - a.on || a.name.localeCompare(b.name));
		const active = connections.find(connection => connection.on);
		if (active)
			last = active.id;
	}

	function look() {
		listing.running = true;
	}

	// What's asked of them and not begun, in turn: [{ id, wanted }].
	property var asked: []

	function set(connection, wanted) {
		failure = "";
		Env.act(`vpn ${wanted ? "up" : "down"}`, () => {
			asked = asked.concat([{ id: connection.id, wanted }]);
			next();
		});
	}

	// One at a time: nmcli says why only of its own.
	function next() {
		if (changing.running || asked.length === 0)
			return;
		const request = asked[0];
		asked = asked.slice(1);
		failedId = request.id;
		changing.command = [tool, "connection", request.wanted ? "up" : "down", "uuid", request.id];
		changing.running = true;
	}

	// The switch: all that's up goes down, or the preferred one comes up.
	function setEnabled(wanted) {
		if (!wanted)
			up.forEach(connection => set(connection, false));
		else if (preferred)
			set(preferred, true);
	}

	Component.onCompleted: look()

	Process {
		id: listing

		command: [vpn.tool, "-t", "-f", "NAME,UUID,TYPE,STATE", "connection", "show"]
		stdout: StdioCollector {
			onStreamFinished: vpn.read(text)
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
				vpn.failure = said.text.trim().split("\n").pop().replace(/^Error: /, "") || "Couldn't connect";
			vpn.look();
			vpn.next();
		}
	}

	Timer {
		interval: 3000
		running: Control.open
		repeat: true
		triggeredOnStart: true
		onTriggered: vpn.look()
	}
}
