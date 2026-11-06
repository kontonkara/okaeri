import QtQuick

// When something is to end, `until`, in ms since the epoch, 0 for never: over()
// says it's time, and `label` how long that is. It looks every second, as a sleep
// would stop a long timer.
Timer {
	id: expiry

	property double until: 0
	property double now: Date.now()
	readonly property string label: until > 0 ? `${Power.span(Math.max(0, until - now) / 1000)} · until ${Qt.formatDateTime(new Date(until), "HH:mm")}` : ""

	signal over

	// What `until` is `seconds` from now.
	function after(seconds) {
		return Date.now() + seconds * 1000;
	}

	// What it is `notches` of the wheel on, half an hour each: 0 when that's past.
	function stepped(notches) {
		now = Date.now();
		const end = Math.max(until, now) + notches * 1800000;
		return end > now ? end : 0;
	}

	interval: 1000
	repeat: true
	running: until > 0
	onTriggered: {
		now = Date.now();
		if (now >= until)
			over();
	}
}
