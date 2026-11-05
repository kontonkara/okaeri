pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// The power profile, power-profiles-daemon's.
Singleton {
	readonly property int profile: PowerProfiles.profile
	readonly property var choices: [
		{ profile: PowerProfile.PowerSaver, text: "Saver" },
		{ profile: PowerProfile.Balanced, text: "Balanced" }
	].concat(PowerProfiles.hasPerformanceProfile ? [{ profile: PowerProfile.Performance, text: "Performance" }] : [])

	function set(choice) {
		Env.act(`power profile ${PowerProfile.toString(choice)}`, () => PowerProfiles.profile = choice);
	}
}
