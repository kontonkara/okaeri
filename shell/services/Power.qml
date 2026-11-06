pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The power profile, power-profiles-daemon's, and how the laptop's battery is doing.
Singleton {
	id: power

	readonly property int profile: PowerProfiles.profile
	readonly property var choices: [
		{ profile: PowerProfile.PowerSaver, text: "Saver" },
		{ profile: PowerProfile.Balanced, text: "Balanced" }
	].concat(PowerProfiles.hasPerformanceProfile ? [{ profile: PowerProfile.Performance, text: "Performance" }] : [])

	readonly property var battery: UPower.devices.values.find(device => device.isLaptopBattery) ?? null
	readonly property string batteryLine: battery ? describe(battery.state, battery.state === UPowerDeviceState.Charging ? battery.timeToFull : battery.timeToEmpty, battery.changeRate, battery.healthSupported ? battery.healthPercentage : 0) : ""

	function set(choice) {
		Env.act(`power profile ${PowerProfile.toString(choice)}`, () => PowerProfiles.profile = choice);
	}

	// `seconds` as hours and minutes.
	function span(seconds) {
		const minutes = Math.round(seconds / 60);
		const hours = Math.floor(minutes / 60);
		return hours > 0 ? `${hours} h ${minutes % 60} min` : `${minutes} min`;
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
}
