pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs

// The power profile, power-profiles-daemon's, and how the laptop's battery is doing.
Singleton {
	id: power

	readonly property int profile: PowerProfiles.profile
	readonly property var choices: [
		{ profile: PowerProfile.PowerSaver, text: "Saver" },
		{ profile: PowerProfile.Balanced, text: "Balanced" }
	].concat(PowerProfiles.hasPerformanceProfile ? [{ profile: PowerProfile.Performance, text: "Performance" }] : [])

	readonly property int at: choices.findIndex(choice => choice.profile === profile)
	readonly property string profileName: choices[at]?.text ?? ""
	// Why the profile isn't all it says, or what app holds it: "" for neither.
	readonly property string profileWhy: {
		const reason = PowerProfiles.degradationReason;
		if (profile === PowerProfile.Performance && reason === PerformanceDegradationReason.HighTemperature)
			return "Held back, it's hot";
		if (profile === PowerProfile.Performance && reason === PerformanceDegradationReason.LapDetected)
			return "Held back, it's on a lap";
		const holds = PowerProfiles.holds ?? [];
		for (let at = 0; at < holds.length; at++) {
			if (holds[at].profile === profile && holds[at].applicationId)
				return `Held by ${holds[at].applicationId}`;
		}
		return "";
	}
	// The profile there was before a low battery took the saver, -1 with none to go
	// back to.
	property int beforeSaver: -1

	readonly property var battery: UPower.devices.values.find(device => device.isLaptopBattery) ?? null
	readonly property string batteryLine: battery ? describe(battery.state, battery.state === UPowerDeviceState.Charging ? battery.timeToFull : battery.timeToEmpty, battery.changeRate, battery.healthSupported ? battery.healthPercentage : 0) : ""
	// What's left of it in percent, whether the machine runs on it, and whether that's
	// getting too little.
	readonly property int charge: Math.round(UPower.displayDevice.percentage * 100)
	readonly property bool draining: UPower.onBattery && UPower.displayDevice.isLaptopBattery
	readonly property bool low: draining && charge <= Settings.battery.warning
	readonly property bool present: UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
	// What else has a battery, a mouse or a headset: { name, percent }.
	property var others: UPower.devices.values.filter(device => !device.isLaptopBattery && device.isPresent && device.type !== UPowerDeviceType.LinePower && device.percentage > 0).map(device => ({
		name: device.model || UPowerDeviceType.toString(device.type),
		percent: Math.round(device.percentage * 100)
	}))
	readonly property string othersLine: others.map(other => `${other.name} ${other.percent}%`).join(" · ")
	// Until it's empty, or full while it charges, in seconds, 0 if that isn't known.
	readonly property real timeLeft: draining ? UPower.displayDevice.timeToEmpty : UPower.displayDevice.timeToFull
	// The charge over the last day, one each quarter of an hour, the newest last,
	// as UPower keeps it: read with lookHistory(), as the battery's card opens.
	property var history: []
	readonly property int historyHours: 24
	readonly property string bus: "busctl"

	// With Settings.battery.saver a low battery has the saver profile, and what it
	// had before once it charges.
	onLowChanged: {
		if (low && Settings.battery.saver && profile !== PowerProfile.PowerSaver) {
			beforeSaver = profile;
			set(PowerProfile.PowerSaver);
		} else if (!low && beforeSaver >= 0) {
			set(beforeSaver);
			beforeSaver = -1;
		}
	}

	function lookHistory() {
		if (battery)
			historyLook.running = true;
	}

	// From what busctl prints of GetHistory, the newest first, each [time, percent,
	// state]: a state of 0 is a time nothing is known of, as the machine was off.
	// Each quarter has the last charge known by its end.
	function readHistory(text, now) {
		let known = [];
		try {
			known = JSON.parse(text).data[0].filter(one => one[2] !== 0).sort((a, b) => a[0] - b[0]);
		} catch (error) {
			history = [];
			return;
		}
		const quarters = historyHours * 4;
		const values = [];
		let at = 0;
		let last = -1;
		for (let quarter = quarters - 1; quarter >= 0; quarter--) {
			const end = now - quarter * 900;
			while (at < known.length && known[at][0] <= end)
				last = known[at++][1];
			if (last >= 0)
				values.push(last);
		}
		// And now, as it is.
		if (values.length > 0)
			values[values.length - 1] = charge;
		history = values;
	}

	// Along the profiles, round to the first again.
	function turn(steps) {
		const count = choices.length;
		if (count > 0)
			set(choices[((at + steps) % count + count) % count].profile);
	}

	function set(choice) {
		Env.act(`power profile ${PowerProfile.toString(choice)}`, () => PowerProfiles.profile = choice);
	}

	// `seconds` as hours and minutes.
	function span(seconds) {
		const minutes = Math.round(seconds / 60);
		const hours = Math.floor(minutes / 60);
		return hours > 0 ? `${hours} h ${minutes % 60} min` : `${minutes} min`;
	}

	// `seconds` as hours and minutes, for little room: 2:05.
	function clock(seconds) {
		const minutes = Math.round(seconds / 60);
		return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}`;
	}

	// What's going on, how fast, and how worn it is, each if it's known.
	function describe(state, seconds, watts, health) {
		const rate = watts > 0 ? `${watts.toFixed(1)} W` : "";
		const parts = [];
		if (state === UPowerDeviceState.Discharging)
			parts.push(seconds > 0 ? `${span(seconds)} left` : "On battery", rate);
		else if (state === UPowerDeviceState.Charging)
			parts.push(seconds > 0 ? `${span(seconds)} to full` : "Charging", rate);
		else if (state === UPowerDeviceState.FullyCharged)
			parts.push("Fully charged");
		else
			parts.push("Not charging");
		if (health > 0)
			parts.push(`health ${Math.round(health)}%`);
		return parts.filter(part => part !== "").join(" · ");
	}

	Process {
		id: historyLook

		// Its object, by its name in /sys as UPower makes it. A week back: it keeps
		// a charge as it changes, and one that held all day is from before it.
		command: [power.bus, "--json=short", "call", "--system", "org.freedesktop.UPower", `/org/freedesktop/UPower/devices/battery_${(power.battery?.nativePath ?? "").replace(/[^A-Za-z0-9_]/g, "_")}`, "org.freedesktop.UPower.Device", "GetHistory", "suu", "charge", "604800", "2000"]

		stdout: StdioCollector {
			onStreamFinished: power.readHistory(text, Date.now() / 1000)
		}
	}
}
