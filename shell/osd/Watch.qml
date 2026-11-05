import QtQuick

// One of a service's values: moved() says it changed. What it reads as the
// service comes up or goes to another `device` isn't a change, nor is what it
// reads in the moment after.
Timer {
	id: watch

	property var value
	property bool ready: false
	property var device

	signal moved

	// After the bindings are done: `ready` and `value` change in no set order.
	function check() {
		if (ready && !running)
			moved();
	}

	interval: 1000
	running: true
	onReadyChanged: restart()
	onDeviceChanged: restart()
	onValueChanged: Qt.callLater(check)
}
