pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Airplane mode: Wi-Fi and Bluetooth off, and back as they were when it ends.
// What they were is kept in a file, so that it ends right after a restart too;
// one of them turned on by hand meanwhile ends it, with the other left alone.
Singleton {
	id: airplane

	// What was on as it began: { wifi, bluetooth }, null while it's off.
	property var before: null
	readonly property bool on: before !== null
	readonly property bool possible: !!Wifi.device || !!Bt.adapter

	function set(wanted) {
		if (wanted === on)
			return;
		if (wanted) {
			keep({ wifi: !!Wifi.device && Wifi.enabled, bluetooth: Bt.enabled });
			if (before.wifi)
				Wifi.setEnabled(false);
			if (before.bluetooth)
				Bt.setEnabled(false);
		} else {
			const was = before;
			keep(null);
			if (was.wifi)
				Wifi.setEnabled(true);
			if (was.bluetooth)
				Bt.setEnabled(true);
		}
	}

	function keep(state) {
		before = state;
		file.setText(state ? JSON.stringify(state) + "\n" : "");
	}

	// Turned on by hand: it's over, and nothing else changes.
	function interrupted() {
		if (on)
			keep(null);
	}

	Connections {
		target: Wifi

		function onEnabledChanged() {
			if (Wifi.enabled)
				airplane.interrupted();
		}
	}

	Connections {
		target: Bt

		function onEnabledChanged() {
			if (Bt.enabled)
				airplane.interrupted();
		}
	}

	FileView {
		id: file

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/airplane.json`
		blockLoading: true
		printErrors: false
		onLoaded: {
			const text = file.text().trim();
			const state = text ? Theme.parse(text, path) : {};
			airplane.before = state.wifi !== undefined ? state : null;
		}
	}
}
